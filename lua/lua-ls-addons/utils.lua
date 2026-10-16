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

--- Formats a raw folder/repo string into a pretty Title Case name.
--- Example: "my_cool-addon" -> "My Cool Addon"
---@param raw_name string
---@return string
function M.format_addon_name(raw_name)
	local cleaned = raw_name:gsub("[_%-]+", " ")
	return cleaned:gsub("(%a)([%w']*)", function(first, rest)
		return first:upper() .. rest:lower()
	end)
end

local IGNORED_DIRS = {
	materials = true,
	models = true,
	sound = true,
	maps = true,
	resource = true,
	particles = true,
	backgrounds = true,
	scenes = true,
	shaders = true,
	wiki = true,
	docs = true,
	doc = true,
	tests = true,
	test = true,
	examples = true,
	node_modules = true,
}

--- Dynamically scans top-level directories to find where .lua files actually reside.
---@param root_path string
---@return string|string[]|nil
function M.detect_lua_paths(root_path)
	-- 1. If there are .lua files directly in the root (like init.lua), use root "."
	local root_lua = vim.fn.glob(root_path .. "/*.lua", false, true)
	if #root_lua > 0 then
		return "."
	end

	-- 2. Scan all top-level subdirectories for any .lua files inside them
	local found = {}
	local handle = vim.uv.fs_scandir(root_path)
	if handle then
		while true do
			local name, ftype = vim.uv.fs_scandir_next(handle)
			if not name then
				break
			end

			if not ftype then
				local stat = vim.uv.fs_stat(root_path .. "/" .. name)
				ftype = stat and stat.type
			end

			-- Check non-hidden, non-asset directories
			if ftype == "directory" and not name:match("^%.") and not IGNORED_DIRS[name:lower()] then
				local sub_lua = vim.fn.glob(root_path .. "/" .. name .. "/**/*.lua", false, true)
				if #sub_lua > 0 then
					table.insert(found, name)
				end
			end
		end
	end

	table.sort(found)

	if #found == 0 then
		return nil
	elseif #found == 1 then
		return found[1]
	else
		return found
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
