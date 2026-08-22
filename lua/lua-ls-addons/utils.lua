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

--- Parses an addon requirement string from .luarc.json.
---@param str string The raw requirement string (e.g., 'garrysmod@v1.0:%.zip$').
---@param aliases table<string, string> Dictionary of registered aliases.
---@return ParsedAddonString
function M.parse_addon_string(str, aliases)
	local base_name, version, pattern = str:match("^([^@:]+)@?([^:]*):?(.*)$")

	if not version or version == "" then
		version = "latest"
	end
	if not pattern or pattern == "" then
		pattern = nil
	end

	local repo = aliases[base_name] or base_name
	local is_release = pattern ~= nil

	return {
		original_name = base_name,
		repo = repo,
		version = version,
		release_pattern = pattern,
		is_release = is_release,
	}
end

return M
