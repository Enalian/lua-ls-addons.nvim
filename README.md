# 📦 lua-ls-addons.nvim

**lua-ls-addons.nvim** is a powerful Neovim plugin designed to seamlessly manage, download, and configure Lua typings and environments for `lua_ls` (Lua Language Server). 

Instead of manually downloading typings, updating paths, and configuring globals for every project, `lua-ls-addons` automates the entire process. It reads your project's `.luarc.json`, automatically resolves dependencies, and injects the correct libraries and diagnostic rules directly into your LSP on the fly.

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
    "Enalian/lua-ls-addons.nvim",
    opts = {
        -- Global flag to enable/disable automatic updates
        auto_update = true,

        -- Automatically reload lua_ls when .luarc.json is saved
        watch_configs = true,
            
        addons = {
            -- Simple syntax (defaults to Git clone)
            garrysmod = {
                src = "luttje/glua-api-snippets",
                version = "timestamp",
                force_name = "Garry's Mod",
            },
                
            -- Advanced syntax (GitHub Releases)
            wiremod = {
                src = "Enalian/wiremod-typings",
                force_name = "Wiremod (Custom)", -- Override the display name
                version = "numbered", -- Smart semver comparison
                check_interval = 86400, -- Check once a day (in seconds)
                release_name = "%.lua%.zip$"
            }
        }
    }
}
```

### ⚙️ Addon Configuration Options

When configuring an addon in the `addons` table, you can use the following fields (beyond the ones shown in the `wiremod` example above):

- **`src`** *(string)*: GitHub repository in `owner/repo` format or a full URL.
- **`branch`** *(string)*: Specific Git branch to clone (only applies if the version strategy is `"commit"`).
- **`force_name`** *(string)*: Override the display name of the addon in UI notifications, ignoring the manifest.
- **`auto_update`** *(boolean)*: Overrides the global `auto_update` setting specifically for this addon.
- **`version`** *(string | boolean | table)*: The update detection strategy. 
  - `"commit"` (default) - updates via `git pull`.
  - `"numbered"` - compares semantic version strings (e.g., `v1.2.3`).
  - `"datetime"` / `"timestamp"` - parses release dates.
  - `false` / `"disabled"` - completely disables update checking.
  - `{ type = "custom", format = function(remote, local_ver) ... end }` - allows you to write your own Lua function to determine if an update is needed.

---

## 🔌 LSP Integration

To make the magic work, you must hook the plugin into your `lua_ls` initialization. If you are using `nvim-lspconfig`, it looks like this:

```lua
local lspconfig = require("lspconfig")
local lua_addons = require("lua-ls-addons") -- Use the exact module name here

lspconfig.lua_ls.setup({
    -- Attach the lua-addons processor to the LSP initialization
    on_init = lua_addons.on_init,
    
    settings = {
        Lua = {
            -- Your other default Lua settings...
        }
    }
})
```

---

## 📁 Usage in Projects

To activate an addon for a specific project, simply add an `addon` array to your `.luarc.json` (or `.luarc.jsonc`) in the root of your project:

```json
{
    "addon": [
        "vim",
        "wiremod"
    ]
}
```
*Note: Because `lua-ls-addons` automatically resolves dependencies, if `wiremod` depends on `garrysmod`, the plugin will load both automatically in the correct order. `"vim"` is a built-in keyword that configures `lua_ls` for Neovim plugin development.*

---

## 🛠️ For Addon Authors (`__manifest.json`)

If you are creating typings or a library repository, you can place a `__manifest.json` file in the root of your repo. 

**Why is it needed?** It tells `lua-ls-addons` exactly how your environment should be injected into the user's workspace, preventing them from having to manually configure paths or disable warnings for your specific global variables.

### Example `__manifest.json`:
```json
{
    "name": "Wiremod (Extended)",
    "base": "garrysmod",
    "depends_on": ["other-lib"],
    "lua_ls": {
        "workspace": {
            "library": ["lua", "includes"]
        },
        "diagnostics": {
            "globals": ["WireLib", "duplicator"],
            "disable": ["lowercase-global"]
        }
    }
}
```

### Manifest Fields Explained:

- **`name`** *(string)*: A beautiful display name used for UI notifications in Neovim.
- **`base`** *(string)*: The core addon your library extends. The plugin will ensure the base addon is fully loaded *before* yours.
- **`depends_on`** *(string | array of strings)*: Other addons that must be loaded before this one.
- **`lua_ls.workspace.library`** *(array of strings)*: Relative paths inside your repository that contain the actual Lua files/typings. If omitted, the root folder of the repo is injected.
- **`lua_ls.diagnostics.globals`** *(array of strings)*: Global variables your library introduces. Injecting them here stops `lua_ls` from warning users about `undefined-global`.
- **`lua_ls.diagnostics.disable`** *(array of strings)*: Specific `lua_ls` diagnostic warnings to suppress when your addon is active.

---

## ⌨️ User Commands

The plugin provides several commands to manage your typings (all commands support `<Tab>` auto-completion):

| Command | Description |
| :--- | :--- |
| `:LuaAddonUpdate [name]` | Forces an update check for a specific addon (or `all`). |
| `:LuaAddonInfo <name>` | Displays detailed info (version, repo, path, dependencies). |
| `:LuaAddonList` | Prints a list of all currently installed addons and their versions. |

---

## 📜 License

Distributed under the MIT License. See `LICENSE` for more information.
