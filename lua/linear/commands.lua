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

	-- Telescope-based commands
	local pickers = require("linear.ui.telescope.pickers")

	vim.api.nvim_create_user_command("LinearIssues", function(_opts)
		pickers.issues()
	end, {
		desc = "Browse your assigned Linear issues",
	})

	vim.api.nvim_create_user_command("LinearSearch", function(opts)
		local query = opts.args and opts.args ~= "" and opts.args or nil
		pickers.search_issues(query)
	end, {
		desc = "Search Linear issues",
		nargs = "?",
	})

	vim.api.nvim_create_user_command("LinearBoards", function(_opts)
		pickers.board_picker()
	end, {
		desc = "Browse Linear boards/projects",
	})

	vim.api.nvim_create_user_command("LinearTeams", function(_opts)
		pickers.team_picker()
	end, {
		desc = "Browse Linear teams",
	})

	vim.api.nvim_create_user_command("LinearCycle", function(_opts)
		pickers.cycle_picker()
	end, {
		desc = "Browse current sprint/cycle issues for your team",
	})
end

return M
