local state = require("lua-ls-addons.state")
local preset = require("lua-ls-addons.preset")
local commands = require("lua-ls-addons.commands")
local lsp = require("lua-ls-addons.lsp")

local M = {
	--- LSP on_init hook to be passed to nvim-lspconfig.
	on_init = lsp.on_init,
}

--- Initializes the Lua Addons Manager.
---@param opts LuaAddonsSetupOptions Configuration options.
function M.setup(opts)
	opts = type(opts) == "table" and opts or {}

	state.global_config.auto_update = opts.auto_update ~= false
	state.global_config.watch_configs = opts.watch_configs ~= false
	state.global_config.notifications = opts.notifications ~= false

	if opts.check_interval and type(opts.check_interval) == "number" then
		state.global_config.check_interval = opts.check_interval
	end

	state.aliases = {}
	local user_aliases = type(opts.aliases) == "table" and opts.aliases or {}

	if user_aliases.default then
		for k, v in pairs(preset) do
			state.aliases[k] = v
		end
	end

	for k, v in pairs(user_aliases) do
		if k ~= "default" then
			state.aliases[k] = v
		end
	end

	commands.setup()
	if state.global_config.watch_configs then
		lsp.setup_watcher()
	end
end

return M
