# 📦 lua-addons.nvim

**lua-addons.nvim** is a powerful Neovim plugin designed to seamlessly manage, download, and configure Lua typings and environments for `lua_ls` (Lua Language Server). 

Instead of manually downloading typings, updating paths, and configuring globals for every project, `lua-addons` automates the entire process. It reads your project's `.luarc.json`, automatically resolves dependencies, and injects the correct libraries and diagnostic rules directly into your LSP on the fly.

## ✨ Features

- 🚀 **Automated Downloads:** Fetches typings directly from GitHub repositories (via Git clone or GitHub Releases).
- 🔄 **Smart Versioning:** Supports Semantic Versioning (SemVer), commit tracking, timestamps, and custom Lua version-checking logic.
- 🧠 **Dependency Resolution:** Addon authors can define `base` and `depends_on` in a `__manifest.json`. The plugin uses topological sorting to load dependencies in the exact correct order.
- 🔥 **Hot Reloading:** Automatically watches for changes in `.luarc.json`, `.luarc.jsonc`, or `.luacheckrc` and updates `lua_ls` instantly upon saving. No `:LspRestart` required!
- 🛡️ **Zero Config LSP:** Automatically manages `workspace.library`, `diagnostics.globals`, and `diagnostics.disable` based on the addon's manifest.
- 💻 **User Commands:** Built-in commands with auto-completion to update addons, check information, and list installed libraries.

---

## 📦 Installation

Install with your favorite package manager. Here is an example using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
    "Enalian/lua-addons.nvim",
    config = function()
        require("lua-addons").setup({
            -- Global flag to enable/disable automatic updates
            auto_update = true,
            
            -- Automatically reload lua_ls when .luarc.json is saved
            watch_configs = true,
            
            addons = {
                -- Simple syntax (defaults to Git clone)
                garrysmod = "Enalian/garrysmod-typings",
                
                -- Advanced syntax (GitHub Releases)
                wiremod = {
                    src = "Enalian/wiremod-typings",
                    version = "numbered", -- Smart semver comparison
                    check_interval = 86400, -- Check once a day (in seconds)
                    release_name = "%.lua%.zip$"
                }
            }
        })
    end
}
