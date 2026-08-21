local state = require("lua-ls-addons.state")
local utils = require("lua-ls-addons.utils")

local M = {}

local function check_needs_update(key, ver_config, cache, api_data)
	local remote_ver_id = api_data.tag_name or api_data.name
	local local_ver_id = cache.current_version

	if ver_config.type == "disabled" then
		return false, remote_ver_id
	end
	if ver_config.type == "custom" then
		if type(ver_config.format) == "function" then
			return ver_config.format(remote_ver_id, local_ver_id), remote_ver_id
		end
		return false, remote_ver_id
	end

	if ver_config.type == "numbered" then
		local cmp = utils.compare_versions(local_ver_id, remote_ver_id)
		if cmp == 1 then
			utils.log_warn(
				string.format(
					"Typings for '%s' are locally newer (%s) than remote release (%s)",
					key,
					local_ver_id,
					remote_ver_id
				)
			)
			return false, remote_ver_id
		elseif cmp == -1 then
			return true, remote_ver_id
		else
			return false, remote_ver_id
		end
	end

	if ver_config.type == "datetime" then
		return (local_ver_id ~= remote_ver_id), remote_ver_id
	end
	if ver_config.type == "timestamp" then
		local remote_time = utils.parse_github_date(api_data.name)
		return (not cache.local_time or (remote_time and remote_time > cache.local_time)), remote_ver_id
	end

	return false, remote_ver_id
end

local function get_download_url(api_data, pattern)
	if type(api_data.assets) == "table" then
		for _, asset in ipairs(api_data.assets) do
			if asset.name and asset.name:match(pattern) then
				return asset.browser_download_url
			end
		end
	end
	return api_data.zipball_url
end

local function register_addon_info(key, repo, target_dir, version)
	local owner = repo:match("^([^/]+)/")
	state.loaded_addons[key] = {
		name = key,
		repo = "https://github.com/" .. repo,
		version = version or "unknown",
		author = { name = owner or "unknown", url = owner and ("https://github.com/" .. owner) or "" },
		path = target_dir,
	}
end

local function do_git_sync(key, repo, target_dir, branch, is_forced, on_success)
	vim.fn.mkdir(target_dir, "p")
	local cmd = vim.fn.isdirectory(target_dir .. "/.git") == 1 and { "git", "-C", target_dir, "pull", "--quiet" }
		or (
			branch
				and {
					"git",
					"clone",
					"-b",
					branch,
					"--depth",
					"1",
					"--quiet",
					"https://github.com/" .. repo .. ".git",
					target_dir,
				}
			or { "git", "clone", "--depth", "1", "--quiet", "https://github.com/" .. repo .. ".git", target_dir }
		)

	vim.fn.jobstart(cmd, {
		on_exit = function(_, code)
			if code == 0 then
				register_addon_info(key, repo, target_dir, "commit")
				on_success("commit")
				local msg = is_forced and ("Repository '" .. key .. "' checked (Git)")
					or ("Repository '" .. key .. "' updated!")
				utils.log_info(msg)
			end
		end,
	})
end

local function do_release_sync(key, repo, target_dir, release_pattern, ver_config, cache, is_forced, on_success)
	local api_url = "https://api.github.com/repos/" .. repo .. "/releases/latest"
	local api_output = {}

	vim.fn.jobstart({ "curl", "-s", api_url }, {
		stdout_buffered = true,
		on_stdout = function(_, data)
			if data then
				for _, line in ipairs(data) do
					table.insert(api_output, line)
				end
			end
		end,
		on_exit = function(_, code)
			if code ~= 0 then
				register_addon_info(key, repo, target_dir, cache.current_version)
				return on_success(nil)
			end

			local ok, api_data = pcall(vim.json.decode, table.concat(api_output, ""))
			if not ok or type(api_data) ~= "table" or not api_data.name then
				register_addon_info(key, repo, target_dir, cache.current_version)
				return on_success(nil)
			end

			local needs_update, remote_ver = check_needs_update(key, ver_config, cache, api_data)
			if not needs_update then
				register_addon_info(key, repo, target_dir, cache.current_version)
				if is_forced then
					utils.log_info(
						"Typings for '" .. key .. "' are up to date (version: " .. remote_ver .. ")",
						"",
						"DiagnosticInfo"
					)
				end
				return on_success(cache.current_version)
			end

			local url = get_download_url(api_data, release_pattern)
			if not url then
				register_addon_info(key, repo, target_dir, cache.current_version)
				return
			end

			local tmp_zip = vim.fn.stdpath("cache") .. "/" .. key .. "-api.zip"
			utils.log_info("Downloading update for: " .. key, "", "DiagnosticInfo")
			vim.fn.mkdir(target_dir, "p")

			local dl_cmd = string.format(
				"curl -sL '%s' -o '%s' && unzip -qo '%s' -d '%s' && rm -f '%s'",
				url,
				tmp_zip,
				tmp_zip,
				target_dir,
				tmp_zip
			)
			vim.fn.jobstart({ "bash", "-c", dl_cmd }, {
				on_exit = function(_, final_code)
					if final_code == 0 then
						register_addon_info(key, repo, target_dir, remote_ver)
						on_success(remote_ver)
						utils.log_info("Typings for '" .. key .. "' successfully updated!")
					end
				end,
			})
		end,
	})
end

function M.process_addon(key, config, is_forced)
	local target_dir = vim.fn.expand("~/.local/share/nvim/lua-addons/" .. key)
	local metadata_path = target_dir .. "/__metadata.json"
	local cache = utils.read_cache(metadata_path)

	register_addon_info(
		key,
		config.repo,
		target_dir,
		cache.current_version or (config.ver_config.type == "commit" and "commit" or nil)
	)

	if not is_forced then
		if config.auto_update == false then
			return
		end
		if os.time() < cache.next_check then
			return
		end
	end

	local function on_success(new_version)
		utils.write_cache(target_dir, metadata_path, config.check_interval, new_version)
	end

	if config.ver_config.type == "commit" then
		do_git_sync(key, config.repo, target_dir, config.branch, is_forced, on_success)
	else
		do_release_sync(
			key,
			config.repo,
			target_dir,
			config.release_name,
			config.ver_config,
			cache,
			is_forced,
			on_success
		)
	end
end

return M
