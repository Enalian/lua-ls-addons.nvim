---@class LuaAddonsSetupOptions
---@field auto_update? boolean If true, the plugin will fetch the latest versions when "latest" is requested (default: true).
---@field watch_configs? boolean Automatically reload lua_ls when project config files (.luarc.json) are saved (default: true).
---@field aliases? table<string, string> Dictionary mapping short addon names to their full GitHub repositories.
---@example
--- require("lua-ls-addons").setup({
---     auto_update = true,
---     aliases = {
---         garrysmod = "luttje/glua-api-snippets",
---         palworld = "someone/palworld-api-typings"
---     }
--- })

---@class LuaAddonsInternalConfig
---@field base_dir string Absolute path to the global cache directory where all addons are downloaded.
---@field manifest_name string The expected name of the manifest file inside an addon repository.
---@field lockfile_name string The name of the lockfile generated in the root of user projects.

---@type LuaAddonsInternalConfig
return {
	base_dir = vim.fn.stdpath("data") .. "/lua-addons",
	manifest_name = "__manifest.json",
	lockfile_name = "lua-addons.lock",
}
