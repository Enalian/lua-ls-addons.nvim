---@class LuaAddonGlobalConfig
---@field auto_update boolean Global flag to enable/disable automatic updates.
---@field watch_configs boolean Automatically reload lua_ls when configs are saved.
---@field notifications boolean Global flag to enable/disable notifications.
---@field check_interval integer Global update check interval in seconds.

---@class LuaAddonState
---@field aliases table<string, any> Mapping of short names to GitHub repositories or config tables.
---@field global_config LuaAddonGlobalConfig Global plugin settings.

---@type LuaAddonState
local M = {
	aliases = {},
	global_config = {
		auto_update = true,
		watch_configs = true,
		notifications = true,
		check_interval = 14 * 24 * 60 * 60, -- 14 days default
	},
}

return M
