---@class LuaAddonState
local M = {
	---@type table<string, LuaAddonInfoData>
	loaded_addons = {},

	---@type table<string, LuaAddonConfig>
	addon_configs = {},

	DEFAULT_INTERVAL = 14 * 24 * 60 * 60, -- 14 days
}

return M
