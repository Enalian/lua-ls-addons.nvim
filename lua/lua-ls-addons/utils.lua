local M = {}

function M.log_info(msg, icon, hl)
	vim.api.nvim_echo({ { "[ " .. (icon or "") .. " ] ", hl or "DiagnosticOk" }, { msg, "Normal" } }, true, {})
end

function M.log_warn(msg, icon)
	vim.api.nvim_echo({ { "[ " .. (icon or "") .. " ] ", "DiagnosticWarn" }, { msg, "Normal" } }, true, {})
end

function M.log_error(msg, icon)
	vim.api.nvim_echo({ { "[ " .. (icon or "") .. " ] ", "DiagnosticError" }, { msg, "Normal" } }, true, {})
end

function M.parse_repo(src)
	local owner, repo = src:match("github%.com/([^/]+)/([^/%.]+)")
	return (owner and repo) and (owner .. "/" .. repo) or src
end

function M.parse_github_date(date_str)
	local m, d, y, h, min, s, ampm = date_str:match("(%d+)/(%d+)/(%d+),%s*(%d+):(%d+):(%d+)%s*(%a+)")
	if not m then
		return nil
	end
	h = tonumber(h) or 0
	if ampm:upper() == "PM" and h < 12 then
		h = h + 12
	end
	if ampm:upper() == "AM" and h == 12 then
		h = 0
	end
	return os.time({
		year = tonumber(y),
		month = tonumber(m),
		day = tonumber(d),
		hour = h,
		min = tonumber(min),
		sec = tonumber(s),
	})
end

function M.compare_versions(v1, v2)
	if v1 == v2 then
		return 0
	end
	if not v1 then
		return -1
	end
	if not v2 then
		return 1
	end

	local s1 = v1:gsub("^%D+", "")
	local s2 = v2:gsub("^%D+", "")
	local iter1 = s1:gmatch("%d+")
	local iter2 = s2:gmatch("%d+")

	while true do
		local n1, n2 = iter1(), iter2()
		if not n1 and not n2 then
			return 0
		end
		if not n1 then
			return -1
		end
		if not n2 then
			return 1
		end

		n1, n2 = tonumber(n1), tonumber(n2)
		if n1 > n2 then
			return 1
		end
		if n1 < n2 then
			return -1
		end
	end
end

function M.read_cache(metadata_path)
	local cache = { next_check = 0, current_version = nil, local_time = nil }
	if vim.fn.filereadable(metadata_path) == 1 then
		local f = io.open(metadata_path, "r")
		if f then
			local ok, json = pcall(vim.json.decode, f:read("*a"))
			f:close()
			if ok and type(json) == "table" then
				cache.next_check = tonumber(json.next_check) or 0
				cache.current_version = json.current_version
			end
		end
	end
	return cache
end

function M.write_cache(target_dir, metadata_path, check_interval, new_version)
	local data = M.read_cache(metadata_path)
	data.next_check = os.time() + check_interval
	if new_version then
		data.current_version = new_version
	end
	vim.fn.mkdir(target_dir, "p")
	local f = io.open(metadata_path, "w")
	if f then
		f:write(vim.json.encode(data))
		f:close()
	end
end

return M
