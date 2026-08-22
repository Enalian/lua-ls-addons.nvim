local state = require("lua-ls-addons.state")
local utils = require("lua-ls-addons.utils")
local config = require("lua-ls-addons.config")
local sync = require("lua-ls-addons.sync")

local M = {}

--- Reads and parses .luarc.json or .luacheckrc
---@param path string
---@return table|nil
local function read_luarc(path)
	local filepath = path .. "/.luarc.json"
	if vim.fn.filereadable(filepath) == 0 then
		filepath = path .. "/.luarc.jsonc"
	end

	if vim.fn.filereadable(filepath) == 1 then
		local f = io.open(filepath, "r")
		if f then
			local content = f:read("*a"):gsub("/%*.-%*/", ""):gsub("//[^\n]*", "")
			f:close()
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

--- Reads the addon's manifest file
---@param path string
---@return table|nil
function M.read_manifest(path)
	local manifest_path = path .. "/" .. config.manifest_name
	if vim.fn.filereadable(manifest_path) == 1 then
		local f = io.open(manifest_path, "r")
		if f then
			local ok, parsed = pcall(vim.json.decode, f:read("*a"))
			f:close()
			if ok and type(parsed) == "table" then
				return parsed
			end
		end
	end
	return nil
end

--- Reads or writes the lockfile
---@param path string
---@param data table|nil If nil, reads. Otherwise, writes.
---@return table
local function rw_lockfile(path, data)
	local lock_path = path .. "/" .. config.lockfile_name
	if not data then
		if vim.fn.filereadable(lock_path) == 1 then
			local f = io.open(lock_path, "r")
			if f then
				local ok, parsed = pcall(vim.json.decode, f:read("*a"))
				f:close()
				return ok and parsed or {}
			end
		end
		return {}
	else
		local f = io.open(lock_path, "w")
		if f then
			local lines = { "{" }
			local keys = vim.tbl_keys(data)
			table.sort(keys)
			for i, k in ipairs(keys) do
				table.insert(lines, string.format('\t"%s": "%s"%s', k, data[k], (i == #keys) and "" or ","))
			end
			table.insert(lines, "}")
			f:write(table.concat(lines, "\n") .. "\n")
			f:close()
		end
		return data
	end
end

--- Recursively processes dependencies and injects them into the settings
local function process_tree(addon_raw, lockfile, settings, visited, visiting, has_upd, used_vers, force_update)
	local start_time = vim.uv.hrtime()
	local req_str = type(addon_raw) == "table" and addon_raw.addon or addon_raw
	local parsed = utils.parse_addon_string(req_str, state.aliases)
	local name = parsed.original_name

	if visited[name] then
		return
	end
	if visiting[name] then
		utils.log_warn("Circular dependency detected in: " .. name)
		return
	end

	visiting[name] = true

	if name == "vim" then
		settings.runtime.version = "LuaJIT"
		settings.workspace.checkThirdParty = false
		if not vim.tbl_contains(settings.diagnostics.globals, "vim") then
			table.insert(settings.diagnostics.globals, "vim")
		end
		if not vim.tbl_contains(settings.workspace.library, vim.env.VIMRUNTIME) then
			table.insert(settings.workspace.library, vim.env.VIMRUNTIME)
		end
		has_upd.status = true
		visiting[name] = false
		visited[name] = true

		local elapsed_ms = math.floor((vim.uv.hrtime() - start_time) / 1000000)
		utils.log_info(string.format("Addon Vim successfully loaded in %d ms", elapsed_ms), "󰢱", "DiagnosticInfo")
		return
	else
		local addon_path, actual_ver = nil, nil

		if req_str:match("^[/~]") or req_str:match("^[A-Za-z]:\\") then
			addon_path = vim.fn.expand(req_str)
		else
			local locked_ver = lockfile[name]
			local auto = type(addon_raw) == "table" and addon_raw.auto_update or force_update
			local interval = type(addon_raw) == "table" and addon_raw.check_interval or nil
			addon_path, actual_ver = sync.ensure_installed(parsed, locked_ver, auto, interval)
		end

		if addon_path then
			if actual_ver then
				used_vers[name] = actual_ver
			end
			local manifest = M.read_manifest(addon_path) or {}

			if manifest.base then
				process_tree(manifest.base, lockfile, settings, visited, visiting, has_upd, used_vers, force_update)
			end
			if manifest.depends_on then
				local deps = type(manifest.depends_on) == "string" and { manifest.depends_on } or manifest.depends_on
				for _, dep in ipairs(deps) do
					process_tree(dep, lockfile, settings, visited, visiting, has_upd, used_vers, force_update)
				end
			end

			local custom = manifest.lua_ls or {}
			local d_name = (type(addon_raw) == "table" and addon_raw.force_name)
				or manifest.name
				or name:gsub("^%l", string.upper)

			if not vim.tbl_contains(settings.workspace.library, addon_path) then
				table.insert(settings.workspace.library, addon_path)
			end

			if custom.diagnostics and custom.diagnostics.globals then
				for _, g in ipairs(custom.diagnostics.globals) do
					if not vim.tbl_contains(settings.diagnostics.globals, g) then
						table.insert(settings.diagnostics.globals, g)
					end
				end
			end

			local disables = custom.diagnostics and custom.diagnostics.disable
				or { "syntax-error", "undefined-global", "lowercase-global" }
			for _, d in ipairs(disables) do
				if not vim.tbl_contains(settings.diagnostics.disable, d) then
					table.insert(settings.diagnostics.disable, d)
				end
			end

			has_upd.status = true
			visiting[name] = false
			visited[name] = true

			local elapsed_ms = math.floor((vim.uv.hrtime() - start_time) / 1000000)
			utils.log_info(
				string.format("Addon %s successfully loaded in %d ms", d_name, elapsed_ms),
				"󰢱",
				"DiagnosticInfo"
			)
			return
		end
	end

	visiting[name] = false
	visited[name] = true
end

--- LSP on_init hook to be passed to nvim-lspconfig.
---@param client table The initialized Neovim LSP client object.
---@param skip_notify? boolean If true, suppresses sending `workspace/didChangeConfiguration`.
---@param force_update? boolean If true, forces the plugin to fetch the latest updates.
---@return boolean
function M.on_init(client, skip_notify, force_update)
	local path = client.workspace_folders and client.workspace_folders[1].name
	if not path then
		return true
	end

	local luarc = read_luarc(path)
	if luarc and type(luarc.addons) == "table" then
		local lockfile = rw_lockfile(path, nil)
		local settings = client.config.settings.Lua
			or { runtime = {}, workspace = { library = {} }, diagnostics = { globals = {}, disable = {} } }
		settings.runtime = settings.runtime or {}
		settings.workspace = settings.workspace or {}
		settings.workspace.library = settings.workspace.library or {}
		settings.diagnostics = settings.diagnostics or {}
		settings.diagnostics.globals = settings.diagnostics.globals or {}
		settings.diagnostics.disable = settings.diagnostics.disable or {}

		local visited, visiting, used_vers, has_upd = {}, {}, {}, { status = false }

		for _, req in ipairs(luarc.addons) do
			process_tree(req, lockfile, settings, visited, visiting, has_upd, used_vers, force_update)
		end

		local changed = false
		for k, v in pairs(used_vers) do
			if lockfile[k] ~= v then
				changed = true
				break
			end
		end
		if not changed then
			for k, _ in pairs(lockfile) do
				if not used_vers[k] then
					changed = true
					break
				end
			end
		end

		if changed then
			rw_lockfile(path, used_vers)
		end

		if has_upd.status then
			client.config.settings.Lua = settings
			if not skip_notify then
				client.rpc.notify("workspace/didChangeConfiguration", { settings = client.config.settings })
			end
		end
	end
	return true
end

function M.setup_watcher()
	local group = vim.api.nvim_create_augroup("LuaAddonsWatcher", { clear = true })
	vim.api.nvim_create_autocmd("BufWritePost", {
		group = group,
		pattern = { ".luarc.json", ".luarc.jsonc", ".luacheckrc" },
		callback = function()
			local get_clients = vim.lsp.get_clients or vim.lsp.get_active_clients
			local clients = get_clients({ name = "lua_ls" })
			if not clients then
				return
			end
			for _, client in ipairs(clients) do
				if M.on_init(client, false, false) then
					-- environment updated via watcher
				end
			end
		end,
		desc = "Hot reload lua_ls when config files change",
	})
end

return M
