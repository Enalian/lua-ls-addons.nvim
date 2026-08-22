# 📦 lua-ls-addons.nvim

**lua-ls-addons.nvim** is a decentralized package manager and environment injector for Neovim's `lua_ls`. It automates the downloading, versioning, and configuration of Lua typings (like game APIs or frameworks) directly from GitHub or local directories.

Instead of globally installing typings for all projects or manually fighting with `workspace.library` paths, this plugin turns your project's `.luarc.json` into a fully functional package manager (similar to `package.json` in Node.js or `composer.json` in PHP). 

## ✨ Core Features

*   🚀 **Decentralized Configurations:** Your project dictates its own dependencies. Anyone cloning your repository gets the exact same LSP environment automatically.
*   🔒 **Lockfile Generation:** Automatically generates and updates a `lua-addons.lock` file in your project root to guarantee identical setups across your team.
*   📥 **Smart Fetching:** Can clone specific Git commits, branches, or download packaged `.zip` releases directly from the GitHub API.
*   🔥 **Hot Reloading:** Instantly updates the `lua_ls` environment when saving project configuration files without requiring editor restarts.

## 📦 Installation & Global Setup

Install with your favorite package manager (e.g., `lazy.nvim`). The global setup is extremely minimal and is primarily used to define **aliases** for clean project configurations.

```lua
{
    "Enalian/lua-ls-addons.nvim",
    opts = {
        -- Automatically check for updates if "latest" is requested
        auto_update = true, 
        
        -- Watch .luarc.json for changes and reload LSP
        watch_configs = true,
        
        -- Map short names to full GitHub repositories
        aliases = {
            garrysmod = "luttje/glua-api-snippets",
            palworld  = "someone/palworld-api-typings",
            wiremod   = "Enalian/wiremod-typings"
        }
    }
}
```

Hook the plugin into your LSP initialization routine using `nvim-lspconfig`:

```lua
require("lspconfig").lua_ls.setup({
    on_init = require("lua-ls-addons").on_init,
    settings = { Lua = {} }
})
```

## 🛠️ Project Configuration (`.luarc.json`)

To add dependencies to a project, simply define them in the `addons` array inside your project's `.luarc.json` or `.luarc.jsonc`. 

The syntax follows this powerful format: `repository@version:release_pattern`

```json
{
    "addons": [
        // 1. Alias Usage: Resolves to "luttje/glua-api-snippets@latest"
        "garrysmod",
        
        // 2. Specific Commit: Clones a specific git commit hash
        "Enalian/wiremod-typings@306a055",
        
        // 3. GitHub Release: Downloads a specific release asset matching the regex pattern
        "author/framework@v1.0.2:%.lua%.zip$",
        
        // 4. Local Development: Provide an absolute or home-relative path
        "~/projects/my-local-addon",
        
        // 5. Advanced Object Configuration: Overrides default behaviors
        {
            "addon": "palworld@latest:%.zip$",
            "force_name": "Palworld Server API",
            "auto_update": false
        }
    ]
}
```

### Syntax Breakdown:
*   **Repository (`garrysmod` or `author/repo`)**: The GitHub repository. If an alias exists in your Neovim config, it will expand automatically.
*   **Version (`@v1.0.2`, `@306a055`, or `@latest`)**: The specific git commit, branch, or release tag. Defaults to `latest`.
*   **Release Pattern (`:pattern$`)**: *Optional.* If provided, the plugin will bypass `git clone` and instead use the GitHub API to download the first release asset matching this Lua regex pattern.

## 🔗 Manifests & Dependencies

Addon authors can further control the environment by placing a `__manifest.json` in their repository root. The plugin will automatically resolve and download nested dependencies.

```json
{
    "name": "Wiremod Typings",
    "base": "garrysmod",
    "depends_on": ["Enalian/another-addon@v2.0.0"],
    "lua_ls": {
        "diagnostics": {
            "globals": ["CLIENT", "SERVER"]
        }
    }
}
```

---

### 💻 User Commands

| Command | Description |
| :--- | :--- |
| `:LuaAddonUpdate` | Force update check for active addons in the current workspace. |
