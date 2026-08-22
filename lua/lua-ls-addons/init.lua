local state = require("lua-ls-addons.state")
local commands = require("lua-ls-addons.commands")
local lsp = require("lua-ls-addons.lsp")

local M = {}

--- LSP on_init hook to be passed to nvim-lspconfig.
---@param client vim.lsp.Client
---@param skip_notify? boolean
---@return boolean
M.on_init = lsp.on_init

--- Initializes the Lua Addons Manager.
---@param opts LuaAddonsSetupOptions Configuration options.
function M.setup(opts)
	opts = type(opts) == "table" and opts or {}

	state.global_config.auto_update = opts.auto_update ~= false
	state.global_config.watch_configs = opts.watch_configs ~= false
	state.aliases = type(opts.aliases) == "table" and opts.aliases or {}

	commands.setup(M)

	if state.global_config.watch_configs then
		lsp.setup_watcher()
	end
end

return M
