# Setup

Add this package with your favorite package manager.

```lua
require("nvim-setup").setup({
    url = "https://gerrithub.io/a",
    -- If you do not want to use HTTP credentials then you
    -- can instead provide cookie. In that case do not add the
    -- fields username and password
    -- cookie = os.getenv("GERRIT_COOKIE"),

    -- Be careful not to git commit your credentials ;)
    digest_authentication = false,
    username = os.getenv("GERRIT_USERNAME"),
    password = os.getenv("GERRIT_PASSWORD"),
})`.
```
## URL

The url is mandatory. It should end with "/a" if you use the HTTP credentials.

## HTTP credentials (recommended)

If you use HTTP credentials you do **not** need cookie authentication.

Field username and password must be provided. The password is not the one you use to login via your browser.

To get a HTTP password go to your gerrit dashboard and go to "HTTP Credentials" and click "Generate new password".

The field `digest_authentication` should be set accordingly to your gerrit configuration.

When you choose this method the url should probably end with "/a".

The fields username and password can be functions. The functions are called when the network
requests are made. This can be used for example to call a CLI of a password keeper to resolve
the password. Password keepers are much safer than env variables;

## Cookie authentication

If you do **not** use HTTP crendentials you can use cookies to authenticate yourself.

You can get a cookie by connecting to your browser and copying your authentication cookie. Everytime you log in again on gerrit on your browser you have to update your cookie. The cookie string should be in the form "GerritAccount=XYZ".

### Automatically get cookies

You can pass a function to the field `cookie`. You can use that to get the cookie dynamically. You can for example
use a program that can get cookies automatically from your browser.

#### Firefox example

This is an example if you use Firefox and have sqlite3 installed. This example use the paths you
have if you install Firefox with snap. If you didn't use `snap` change the paths accordingly.

```lua
cookie = function()
    local handle = io.popen("cp ~/snap/firefox/common/.mozilla/firefox/*default-release/cookies.sqlite /tmp/cookies.sqlite "
                            .. "&& sqlite3 /tmp/cookies.sqlite 'SELECT value FROM moz_cookies WHERE name=\"GerritAccount\" ;'"
                            .. "&& rm /tmp/cookies.sqlite")
    assert(handle, "Gerrit cookie: popen fail")
    local result = handle:read("*a")
    assert(handle, "Gerrit cookie: failed to read output")
    handle:close()
    assert(#result, "Gerrit cookie: no output")
    -- Remove the \n
    result = result:sub(1, -2)
    return "GerritAccount=" .. result
end
```

# Usage

```lua
:GerritLoadComments <change_id>
```

It will load the comments on your quickfix list.

Be sure that you have ":cd ~/dev/my_project" (or ":tcd") to have the root of the repo reviewed on gerrit before
-:GerritLoadComments (otherwise the paths in the quickfix list won't make sense).

# Contributions

There is much more we can do with the [gerrit API](https://gerrit-documentation.storage.googleapis.com/Documentation/2.15.3/rest-api.html). Contributions are welcome.
