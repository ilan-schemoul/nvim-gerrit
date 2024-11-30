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

## Cookie authentication (not recommended)

If you do **not** use HTTP crendentials you can use cookies to authenticate yourself.

You can get a cookie by connecting to your browser and copying your authentication cookie. Everytime you log in again on gerrit on your browser you have to update your cookie. The cookie string should be in the form "GerritAccount=XYZ".

# Usage

```lua
:GerritLoadComments <change_id>
```

It will load the comments on your quickfix list.

# Contributions

There is much more we can do with the [gerrit API](https://gerrit-documentation.storage.googleapis.com/Documentation/2.15.3/rest-api.html). Contributions are welcome.
