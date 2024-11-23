local curl = require "plenary.curl"

local M = {
  config = {},
}

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
  assert(M.config.url)
  assert(M.config.cookie)

  if not url then
    vim.notify("You must provide an url", vim.log.levels.ERROR)
    return false
  end

  print_debug("Loading comments from url " .. url)

  curl.get({
    url = url,
    raw = { "--cookie", M.config.cookie },
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
  assert(M.config.url)
  assert(M.config.cookie)

  if not id then
    vim.notify("You must provide an id", vim.log.levels.ERROR)
    return false
  end

  local url = M.config.url .. "/changes/" .. tostring(id) .. "/comments"
  load_comments_from_url(url)
end

M.setup = function(config)
  if not config.cookie then
    vim.notify("Field cookie is mandatory", vim.log.levels.ERROR)
    return false
  end

  if not config.url then
    vim.notify("Field url is mandatory", vim.log.levels.ERROR)
    return false
  end

  M.config.url = config.url
  M.config.cookie = config.cookie
  M.config.debug = config.debug or false

  vim.api.nvim_create_user_command("GerritLoadComments", function(args)
    M.load_comments_from_changeid(args.args)
    vim.cmd("cwindow")
  end, { nargs = 1 })
end

return M
