-- ==============================================================================
-- Typings and library manager for Neovim (lua_ls)
-- ==============================================================================

---@class LuaAddonVersionConfig
---@field type? '"commit"'|'"numbered"'|'"datetime"'|'"timestamp"'|'"disabled"'|'"custom"' Versioning strategy type.
---@field format? string|fun(remote: string, local_ver: string|nil): boolean Custom format string or comparison function.

---@class LuaAddonConfig
---@field src? string GitHub repository in "owner/repo" format or full URL.
---@field force_name? string Override the display name of the addon, ignoring the manifest.
---@field check_interval? number Interval between update checks in seconds (default: 14 days).
---@field release_name? string Regex pattern to match the release asset name (default: "%.lua%.zip$").
---@field branch? string Git branch to clone (if version type is "commit").
---@field auto_update? boolean Automatically check for updates on startup.
---@field version? boolean|string|LuaAddonVersionConfig Versioning configuration. False disables version checking.

---@class LuaAddonOptions
---@field auto_update? boolean Global flag to enable/disable automatic updates for all addons.
---@field addons table<string, string|LuaAddonConfig> Dictionary of addons to manage.

local state = require("lua-ls-addons.state")
local utils = require("lua-ls-addons.utils")
local sync = require("lua-ls-addons.sync")
local lsp = require("lua-ls-addons.lsp")
local commands = require("lua-ls-addons.commands")

local M = {}

--- Forces an immediate update check for a specific addon.
---@param key string The addon identifier/key.
function M.update(key)
	local config = state.addon_configs[key]
	if not config then
		utils.log_error("Addon '" .. key .. "' not found in configuration!")
		return
	end
	utils.log_info("Checking for updates for: " .. key .. "...", "", "DiagnosticInfo")
	sync.process_addon(key, config, true)
end

--- Forces an immediate update check for all registered addons.
function M.update_all()
	for key, _ in pairs(state.addon_configs) do
		M.update(key)
	end
end

--- Checks if an addon is currently loaded/installed.
---@param key string The addon identifier.
---@return boolean # True if the addon is registered and cached locally.
function M.is_loaded(key)
	return state.loaded_addons[key] ~= nil
end

--- Retrieves the absolute file path to the addon directory.
---@param key string The addon identifier.
---@return string|nil # The absolute path, or nil if not loaded.
function M.get_path(key)
	return state.loaded_addons[key] and state.loaded_addons[key].path or nil
end

--- Retrieves full information about an installed addon.
---@param key string The addon identifier.
---@return LuaAddonInfoData|nil # The table with addon metadata.
function M.get_info(key)
	return state.loaded_addons[key]
end

--- Retrieves a list of all currently loaded addons.
---@return table<string, LuaAddonInfoData> # A dictionary of all installed addons.
function M.get_all_addons()
	return state.loaded_addons
end

--- Handler for LSP client initialization (`on_init`).
--- Resolves dependencies, injects libraries, and applies diagnostics settings.
---@param client table The initialized Neovim LSP client object.
---@param skip_notify? boolean If true, suppresses sending `workspace/didChangeConfiguration` back to the server.
---@return boolean Always returns true to allow LSP initialization.
M.on_init = lsp.on_init

--- Initializes the Lua Addon Manager, downloads missing dependencies, and registers user commands.
---
---@param opts LuaAddonOptions Configuration options
function M.setup(opts)
	opts = type(opts) == "table" and opts or {}
	local addons = type(opts.addons) == "table" and opts.addons or {}

	local global_auto = true
	if opts.auto_update ~= nil then
		global_auto = opts.auto_update
	end

	local watch_configs = opts.watch_configs ~= false

	for key, raw_config in pairs(addons) do
		local config = {
			repo = nil,
			force_name = nil,
			check_interval = state.DEFAULT_INTERVAL,
			release_name = "%.lua%.zip$",
			branch = nil,
			ver_config = { type = "commit", format = nil },
			auto_update = global_auto,
		}

		if type(raw_config) == "string" then
			config.repo = utils.parse_repo(raw_config)
		elseif type(raw_config) == "table" then
			if raw_config.src then
				config.repo = utils.parse_repo(raw_config.src)
			end
			if raw_config.check_interval then
				config.check_interval = raw_config.check_interval
			end
			if raw_config.release_name then
				config.release_name = raw_config.release_name
			end
			if raw_config.branch then
				config.branch = raw_config.branch
			end
			if raw_config.auto_update ~= nil then
				config.auto_update = raw_config.auto_update
			end

			if raw_config.version == false then
				config.ver_config.type = "disabled"
			elseif type(raw_config.version) == "string" then
				config.ver_config.type = raw_config.version
			elseif type(raw_config.version) == "table" then
				config.ver_config.type = raw_config.version.type or "disabled"
				config.ver_config.format = raw_config.version.format
			end
		end

		if config.repo then
			state.addon_configs[key] = config
			sync.process_addon(key, config, false)
		end
	end

	commands.setup(M)

	if watch_configs then
		lsp.setup_watcher()
	end
end

return M
