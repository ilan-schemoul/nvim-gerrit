local curl = require "plenary.curl"

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

local function load_comments_from_url(url)
  conf_check()

  if not url then
    vim.notify("You must provide an url", vim.log.levels.ERROR)
    return false
  end

  print_debug("Loading comments from url " .. url)

  local headers = {}

  if M.config.cookie then
    table.insert(headers, "--cookie")
    table.insert(headers, M.config.cookie)
  else
    assert(M.config.username and M.config.password)
    if M.config.digest_authentication then
      table.insert(headers, "--digest")
    end
    table.insert(headers, "--user")
    table.insert(headers, M.config.username .. ":" .. M.config.password)
  end

  print_debug("Headers: " .. vim.inspect(headers))

  curl.get({
    url = url,
    raw = headers,
    callback = function(res)
      vim.schedule(function()
        -- Clean quickfix list
        vim.cmd("cexpr []")

        print_debug("result body: " .. res.body)
        -- Remove )]}'
        local json = res.body:sub(5)

        -- Errors are in the form file:line
        vim.cmd("set errorformat=%f:%l\\ %m")

        local files = vim.json.decode(json)
        for filename, patch_sets in pairs(files) do
          for _, comment in ipairs(patch_sets) do
            if comment.line then
              local error = filename .. ":" .. comment.line .. " " .. comment.message
              -- Escape multiline string for vim
              error = error:gsub("\n", "\n\\ ")
              -- Escape quote
              error = error:gsub("'", " ")

              -- Load errors
              vim.cmd("caddexpr '" .. error .. "'")
            end
          end
        end
      end)
    end,
  })
end

M.load_comments_from_changeid = function(id)
  conf_check()

  if not id then
    vim.notify("You must provide an id", vim.log.levels.ERROR)
    return false
  end

  local url = M.config.url .. "/changes/" .. tostring(id) .. "/comments"
  load_comments_from_url(url)
end

M.setup = function(config)
  M.config.url = config.url
  M.config.username = config.username
  M.config.password = config.password
  M.config.cookie = config.cookie
  M.config.debug = config.debug or false

  print_debug(vim.inspect(config))

  conf_check()

  vim.api.nvim_create_user_command("GerritLoadComments", function(args)
    M.load_comments_from_changeid(args.args)
    vim.cmd("cwindow")
  end, { nargs = 1 })
end

return M
