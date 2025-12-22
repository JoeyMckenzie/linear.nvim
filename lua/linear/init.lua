local config = require("linear.config")
local api = require("linear.api")
local commands = require("linear.commands")

---@class LinearModule
local M = {}

local initialized = false

---Setup function - called from plugin/linear.lua
---@param opts? linear.Config User configuration options
function M.setup(opts)
	if initialized then
		return
	end

	-- Configure the plugin
	config.setup(opts or {})

	-- Get API key and initialize API client
	local api_key = config.get_api_key()
	if api_key then
		api.setup(api_key)
		commands.setup_commands()
		initialized = true
		vim.notify("Linear.nvim initialized successfully", vim.log.levels.INFO)
	else
		vim.notify("Linear.nvim: Could not initialize - no API key found", vim.log.levels.WARN)
	end
end

return M
