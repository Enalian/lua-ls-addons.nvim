local config = require("lua-ls-addons.config")
local state = require("lua-ls-addons.state")
local utils = require("lua-ls-addons.utils")

local M = {}

local CHECK_CACHE_FILE = config.base_dir .. "/" .. (config.cache_name or "check_cache.json")

--- Loads the update check cache timestamps.
---@return table<string, integer>
local function load_check_cache()
	if vim.fn.filereadable(CHECK_CACHE_FILE) == 1 then
		local f = io.open(CHECK_CACHE_FILE, "r")
		if f then
			local ok, data = pcall(vim.json.decode, f:read("*a"))
			f:close()
			if ok and type(data) == "table" then
				return data
			end
		end
	end
	return {}
end

--- Saves the update check cache timestamps.
---@param data table<string, integer>
local function save_check_cache(data)
	vim.fn.mkdir(config.base_dir, "p")
	local f = io.open(CHECK_CACHE_FILE, "w")
	if f then
		local lines = { "{" }
		local keys = vim.tbl_keys(data)
		table.sort(keys)
		for i, k in ipairs(keys) do
			table.insert(lines, string.format('\t"%s": %d%s', k, data[k], (i == #keys) and "" or ","))
		end
		table.insert(lines, "}")
		f:write(table.concat(lines, "\n") .. "\n")
		f:close()
	end
end

--- Retrieves the latest commit hash for a given remote repository.
---@param repo string Repository in 'author/repo' format.
---@return string|nil commit_hash The latest commit hash, or nil if failed.
local function get_latest_commit(repo)
	local cmd = string.format("git ls-remote https://github.com/%s.git HEAD", repo)
	local handle = io.popen(cmd)
	if not handle then
		return nil
	end
	local result = handle:read("*a")
	handle:close()
	return result:match("^(%w+)")
end

--- Retrieves the latest release tag or title matching the pattern.
---@param repo string Repository in 'author/repo' format.
---@param pattern string Lua regex pattern to match the asset name.
---@return string|nil release_version The latest release version name/tag, or nil if failed.
local function get_latest_release_tag(repo, pattern)
	if vim.fn.executable("curl") == 0 then
		return nil
	end
	local api_url = string.format("https://api.github.com/repos/%s/releases/latest", repo)
	local handle = io.popen(string.format("curl -s %s", api_url))
	if not handle then
		return nil
	end
	local json_str = handle:read("*a")
	handle:close()

	local ok, release = pcall(vim.json.decode, json_str)
	if ok and release then
		if release.assets then
			for _, asset in ipairs(release.assets) do
				if asset.name:match(pattern) then
					return (release.name and release.name ~= "") and release.name or release.tag_name
				end
			end
		end
	end
	return nil
end

--- Downloads a repository using git clone.
---@param repo string Repository in 'author/repo' format.
---@param target_dir string The destination path.
---@param version string Commit hash or tag to checkout.
---@return boolean success True if the download was successful.
local function download_git(repo, target_dir, version)
	if vim.fn.executable("git") == 0 then
		utils.log_error("'git' is not installed, cannot download repository.")
		return false
	end

	vim.fn.mkdir(target_dir, "p")
	local cmd = string.format("git clone --quiet https://github.com/%s.git %s", repo, target_dir)
	vim.fn.system(cmd)
	if vim.v.shell_error ~= 0 then
		return false
	end

	if version and version ~= "latest" then
		vim.fn.system(string.format("git -C %s checkout --quiet %s", target_dir, version))
	end

	vim.fn.delete(target_dir .. "/.git", "rf")
	return true
end

--- Downloads and extracts a specific asset from a GitHub Release.
---@param repo string Repository in 'author/repo' format.
---@param target_dir string The destination path.
---@param version string Release tag or 'latest'.
---@param pattern string Lua regex pattern to match the asset name.
---@return boolean success True if successful.
---@return string|nil actual_version The resolved version string (release name or tag).
local function download_release(repo, target_dir, version, pattern)
	if vim.fn.executable("curl") == 0 then
		utils.log_error("'curl' is not installed, cannot download release.")
		return false, nil
	end
	if vim.fn.executable("unzip") == 0 then
		utils.log_error("'unzip' is not installed, cannot extract release.")
		return false, nil
	end

	local api_url = "https://api.github.com/repos/" .. repo .. "/releases"
	api_url = (version == "latest") and (api_url .. "/latest") or (api_url .. "/tags/" .. version)

	local handle = io.popen(string.format("curl -s %s", api_url))
	if not handle then
		return false, nil
	end
	local json_str = handle:read("*a")
	handle:close()

	local ok, release = pcall(vim.json.decode, json_str)
	if not ok or not release or not release.assets then
		return false, nil
	end

	local asset_url = nil
	for _, asset in ipairs(release.assets) do
		if asset.name:match(pattern) then
			asset_url = asset.browser_download_url
			break
		end
	end

	if not asset_url then
		return false, nil
	end

	vim.fn.mkdir(target_dir, "p")
	local zip_path = target_dir .. "/temp.zip"
	vim.fn.system(string.format("curl -sL -o %s %s", zip_path, asset_url))
	if vim.v.shell_error ~= 0 then
		return false, nil
	end

	vim.fn.system(string.format("unzip -q %s -d %s", zip_path, target_dir))
	vim.fn.delete(zip_path)

	local release_version = (release.name and release.name ~= "") and release.name or release.tag_name
	return true, release_version
end

--- Ensures the requested addon is installed locally, downloading it if necessary.
---@param parsed ParsedAddonString The parsed addon data.
---@param locked_version? string The version locked in the project's lockfile.
---@param force_update? boolean Override to force a network check bypassing the interval.
---@param custom_interval? integer Optional per-addon check interval in seconds.
---@return string|nil path The absolute path to the addon directory.
---@return string|nil actual_ver The actual version (hash or tag/title) resolved.
function M.ensure_installed(parsed, locked_version, force_update, custom_interval)
	local target_version = locked_version or parsed.version
	local is_latest = (parsed.version == "latest")
	local auto_update = state.global_config.auto_update
	local interval = custom_interval or state.global_config.check_interval

	if is_latest and auto_update then
		local cache = load_check_cache()
		local last_checked = cache[parsed.repo] or 0
		local now = os.time()

		if force_update or (now - last_checked > interval) or not locked_version then
			local remote_ver = nil
			if parsed.is_release then
				remote_ver = get_latest_release_tag(parsed.repo, parsed.release_pattern)
			else
				remote_ver = get_latest_commit(parsed.repo)
			end

			if remote_ver then
				target_version = remote_ver
			end

			cache[parsed.repo] = now
			save_check_cache(cache)
		end
	end

	if target_version == "latest" then
		target_version = locked_version or "master"
	end

	local target_dir = vim.fn.expand(config.base_dir .. "/" .. parsed.original_name .. "/" .. target_version)
	if vim.fn.isdirectory(target_dir) == 1 then
		return target_dir, target_version
	end

	local success, actual_ver = false, nil
	if parsed.is_release then
		success, actual_ver = download_release(parsed.repo, target_dir, target_version, parsed.release_pattern)
		if success and actual_ver then
			target_version = actual_ver
		end
	else
		success = download_git(parsed.repo, target_dir, target_version)
	end

	if success then
		utils.log_info(string.format("Installed %s (%s)", parsed.original_name, target_version:sub(1, 7)), "")
		return target_dir, target_version
	end

	return nil, nil
end

return M
