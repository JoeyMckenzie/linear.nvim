---@diagnostic disable: duplicate-set-field, redundant-return-value, need-check-nil, return-type-mismatch
---Minimal Neovim init for running tests
---Sets up the test environment without loading a full config

---Setup runtimepath
local function setup_runtimepath()
	-- Only set runtimepath if vim.opt exists (running in Neovim)
	if vim and vim.opt then
		vim.opt.rtp:prepend(".")
	end
end

---Setup test environment variables
local function setup_env()
	-- Note: os.setenv is not available in Lua 5.1
	-- Tests will use existing LINEAR_API_KEY environment variable
end

-- Set up runtimepath
setup_runtimepath()

-- Set environment for tests
setup_env()

---Setup vim.notify
local function setup_notify()
	if not vim.notify then
		vim.notify = function(msg, _level)
			print("[NOTIFY] " .. msg)
		end
	end
end

---Setup vim.log levels
local function setup_log()
	if not vim.log or not vim.log.levels then
		vim.log = {
			levels = {
				TRACE = 0,
				DEBUG = 1,
				INFO = 2,
				WARN = 3,
				ERROR = 4,
			},
		}
	end
end

---Setup vim.api
local function setup_api()
	if not vim.api or not vim.api.nvim_create_user_command then
		vim.api = vim.api or {}
		vim.api.nvim_create_user_command = function(_name, _fn, _opts)
			-- Mock implementation
		end
	end
end

---Setup vim.fn utilities
local function setup_fn()
	if not vim.fn then
		vim.fn = {}
	end

	if not vim.fn.fnamemodify then
		vim.fn.fnamemodify = function(path, modifier)
			if modifier == ":p" then
				local cwd = (vim and vim.loop and vim.loop.cwd) and vim.loop.cwd() or os.getenv("PWD") or "."
				return cwd .. "/" .. path
			end
			return path
		end
	end

	if not vim.fn.stdpath then
		vim.fn.stdpath = function(what)
			if what == "data" then
				return os.getenv("HOME") .. "/.local/share/nvim"
			end
			local cwd = (vim and vim.loop and vim.loop.cwd) and vim.loop.cwd() or os.getenv("PWD") or "."
			return cwd
		end
	end

	if not vim.fn.glob then
		vim.fn.glob = function(pattern, _nosuf, _list)
			local files = {}
			if vim and vim.loop and vim.loop.fs_scandir then
				for file in vim.loop.fs_scandir(".") do
					if file:match(pattern:gsub("*", ".*")) then
						table.insert(files, file)
					end
				end
			end
			return files
		end
	end
end

---Simple JSON decoder for test environment
---@param json_str string
---@return table
local function simple_json_decode(json_str)
	-- Trim whitespace
	json_str = json_str:gsub("^%s+", ""):gsub("%s+$", "")

	-- Handle null, true, false
	if json_str == "null" then return nil end
	if json_str == "true" then return true end
	if json_str == "false" then return false end

	-- Handle strings
	if json_str:sub(1, 1) == '"' then
		return json_str:sub(2, -2):gsub('\\"', '"')
	end

	-- Handle numbers
	if tonumber(json_str) then
		return tonumber(json_str)
	end

	-- Handle objects and arrays - simple recursive descent parser
	local function parse_value(str, pos)
		while pos <= #str and str:sub(pos, pos):match("%s") do
			pos = pos + 1
		end

		if pos > #str then return nil, pos end

		local ch = str:sub(pos, pos)
		if ch == '"' then
			-- Parse string
			pos = pos + 1
			local start = pos
			while pos <= #str do
				if str:sub(pos, pos) == '"' and str:sub(pos - 1, pos - 1) ~= "\\" then
					return str:sub(start, pos - 1):gsub('\\"', '"'), pos + 1
				end
				pos = pos + 1
			end
			return str:sub(start), pos
		elseif ch == "{" then
			-- Parse object
			local obj = {}
			pos = pos + 1
			while pos <= #str do
				while pos <= #str and str:sub(pos, pos):match("%s") do pos = pos + 1 end
				if str:sub(pos, pos) == "}" then return obj, pos + 1 end

				-- Parse key
				local key, key_pos = parse_value(str, pos)
				pos = key_pos

				while pos <= #str and str:sub(pos, pos):match("%s") do pos = pos + 1 end
				if str:sub(pos, pos) == ":" then pos = pos + 1 end
				while pos <= #str and str:sub(pos, pos):match("%s") do pos = pos + 1 end

				-- Parse value
				local val, val_pos = parse_value(str, pos)
				pos = val_pos
				obj[key] = val

				while pos <= #str and str:sub(pos, pos):match("%s") do pos = pos + 1 end
				if str:sub(pos, pos) == "," then pos = pos + 1 end
			end
			return obj, pos
		elseif ch == "[" then
			-- Parse array
			local arr = {}
			pos = pos + 1
			while pos <= #str do
				while pos <= #str and str:sub(pos, pos):match("%s") do pos = pos + 1 end
				if str:sub(pos, pos) == "]" then return arr, pos + 1 end

				local val, new_pos = parse_value(str, pos)
				pos = new_pos
				table.insert(arr, val)

				while pos <= #str and str:sub(pos, pos):match("%s") do pos = pos + 1 end
				if str:sub(pos, pos) == "," then pos = pos + 1 end
			end
			return arr, pos
		elseif ch == "t" or ch == "f" or ch == "n" then
			-- true, false, null
			if str:sub(pos, pos + 3) == "true" then return true, pos + 4 end
			if str:sub(pos, pos + 4) == "false" then return false, pos + 5 end
			if str:sub(pos, pos + 3) == "null" then return nil, pos + 4 end
		else
			-- number
			local num_str = ""
			while pos <= #str and (str:sub(pos, pos):match("[0-9.%-+eE]")) do
				num_str = num_str .. str:sub(pos, pos)
				pos = pos + 1
			end
			return tonumber(num_str), pos
		end
		return nil, pos
	end

	local result, _ = parse_value(json_str, 1)
	return result
end

---Setup vim.json utilities
local function setup_json()
	if not vim.json or not vim.json.encode then
		vim.json = vim.json or {}
		vim.json.encode = function(obj)
			-- Try to use cjson if available
			local ok, cjson = pcall(require, "cjson")
			if ok then
				return cjson.encode(obj)
			end
			-- Fallback for simple types
			if type(obj) == "string" then
				return '"' .. obj:gsub('"', '\\"') .. '"'
			elseif type(obj) == "number" then
				return tostring(obj)
			elseif type(obj) == "boolean" then
				return obj and "true" or "false"
			elseif type(obj) == "table" then
				return "{}"
			end
			return "null"
		end
	end

	if not vim.json.decode then
		vim.json.decode = function(json_str)
			-- Try to use cjson if available
			local ok, cjson = pcall(require, "cjson")
			if ok then
				return cjson.decode(json_str)
			end
			-- Fallback: use simple JSON decoder
			return simple_json_decode(json_str)
		end
	end
end

---Setup vim.tbl utilities
local function setup_tbl()
	if not vim.tbl_deep_extend then
		vim.tbl_deep_extend = function(mode, tbl1, tbl2)
			local result = {}
			for k, v in pairs(tbl1) do
				if type(v) == "table" then
					result[k] = vim.tbl_deep_extend(mode, v, tbl2[k] or {})
				else
					result[k] = v
				end
			end
			for k, v in pairs(tbl2) do
				if result[k] == nil then
					result[k] = v
				elseif type(v) == "table" and type(result[k]) == "table" then
					result[k] = vim.tbl_deep_extend(mode, result[k], v)
				else
					if mode == "force" then
						result[k] = v
					end
				end
			end
			return result
		end
	end

	if not vim.tbl_contains then
		vim.tbl_contains = function(tbl, val)
			for _, v in ipairs(tbl) do
				if v == val then
					return true
				end
			end
			return false
		end
	end
end

---Setup vim.deepcopy utility
local function setup_deepcopy()
	if not vim.deepcopy then
		vim.deepcopy = function(obj)
			if type(obj) ~= "table" then
				return obj
			end
			local result = {}
			for k, v in pairs(obj) do
				result[k] = vim.deepcopy(v)
			end
			return result
		end
	end
end

-- Setup vim globals
setup_notify()
setup_log()
setup_api()
setup_fn()
setup_json()
setup_tbl()
setup_deepcopy()
