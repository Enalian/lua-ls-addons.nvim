local config = require("lua-addons.config")
local state = require("lua-ls-addons.state")
local utils = require("lua-ls-addons.utils")

local M = {}

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
---@return string|nil actual_version The resolved tag name of the release.
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

	return true, release.tag_name
end

--- Ensures the requested addon is installed locally, downloading it if necessary.
---@param parsed ParsedAddonString The parsed addon data.
---@param force_auto_update? boolean Override for the global auto_update flag.
---@return string|nil path The absolute path to the addon directory.
---@return string|nil actual_ver The actual version (hash or tag) resolved.
function M.ensure_installed(parsed, force_auto_update)
	local target_version = parsed.version
	local auto_update = force_auto_update ~= nil and force_auto_update or state.global_config.auto_update

	if parsed.version == "latest" and auto_update then
		if not parsed.is_release then
			target_version = get_latest_commit(parsed.repo) or "latest"
		end
	end

	local target_dir = vim.fn.expand(config.base_dir .. "/" .. parsed.original_name .. "/" .. target_version)
	if vim.fn.isdirectory(target_dir) == 1 then
		return target_dir, target_version
	end

	local success, actual_ver = false, nil
	if parsed.is_release then
		success, actual_ver = download_release(parsed.repo, target_dir, parsed.version, parsed.release_pattern)
		if success and actual_ver then
			target_version = actual_ver
		end
	else
		success = download_git(parsed.repo, target_dir, target_version)
	end

	if success then
		utils.log_info("Installed " .. parsed.original_name .. " (" .. target_version:sub(1, 7) .. ")", "")
		return target_dir, target_version
	end

	return nil, nil
end

return M
