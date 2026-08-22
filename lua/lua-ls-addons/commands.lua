local utils = require("lua-ls-addons.utils")
local lsp = require("lua-ls-addons.lsp")

local M = {}

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
end

return M
