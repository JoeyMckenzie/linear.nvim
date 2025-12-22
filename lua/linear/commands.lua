---@class LinearCommands
local M = {}

---Setup user commands
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

	vim.api.nvim_create_user_command("LinearCycle", function(opts)
		local args = opts.fargs or {}
		local team_name = nil
		local show_all = false

		-- Parse arguments: ["team_name"] [all]
		-- Use quotes for multi-word team names: :LinearCycle "Technical Debt" all
		for _, arg in ipairs(args) do
			if arg:lower() == "all" then
				show_all = true
			else
				team_name = arg
			end
		end

		pickers.cycle_picker({ show_all = show_all, team_name = team_name })
	end, {
		desc = "Browse current sprint/cycle issues ([\"team\"] [all])",
		nargs = "*",
	})
end

return M
