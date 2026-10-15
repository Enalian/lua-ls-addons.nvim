local config = require("lua-ls-addons.config")
local utils = require("lua-ls-addons.utils")
local lsp = require("lua-ls-addons.lsp")

local M = {}

--- Creates a boilerplate manifest file in the current working directory.
---@param force boolean If true, overwrites an existing manifest file.
local function init_manifest(force)
	local cwd = vim.fn.getcwd()
	local manifest_path = cwd .. "/" .. config.manifest_name

	if vim.fn.filereadable(manifest_path) == 1 and not force then
		utils.log_warn(config.manifest_name .. " already exists! Use :LAInit! to overwrite.")
		return
	end

	-- Automatically use the current folder name as the default addon name
	local folder_name = vim.fn.fnamemodify(cwd, ":t")
	local default_name = folder_name:gsub("^%l", string.upper)

	-- Auto-detect "lua" subfolder if it exists in the project root
	local default_path = vim.fn.isdirectory(cwd .. "/lua") == 1 and "lua" or "."

	local template = {
		"{\n",
		'\t"name": "' .. default_name .. '",\n',
		'\t"version": "1.0.0",\n',
		'\t"path": "' .. default_path .. '",\n',
		'\t"base": "garrysmod",\n',
		'\t"depends_on": [],\n',
		'\t"lua_ls": {\n',
		'\t\t"diagnostics": {\n',
		'\t\t\t"globals": [],\n',
		'\t\t\t"disable": [\n',
		'\t\t\t\t"syntax-error",\n',
		'\t\t\t\t"undefined-global",\n',
		'\t\t\t\t"lowercase-global"\n',
		"\t\t\t]\n",
		"\t\t}\n",
		"\t}\n",
		"}\n",
	}

	local f = io.open(manifest_path, "w")
	if f then
		f:write(table.concat(template, ""))
		f:close()
		utils.log_info("Created " .. config.manifest_name .. " in project root!", "")
		vim.cmd("edit " .. vim.fn.fnameescape(manifest_path))
	else
		utils.log_error("Failed to create " .. config.manifest_name)
	end
end

function M.setup()
	-- Update current project addons (ignores auto_update = false)
	vim.api.nvim_create_user_command("LuaAddonUpdate", function()
		local get_clients = vim.lsp.get_clients or vim.lsp.get_active_clients
		local clients = get_clients({ name = "lua_ls" })

		if not clients or #clients == 0 then
			utils.log_warn("No active lua_ls clients found.")
			return
		end

		utils.log_info("Checking for updates...", "", "DiagnosticInfo")
		for _, client in ipairs(clients) do
			lsp.on_init(client, false, true)
		end
	end, { desc = "Force update check for active addons in current workspace" })

	-- Generate boilerplate manifest for addon developers
	vim.api.nvim_create_user_command("LAInit", function(opts)
		init_manifest(opts.bang)
	end, {
		bang = true,
		desc = "Initialize a boilerplate " .. config.manifest_name .. " in the current directory",
	})

	vim.api.nvim_create_user_command("LuaAddonInit", function(opts)
		init_manifest(opts.bang)
	end, {
		bang = true,
		desc = "Initialize a boilerplate " .. config.manifest_name .. " in the current directory",
	})
end

return M
