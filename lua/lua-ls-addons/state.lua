---@class LuaAddonGlobalConfig
---@field auto_update boolean Global flag to enable/disable automatic updates.
---@field watch_configs boolean Automatically reload lua_ls when configs are saved.
---@field notifications boolean Global flag to enable/disable notifications.

---@class LuaAddonState
---@field aliases table<string, string> Mapping of short names to GitHub repositories.
---@field global_config LuaAddonGlobalConfig Global plugin settings.

---@type LuaAddonState
local M = {
	aliases = {},
	global_config = {
		auto_update = true,
		watch_configs = true,
		notifications = true,
	},
}

return M
