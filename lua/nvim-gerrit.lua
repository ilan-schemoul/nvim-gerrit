local curl = require "plenary.curl"
local entry_display = require "telescope.pickers.entry_display"
local pickers = require "telescope.pickers"
local finders = require "telescope.finders"
local conf = require("telescope.config").values
local actions = require "telescope.actions"
local action_state = require "telescope.actions.state"

local M = {
  config = {},
}

local function conf_check()
  assert(M.config.cookie or (M.config.username and M.config.password),
         "You must provide cookie or username and password")
  assert(M.config.url, "You must provide url")
end

local function print_debug(obj)
  if not M.config.debug then
    return
  end
  if type(obj) == "table" then
    print(vim.inspect(obj))
  else
    print(obj)
  end
end

-- If the field name is a function call that function and return its value.
-- Otherwise just return the field.
local function get_field(field_name)
  local config_field = M.config[field_name]
  local val

  if type(config_field) == "function" then
    val = config_field()
  else
    val = config_field
  end

  assert(val, "Failed to get field " .. val)
  return val
end

local function load_into_quickfix(comments_thread)
  -- Clean quickfix list
  vim.cmd("cexpr []")
  -- Errors are in the form file:line
  vim.cmd("set errorformat=%f:%l\\ %m")

  for _, thread in pairs(comments_thread) do
    assert(thread.filename)

    if #thread.comments > 0 and thread.unresolved then
      local first_msg = "[unknown message]"
      if thread.comments[1] then
        first_msg = thread.comments[1].message
      end

      print_debug("Thread starting with " .. first_msg .. " has " ..
                  #thread.comments .. " messages. Unresolved " ..
                  tostring(thread.unresolved))

      for _, comment in ipairs(thread.comments) do
        if comment.line and comment.message then
          print_debug("Comment " .. vim.inspect(comment))

          local error = thread.filename .. ":" .. comment.line .. " " .. comment.message

          -- Escape multiline string for vim
          error = error:gsub("\n", "\n\\ ")
          -- Escape quote
          error = error:gsub("'", "''")

          -- Load errors
          vim.cmd("caddexpr '" .. error .. "'")
        end
      end
    end
  end
end

local function parse_json_date(json_date)
    local pattern = "(%d+)%-(%d+)%-(%d+) (%d+)%:(%d+)%:(%d+)"
    local year, month, day, hour, minute, seconds = json_date:match(pattern)
    local timestamp = os.time{year = year, month = month,
                      day = day, hour = hour, min = minute, sec = seconds}

    assert(timestamp)
    return timestamp
end

-- Return an associative array where the key is the id of the first comment
-- in the thread and the values are the list of comments in that thread.
local function get_comment_threads(files)
  local comment_threads = {}

  -- When a comment is store in a thread whose key is not its own id, but is
  -- the id of its parent or greatparent then we store the tuple comment_id/
  -- thread_id here.
  local id_to_thread_id = {}

  for filename, comments in pairs(files) do
    -- We need to sort by comments date to properly form comments_thread
    table.sort(comments, function(a, b)
      return parse_json_date(a.updated) < parse_json_date(b.updated)
    end)

    for _, comment in ipairs(comments) do
      -- Thread id is the ancestor id (parent, greatparent etc.)
      local thread_id = id_to_thread_id[comment.in_reply_to]
                        or comment.in_reply_to

      if comment_threads[thread_id] then
        table.insert(comment_threads[thread_id].comments, comment)
        comment_threads[thread_id].unresolved = comment.unresolved

        id_to_thread_id[comment.id] = thread_id
      else
        comment_threads[comment.id] = {
          comments = { comment },
          filename = filename,
          -- As comments are sorted by updated we can use the last unresolved
          -- state to determine if the whole thread is resolved
          unresolved = comment.unresolved,
        }
      end
    end
  end

  print_debug("Comment threads " .. vim.fn.json_encode(comment_threads))

  return comment_threads
end

local function get_headers()
  local headers = {}

  if M.config.cookie then
    table.insert(headers, "--cookie")
    table.insert(headers, get_field("cookie"))
  else
    assert(M.config.username and M.config.password)
    if M.config.digest_authentication then
      table.insert(headers, "--digest")
    end
    table.insert(headers, "--user")
    table.insert(headers, get_field("username") .. ":" .. get_field("password"))
  end

  return headers
end

local function api_request(endpoint, cb)
  conf_check()

  local headers = get_headers()
  print_debug("Headers: " .. vim.inspect(headers))

  curl.get({
    url = M.config.url .. endpoint,
    raw = headers,
    callback = function(res)
      vim.schedule(function()

        print_debug("result body: " .. res.body)

        -- Remove )]}'
        local json = res.body:sub(5)
        local object = vim.json.decode(json)

        cb(object)
      end)
    end,
  })
end

M.load_comments = function(id)
  conf_check()

  local endpoint = "/changes/" .. tostring(id) .. "/comments"

  api_request(endpoint, function(comments)
    local comment_threads = get_comment_threads(comments)
    load_into_quickfix(comment_threads)
    -- open quickfix
    vim.cmd("copen")
    -- When a message takes multiple lines then show it on multiple line
    -- (instead of one).
    vim.cmd("setl nolist wrap linebreak")
  end)
end

M.list_changes = function()
  conf_check()

  local owned_changes = "q=is:open+owner:self"
  local reviewed_changes = "q=is:open+reviewer:self+-owner:self"
  local query = owned_changes .. "&" .. reviewed_changes
  local endpoint = "/changes/?" .. query

  api_request(endpoint, function(changes_arr)
    local changes = {}

    for i, _changes in ipairs(changes_arr) do
      for _, _change in ipairs(_changes) do
        _change.self_owner = i == 1
        table.insert(changes, _change)
      end
    end

    local displayer = entry_display.create {
      items = {
        { remaining = true },
      },
    }

    local function make_display(change)
      local highlight = change.value.self_owner and "TelescopeGerritOwner"
                        or "TelescopeGerritReviewer"

      return displayer({
        { change.value.subject, highlight },
      })
    end

    -- When the query comports an "&" then the API response contains multiple
    -- arrays
    pickers.new({}, {
      prompt_title = "Changes",
      finder = finders.new_table({
        results = changes,
        entry_maker = function(change)
          return {
            value = change,
            display = make_display,
            ordinal = change.subject,
          }
        end,
      }),
      sorter = conf.generic_sorter(),
      attach_mappings = function(prompt_bufnr)
        actions.select_default:replace(function()
          actions.close(prompt_bufnr)
          local change = action_state.get_selected_entry().value
          assert(change)

          M.load_comments(change._number)
        end)
        return true
      end,
    }):find()
  end)
end

local function set_default_highlights()
  if vim.fn.hlexists("TelescopeGerritOwner") == 0 then
    vim.cmd("highlight TelescopeGerritOwner guifg=#dc8a78")
  end

  if vim.fn.hlexists("TelescopeGerritReviewer") == 0 then
    vim.cmd("highlight TelescopeGerritReviewer guifg=#179299")
  end
end

M.setup = function(config)
  M.config.url = config.url
  M.config.username = config.username
  M.config.password = config.password
  M.config.cookie = config.cookie
  M.config.debug = config.debug or false

  print_debug(vim.inspect(config))
  conf_check()

  set_default_highlights()

  vim.api.nvim_create_user_command("GerritLoadComments", function(args)
    M.load_comments(args.args)
  end, { nargs = 1 })
end

return M
