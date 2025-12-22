---@class LinearCommands
local M = {}

---Setup user commands
---@return void
function M.setup_commands()
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
