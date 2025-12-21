local api = require("linear.api")
local utils = require("linear.utils")

local M = {}

-- Test authentication by querying viewer
M.test_auth = function()
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

-- Create a command to test auth
M.setup_commands = function()
	vim.api.nvim_create_user_command("LinearTestAuth", function()
		M.test_auth()
	end, {
		desc = "Test Linear API authentication",
	})
end

return M
