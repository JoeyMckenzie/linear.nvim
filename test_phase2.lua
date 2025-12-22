---Test Phase 2: Telescope Integration - API Functions
---Run these commands from Neovim to test the new API endpoints

local api = require("linear.api")

-- Initialize API
api.setup()

---Format issues for display
---@param issues table Array of issue data
---@return string Formatted output
local function format_issues_output(issues)
	if not issues or #issues == 0 then
		return "No issues found"
	end

	local lines = {}
	table.insert(lines, "Issues:")
	for i, issue in ipairs(issues) do
		local state_name = issue.state and issue.state.name or "Unknown"
		local assignee_name = issue.assignee and issue.assignee.name or "Unassigned"
		local line = string.format("%d. %s - %s [%s] (%s)", i, issue.identifier, issue.title, state_name, assignee_name)
		table.insert(lines, line)
	end
	return table.concat(lines, "\n")
end

-- Test 1: Get filtered issues (assigned to me)
vim.api.nvim_create_user_command("LinearTestGetAssignedIssues", function()
	vim.notify("Fetching assigned issues...", vim.log.levels.INFO)

	api.get_issues_filtered({ assignee = { isMe = { eq = true } } }, "UPDATED_AT", 10, function(data, err)
		if err then
			vim.notify("Error fetching issues: " .. err, vim.log.levels.ERROR)
			return
		end

		if not data or not data.issues then
			vim.notify("No data returned", vim.log.levels.WARN)
			return
		end

		local issues = data.issues.nodes
		local output = format_issues_output(issues)
		vim.notify(output, vim.log.levels.INFO)
	end)
end, { desc = "Test get_issues_filtered for assigned issues" })

-- Test 2: Get all projects/boards
vim.api.nvim_create_user_command("LinearTestGetProjects", function()
	vim.notify("Fetching projects...", vim.log.levels.INFO)

	api.get_projects(function(data, err)
		if err then
			vim.notify("Error fetching projects: " .. err, vim.log.levels.ERROR)
			return
		end

		if not data or not data.projects or not data.projects.nodes then
			vim.notify("No projects found", vim.log.levels.WARN)
			return
		end

		local projects = data.projects.nodes
		local lines = { "Projects/Boards:" }
		for i, project in ipairs(projects) do
			local desc = project.description or "No description"
		local line = string.format("%d. %s - %s", i, project.name, desc)
		table.insert(lines, line)
		end

		vim.notify(table.concat(lines, "\n"), vim.log.levels.INFO)
	end)
end, { desc = "Test get_projects" })

-- Test 3: Search issues
vim.api.nvim_create_user_command("LinearTestSearchIssues", function(opts)
	local query = opts.args and opts.args ~= "" and opts.args or "status:backlog"

	vim.notify("Searching for: " .. query, vim.log.levels.INFO)

	api.search_issues(query, 10, function(data, err)
		if err then
			vim.notify("Error searching issues: " .. err, vim.log.levels.ERROR)
			return
		end

		if not data or not data.issueSearch or not data.issueSearch.nodes then
			vim.notify("No results found", vim.log.levels.WARN)
			return
		end

		local results = data.issueSearch.nodes
		local output = format_issues_output(results)
		local msg = "Search Results:\n" .. output
		vim.notify(msg, vim.log.levels.INFO)
	end)
end, { desc = "Test search_issues (usage: :LinearTestSearchIssues [query])", nargs = "?" })

---Format full issue details for display
---@param issue table Issue data
---@return string Formatted output
local function format_full_issue(issue)
	local lines = {
		"Issue Details:",
		"===============",
		"ID: " .. issue.identifier,
		"Title: " .. issue.title,
		"State: " .. (issue.state and issue.state.name or "Unknown"),
		"Priority: " .. (issue.priority or "None"),
		"Assignee: " .. (issue.assignee and issue.assignee.name or "Unassigned"),
		"Project: " .. (issue.project and issue.project.name or "None"),
		"Created: " .. (issue.createdAt or "Unknown"),
		"Updated: " .. (issue.updatedAt or "Unknown"),
		"URL: " .. (issue.url or "No URL"),
	}

	if issue.description then
		table.insert(lines, "")
		table.insert(lines, "Description:")
		table.insert(lines, issue.description)
	end

	if issue.comments and issue.comments.nodes and #issue.comments.nodes > 0 then
		table.insert(lines, "")
		table.insert(lines, "Recent Comments:")
		for i, comment in ipairs(issue.comments.nodes) do
			local user_name = comment.user and comment.user.name or "Unknown"
			table.insert(lines, string.format("%d. %s (%s):", i, user_name, comment.createdAt))
			table.insert(lines, "   " .. comment.body)
		end
	end

	return table.concat(lines, "\n")
end

-- Test 4: Get full issue details with comments
vim.api.nvim_create_user_command("LinearTestGetIssueFull", function(opts)
	if not opts.args or opts.args == "" then
		vim.notify("Usage: :LinearTestGetIssueFull <issue_id>", vim.log.levels.WARN)
		return
	end

	local issue_id = opts.args

	vim.notify("Fetching full details for issue: " .. issue_id, vim.log.levels.INFO)

	api.get_issue_full(issue_id, function(data, err)
		if err then
			vim.notify("Error fetching issue: " .. err, vim.log.levels.ERROR)
			return
		end

		if not data or not data.issue then
			vim.notify("Issue not found", vim.log.levels.WARN)
			return
		end

		local issue = data.issue
		local output = format_full_issue(issue)
		vim.notify(output, vim.log.levels.INFO)
	end)
end, { desc = "Test get_issue_full (usage: :LinearTestGetIssueFull <issue_id>)", nargs = "+" })

-- Test 5: Update issue status
vim.api.nvim_create_user_command("LinearTestUpdateIssueStatus", function(opts)
	if not opts.args or opts.args == "" then
		vim.notify("Usage: :LinearTestUpdateIssueStatus <issue_id>", vim.log.levels.WARN)
		return
	end

	local issue_id = opts.args

	vim.notify("Fetching available states...", vim.log.levels.INFO)

	api.get_states(function(states_data, err)
		if err then
			vim.notify("Error fetching states: " .. err, vim.log.levels.ERROR)
			return
		end

		local states = states_data.workflowStates.nodes
		local choices = {}
		for _, state in ipairs(states) do
			table.insert(choices, state.name)
		end

		vim.ui.select(choices, { prompt = "Select new status for " .. issue_id .. ":" }, function(choice)
			if not choice then
				return
			end

			-- Find the state ID
			local selected_state = nil
			for _, state in ipairs(states) do
				if state.name == choice then
					selected_state = state
					break
				end
			end

			if selected_state then
				vim.notify("Updating " .. issue_id .. " status to " .. choice .. "...", vim.log.levels.INFO)

				api.update_issue(issue_id, { stateId = selected_state.id }, function(_update_data, update_err)
					if update_err then
						vim.notify("Error updating status: " .. update_err, vim.log.levels.ERROR)
					else
						vim.notify("Successfully updated " .. issue_id .. " status to " .. choice, vim.log.levels.INFO)
					end
				end)
			end
		end)
	end)
end, { desc = "Test update_issue with status change (usage: :LinearTestUpdateIssueStatus <issue_id>)", nargs = "+" })

-- Test 6: Test state management
vim.api.nvim_create_user_command("LinearTestState", function()
	local state = require("linear.ui.telescope.state")

	vim.notify("Testing state management...", vim.log.levels.INFO)

	-- Test applying filters
	state.apply_filters({ status = "backlog" })
	vim.notify("Applied filters - Current filters: " .. vim.inspect(state.current_filters), vim.log.levels.INFO)

	-- Test switching views
	state.switch_view("issues", { board = "ABC" })
	vim.notify("Switched to view: " .. state.current_view, vim.log.levels.INFO)

	-- Test cache
	state.update_cache_time()
	vim.notify("Cache valid: " .. tostring(state.cache_valid()), vim.log.levels.INFO)
end, { desc = "Test state management module" })

print("Phase 2 Test Commands Loaded!")
print("")
print("Available test commands:")
print("  :LinearTestGetAssignedIssues     - Fetch your assigned issues")
print("  :LinearTestGetProjects           - Fetch all projects/boards")
print("  :LinearTestSearchIssues [query]  - Search issues (default: 'status:backlog')")
print("  :LinearTestGetIssueFull <id>     - Get full details for an issue")
print("  :LinearTestUpdateIssueStatus <id> - Update issue status (interactive)")
print("  :LinearTestState                 - Test state management")
print("")
