#!/usr/bin/env lua

-- Test script for Linear.nvim authentication
-- Usage: lua test_auth.lua

-- Make sure we can find the lua modules
package.path = package.path .. ";./lua/?.lua"

-- We'll need a minimal vim environment for testing
-- Create a mock vim object with the functions we need
if not vim then
	vim = {
		log = {
			levels = {
				INFO = 0,
				WARN = 1,
				ERROR = 2,
			},
		},
		notify = function(msg, level)
			print("[" .. (level or 0) .. "] " .. msg)
		end,
		json = {
			encode = function(tbl)
				-- Simple JSON encoder
				return require("cjson").encode(tbl)
			end,
			decode = function(json_str)
				-- Simple JSON decoder
				return require("cjson").decode(json_str)
			end,
		},
		tbl_deep_extend = function(mode, tbl1, tbl2)
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
		end,
	}
end

print("Testing Linear.nvim authentication...")
print("LINEAR_API_KEY env var: " .. (os.getenv("LINEAR_API_KEY") or "NOT SET"))

-- Try to load config
local status, config = pcall(require, "linear.config")
if not status then
	print("ERROR: Could not load config module")
	print(config)
	os.exit(1)
end

print("✓ Config module loaded")

-- Get the API key
local api_key = config.get_api_key()
if api_key then
	print("✓ API key found: " .. api_key:sub(1, 10) .. "...")
else
	print("✗ No API key found")
	os.exit(1)
end

-- Try to load API module
local status, api = pcall(require, "linear.api")
if not status then
	print("ERROR: Could not load API module")
	print(api)
	os.exit(1)
end

print("✓ API module loaded")
print("\nAuthentication test complete. Plugin structure is ready!")
