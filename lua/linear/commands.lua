---@type any
local api = require("linear.api")
---@type any
local utils = require("linear.utils")

---@class LinearCommands
local M = {}

---Test authentication by querying viewer
---@return void
function M.test_auth()
	utils.notify("Testing authentication with Linear API...", vim.log.levels.INFO)

	api.get_viewer(function(data, err)
		if err then
			utils.notify("Authentication failed: " .. err, vim.log.levels.ERROR)
			return
		end

		if data and data.viewer then
			local viewer = data.viewer
			utils.notify(
				"✓ Authentication successful! Logged in as: " .. (viewer.name or viewer.email),
				vim.log.levels.INFO
			)
		else
			utils.notify("Authentication successful but got unexpected response", vim.log.levels.WARN)
		end
	end)
end

---Setup user commands
---@return void
function M.setup_commands()
	vim.api.nvim_create_user_command("LinearTestAuth", function()
		M.test_auth()
	end, {
		desc = "Test Linear API authentication",
	})
end

return M
