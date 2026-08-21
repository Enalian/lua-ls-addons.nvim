local state = require("lua-ls-addons.state")
local utils = require("lua-ls-addons.utils")
local lsp = require("lua-ls-addons.lsp")

local M = {}

--- Registers user commands. Takes the main API table as an argument to avoid circular dependencies.
function M.setup(api)
	local function get_addon_completions(ArgLead)
		local completions = { "all" }
		for key, _ in pairs(state.loaded_addons) do
			table.insert(completions, key)
		end
		local result = {}
		for _, val in ipairs(completions) do
			if val:sub(1, #ArgLead) == ArgLead then
				table.insert(result, val)
			end
		end
		return result
	end

	vim.api.nvim_create_user_command("LuaAddonUpdate", function(opts)
		if opts.args == "" or opts.args == "all" then
			api.update_all()
		else
			api.update(opts.args)
		end
	end, { nargs = "?", desc = "Update lua-ls typings (all or specific)", complete = get_addon_completions })

	vim.api.nvim_create_user_command("LuaAddonInfo", function(opts)
		local addon = state.loaded_addons[opts.args]
		if not addon then
			utils.log_error("Addon '" .. opts.args .. "' is not installed.")
			return
		end

		local manifest = lsp.read_addon_manifest(addon.path) or {}
		local user_config = state.addon_configs[opts.args] or {}
		local display_name = user_config.force_name or manifest.name or addon.name:gsub("^%l", string.upper)

		local lines = {
			" 󰢱 Addon: " .. display_name .. " (" .. addon.name .. ")",
			" ───────────────",
			" 󰏗 Version: " .. addon.version,
			"  Repository: " .. addon.repo,
			"  Author: " .. addon.author.name,
			"  Path: " .. addon.path,
		}

		local manifest = lsp.read_addon_manifest(addon.path)
		if manifest then
			if manifest.base then
				table.insert(lines, " 󰌌 Base: " .. manifest.base)
			end
			if manifest.depends_on then
				local deps = type(manifest.depends_on) == "string" and manifest.depends_on
					or table.concat(manifest.depends_on, ", ")
				table.insert(lines, " 󰦄 Depends on: " .. deps)
			end
		end

		vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO, { title = "Lua Addon Info" })
	end, {
		nargs = 1,
		desc = "Information about the addon",
		complete = function(ArgLead)
			local result = {}
			for key, _ in pairs(state.loaded_addons) do
				if key:sub(1, #ArgLead) == ArgLead then
					table.insert(result, key)
				end
			end
			return result
		end,
	})

	vim.api.nvim_create_user_command("LuaAddonList", function()
		local count = 0
		for key, addon in pairs(state.loaded_addons) do
			utils.log_info(key .. " [" .. addon.version .. "]", "")
			count = count + 1
		end
		if count == 0 then
			utils.log_warn("No addons installed.")
		end
	end, { desc = "List all installed addons" })
end

return M
