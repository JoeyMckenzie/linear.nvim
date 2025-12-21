local M = {}

-- Format issue display string
M.format_issue = function(issue)
	if not issue then
		return ""
	end

	local state = issue.state and issue.state.name or "Unknown"
	local priority = issue.priority or 0
	local assignee = issue.assignee and issue.assignee.name or "Unassigned"

	return string.format(
		"%s [%s] %s (Priority: %d, Assignee: %s)",
		issue.identifier or "N/A",
		state,
		issue.title or "",
		priority,
		assignee
	)
end

-- Format issue detail view
M.format_issue_detail = function(issue)
	if not issue then
		return ""
	end

	local lines = {
		"",
		"Issue: " .. (issue.identifier or "N/A"),
		"Title: " .. (issue.title or ""),
		"State: " .. (issue.state and issue.state.name or "Unknown"),
		"Priority: " .. tostring(issue.priority or 0),
		"Assignee: " .. (issue.assignee and issue.assignee.name or "Unassigned"),
		"Created: " .. (issue.createdAt or ""),
		"Updated: " .. (issue.updatedAt or ""),
		"",
		"Description:",
		"---",
		issue.description or "(No description)",
		"---",
		"",
	}

	return table.concat(lines, "\n")
end

-- Convert priority number to label
M.priority_label = function(priority)
	local labels = {
		[0] = "None",
		[1] = "Urgent",
		[2] = "High",
		[3] = "Medium",
		[4] = "Low",
	}
	return labels[priority] or "Unknown"
end

-- Parse ISO date to readable format
M.format_date = function(iso_date)
	if not iso_date then
		return "N/A"
	end
	-- Simple format: just take the date part
	return iso_date:sub(1, 10)
end

-- Notify user with message
M.notify = function(msg, level)
	level = level or vim.log.levels.INFO
	vim.notify("Linear.nvim: " .. msg, level)
end

-- Check if string is empty or nil
M.is_empty = function(s)
	return s == nil or s == ""
end

return M
