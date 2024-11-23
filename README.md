# Install and setup

Add this package with your favorite package manager.
```lua
require("nvim-setup").setup({
    url = "https://gerrithub.io",
    -- Be careful not to git commit your cookie ;)
    cookie = os.getenv("GERRIT_COOKIES"),
    debug = false,
})`.
```

Url and cookie are mandatory. Be careful to not git commit your cookie.
You can get a cookie by connecting to your browser and copying your authentication cookie.

# Usage

```lua
:GerritLoadComments <change_id>
```

It will load the comments on your quickfix list and open the quickfix window.

# Contributions

There is much more we can do with the [gerrit API](https://gerrit-documentation.storage.googleapis.com/Documentation/2.15.3/rest-api.html). Contributions are welcome.
