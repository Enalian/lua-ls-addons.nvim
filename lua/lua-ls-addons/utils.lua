local M = {}

--- Checks if a fancy notification plugin is available.
---@return boolean
local function has_fancy_notify()
	return package.loaded["notify"] ~= nil or package.loaded["noice"] ~= nil
end

--- Logs an informational message.
---@param msg string The message to display.
---@param icon? string Optional icon.
---@param hl? string Optional highlight group.
function M.log_info(msg, icon, hl)
	local state = require("lua-ls-addons.state")
	if not state.global_config.notifications then
		return
	end
	if has_fancy_notify() then
		vim.notify(msg, vim.log.levels.INFO, { title = "lua-ls-addons", icon = icon or "" })
	else
		vim.api.nvim_echo({ { "[ " .. (icon or "") .. " ] ", hl or "DiagnosticOk" }, { msg, "Normal" } }, true, {})
	end
end

--- Logs a warning message.
---@param msg string The message to display.
---@param icon? string Optional icon.
function M.log_warn(msg, icon)
	local state = require("lua-ls-addons.state")
	if not state.global_config.notifications then
		return
	end
	if has_fancy_notify() then
		vim.notify(msg, vim.log.levels.WARN, { title = "lua-ls-addons", icon = icon or "" })
	else
		vim.api.nvim_echo({ { "[ " .. (icon or "") .. " ] ", "DiagnosticWarn" }, { msg, "Normal" } }, true, {})
	end
end

--- Logs an error message.
---@param msg string The message to display.
---@param icon? string Optional icon.
function M.log_error(msg, icon)
	local state = require("lua-ls-addons.state")
	if not state.global_config.notifications then
		return
	end
	if has_fancy_notify() then
		vim.notify(msg, vim.log.levels.ERROR, { title = "lua-ls-addons", icon = icon or "" })
	else
		vim.api.nvim_echo({ { "[ " .. (icon or "") .. " ] ", "DiagnosticError" }, { msg, "Normal" } }, true, {})
	end
end

---@class ParsedAddonString
---@field original_name string The base name of the addon (e.g., 'garrysmod').
---@field repo string The resolved repository path (e.g., 'author/repo').
---@field version string The requested version or 'latest'.
---@field release_pattern? string The regex pattern for a GitHub release asset.
---@field is_release boolean True if this string requests a GitHub release.

--- Parses an addon requirement string from .luarc.json, resolving aliases and specs.
---@param str string The raw requirement string (e.g., 'garrysmod').
---@param aliases table<string, any> Dictionary of registered aliases.
---@return ParsedAddonString
function M.parse_addon_string(str, aliases)
	local base_name, version, pattern = str:match("^([^@:]+)@?([^:]*):?(.*)$")

	local repo = base_name
	local alias_val = aliases[base_name]

	-- If the alias points to a full spec string (e.g., "repo@version:pattern"), parse it
	if type(alias_val) == "string" then
		local a_repo, a_ver, a_pat = alias_val:match("^([^@:]+)@?([^:]*):?(.*)$")
		repo = a_repo or base_name
		if (not version or version == "") and a_ver and a_ver ~= "" then
			version = a_ver
		end
		if (not pattern or pattern == "") and a_pat and a_pat ~= "" then
			pattern = a_pat
		end
	elseif type(alias_val) == "table" and alias_val.addon then
		return M.parse_addon_string(alias_val.addon, aliases)
	end

	if not version or version == "" then
		version = "latest"
	end
	if not pattern or pattern == "" then
		pattern = nil
	end

	-- Keep the short alias name as original_name so cache folders stay clean (e.g., lua-addons/garrysmod/latest)
	local original_name = base_name
	if aliases[base_name] == nil and base_name:match("/") then
		original_name = base_name:match("([^/]+)$") or base_name
	end

	local is_release = pattern ~= nil

	return {
		original_name = original_name,
		repo = repo,
		version = version,
		release_pattern = pattern,
		is_release = is_release,
	}
end

return M
