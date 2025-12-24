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

	vim.api.nvim_create_user_command("LinearCurrent", function(opts)
		local context = require("linear.context")
		local utils = require("linear.utils")
		local arg = opts.args and opts.args ~= "" and opts.args or nil

		if arg then
			-- Handle "clear" to reset context
			if arg:lower() == "clear" then
				context.clear()
				utils.notify("Linear context cleared", vim.log.levels.INFO)
				return
			end

			-- Set context to the provided identifier (validate it exists first)
			local api = require("linear.api")
			api.search_issues(arg, 5, function(data, err)
				if err then
					utils.notify("Failed to validate issue: " .. err, vim.log.levels.ERROR)
					return
				end

				if not data or not data.issueSearch or not data.issueSearch.nodes or #data.issueSearch.nodes == 0 then
					utils.notify("Issue " .. arg .. " not found", vim.log.levels.ERROR)
					return
				end

				-- Check for exact match
				local found = false
				for _, node in ipairs(data.issueSearch.nodes) do
					if node.identifier == arg:upper() then
						found = true
						break
					end
				end

				if not found then
					utils.notify("Issue " .. arg .. " not found", vim.log.levels.ERROR)
					return
				end

				context.set(arg:upper())
				utils.notify("Linear context set to " .. arg:upper(), vim.log.levels.INFO)
			end)
			return
		end

		-- No argument - resolve and show current issue
		local identifier = context.resolve()

		if not identifier then
			if not context.is_git_repo() then
				utils.notify("Not in a git repository", vim.log.levels.WARN)
			else
				utils.notify("No issue detected. Use :LinearCurrent PROJ-1234 to set one.", vim.log.levels.INFO)
			end
			return
		end

		pickers.current_issue(identifier)
	end, {
		desc = "View current working issue (auto-detected or manually set)",
		nargs = "?",
	})

	vim.api.nvim_create_user_command("LinearBranch", function(_opts)
		local branch = require("linear.branch")
		branch.create_branch_from_context()
	end, {
		desc = "Create git branch from current issue context",
	})
end

return M
