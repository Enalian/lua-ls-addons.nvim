local state = require("lua-ls-addons.state")
local utils = require("lua-ls-addons.utils")

local M = {}

local function read_luarc_metadata(path)
	local filepath = path .. "/.luarc.json"
	if vim.fn.filereadable(filepath) == 0 then
		filepath = path .. "/.luarc.jsonc"
	end

	if vim.fn.filereadable(filepath) == 1 then
		local file = io.open(filepath, "r")
		if file then
			local content = file:read("*a")
			file:close()
			content = content:gsub("/%*.-%*/", ""):gsub("//[^\n]*", "")
			local ok, parsed = pcall(vim.json.decode, content)
			if ok and type(parsed) == "table" then
				return parsed
			end
		end
	end

	local rc_path = path .. "/.luacheckrc"
	if vim.fn.filereadable(rc_path) == 1 then
		local env = {}
		setmetatable(env, { __index = _G })
		local chunk = loadfile(rc_path, "t", env)
		if chunk then
			local ok, _ = pcall(chunk)
			if ok and type(env.addons) == "table" then
				return env
			end
		end
	end
	return nil
end

function M.read_addon_manifest(path)
	local manifest_path = path .. "/__manifest.json"
	if vim.fn.filereadable(manifest_path) == 1 then
		local file = io.open(manifest_path, "r")
		if file then
			local content = file:read("*a")
			file:close()
			local ok, parsed = pcall(vim.json.decode, content)
			if ok and type(parsed) == "table" then
				return parsed
			end
		end
	end
	return nil
end

local function resolve_dependencies(initial_list)
	local resolved, visited, visiting = {}, {}, {}

	local function visit(addon_name)
		if visited[addon_name] then
			return
		end
		if visiting[addon_name] then
			utils.log_warn("Circular dependency detected in addon: " .. addon_name)
			return
		end

		visiting[addon_name] = true

		if addon_name ~= "vim" and state.loaded_addons[addon_name] then
			local addon_path = state.loaded_addons[addon_name].path
			local manifest = M.read_addon_manifest(addon_path) or {}

			if manifest.base and type(manifest.base) == "string" then
				if not state.loaded_addons[manifest.base] then
					utils.log_warn(
						"Addon '"
							.. addon_name
							.. "' requires base addon '"
							.. manifest.base
							.. "', but it is not installed."
					)
				else
					visit(manifest.base)
				end
			end

			if manifest.depends_on then
				local deps = type(manifest.depends_on) == "string" and { manifest.depends_on } or manifest.depends_on
				if type(deps) == "table" then
					for _, dep in ipairs(deps) do
						if not state.loaded_addons[dep] then
							utils.log_warn(
								"Addon '" .. addon_name .. "' depends on '" .. dep .. "', but it is not installed."
							)
						else
							visit(dep)
						end
					end
				end
			end
		end

		visiting[addon_name] = false
		visited[addon_name] = true
		table.insert(resolved, addon_name)
	end

	for _, name in ipairs(initial_list) do
		visit(name)
	end
	return resolved
end

function M.on_init(client, skip_notify)
	local path = client.workspace_folders and client.workspace_folders[1].name
	if not path then
		return true
	end

	local luarc = read_luarc_metadata(path)
	if luarc and type(luarc.addon) == "table" then
		local settings = client.config.settings.Lua or {}
		settings.runtime = settings.runtime or {}
		settings.workspace = settings.workspace or {}
		settings.workspace.library = settings.workspace.library or {}
		settings.diagnostics = settings.diagnostics or {}
		settings.diagnostics.globals = settings.diagnostics.globals or {}
		settings.diagnostics.disable = settings.diagnostics.disable or {}

		local has_updates = false
		local resolved_addons = resolve_dependencies(luarc.addon)

		for _, addon_name in ipairs(resolved_addons) do
			if addon_name == "vim" then
				settings.runtime.version = "LuaJIT"
				settings.workspace.checkThirdParty = false

				if not vim.tbl_contains(settings.diagnostics.globals, "vim") then
					table.insert(settings.diagnostics.globals, "vim")
				end
				if not vim.tbl_contains(settings.workspace.library, vim.env.VIMRUNTIME) then
					table.insert(settings.workspace.library, vim.env.VIMRUNTIME)
				end
				utils.log_info("Vim environment loaded", "󰢱", "DiagnosticInfo")
				has_updates = true
			elseif state.loaded_addons[addon_name] ~= nil then
				settings.runtime.version = "LuaJIT"
				settings.workspace.checkThirdParty = false

				local addon_path = state.loaded_addons[addon_name].path
				local manifest = M.read_addon_manifest(addon_path) or {}
				local custom_config = manifest.lua_ls or {}
				local user_config = state.addon_configs[addon_name] or {}
				local display_name = user_config.force_name or manifest.name or addon_name:gsub("^%l", string.upper)

				if not vim.tbl_contains(settings.workspace.library, addon_path) then
					table.insert(settings.workspace.library, addon_path)
				end

				if custom_config.workspace and type(custom_config.workspace.library) == "table" then
					for _, lib_rel_path in ipairs(custom_config.workspace.library) do
						local full_lib_path = addon_path .. "/" .. lib_rel_path
						full_lib_path = full_lib_path:gsub("//", "/")
						if not vim.tbl_contains(settings.workspace.library, full_lib_path) then
							table.insert(settings.workspace.library, full_lib_path)
						end
					end
				end

				if custom_config.diagnostics and type(custom_config.diagnostics.globals) == "table" then
					for _, global in ipairs(custom_config.diagnostics.globals) do
						if not vim.tbl_contains(settings.diagnostics.globals, global) then
							table.insert(settings.diagnostics.globals, global)
						end
					end
				end

				if custom_config.diagnostics and type(custom_config.diagnostics.disable) == "table" then
					for _, diag in ipairs(custom_config.diagnostics.disable) do
						if not vim.tbl_contains(settings.diagnostics.disable, diag) then
							table.insert(settings.diagnostics.disable, diag)
						end
					end
				else
					local default_disables = { "syntax-error", "undefined-global", "lowercase-global" }
					for _, diag in ipairs(default_disables) do
						if not vim.tbl_contains(settings.diagnostics.disable, diag) then
							table.insert(settings.diagnostics.disable, diag)
						end
					end
				end

				utils.log_info(display_name .. " environment loaded", "󰢱", "DiagnosticInfo")
				has_updates = true
			end
		end

		if has_updates then
			client.config.settings.Lua = settings
			if not skip_notify then
				client.rpc.notify("workspace/didChangeConfiguration", { settings = client.config.settings })
			end
		end
	end
	return true
end

--- Sets up an autocommand to watch for changes in lua config files
function M.setup_watcher()
	local group = vim.api.nvim_create_augroup("LuaAddonsWatcher", { clear = true })

	vim.api.nvim_create_autocmd("BufWritePost", {
		group = group,
		pattern = { ".luarc.json", ".luarc.jsonc", ".luacheckrc" },
		callback = function()
			-- Поддержка как Neovim 0.10+ (get_clients), так и старых версий
			local get_clients = vim.lsp.get_clients or vim.lsp.get_active_clients
			local clients = get_clients({ name = "lua_ls" })

			if not clients or #clients == 0 then
				return
			end

			for _, client in ipairs(clients) do
				-- Запускаем нашу логику заново. false значит "отправить уведомление серверу"
				local success = M.on_init(client, false)
				if success then
					utils.log_info("Config file changed, lua_ls environment updated!", "", "DiagnosticInfo")
				end
			end
		end,
		desc = "Hot reload lua_ls when config files change",
	})
end

return M
