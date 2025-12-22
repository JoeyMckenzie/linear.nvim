---@class linear.Issue
---@field id string
---@field identifier string
---@field title string
---@field description string
---@field state {name: string, color: string}
---@field priority integer
---@field assignee {name: string}?
---@field createdAt string
---@field updatedAt string

---@class linear.IssueFields
---@field identifier string
---@field title string
---@field state string
---@field priority string
---@field assignee string
---@field created string
---@field updated string
---@field description string

---@class LinearUtils
local M = {}

---Format issue for display in a list
---@param issue linear.Issue?
---@return string
function M.format_issue(issue)
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

---Get state name safely
---@param state {name: string, color: string}?
---@return string
local function get_state_name(state)
	return state and state.name or "Unknown"
end

---Get assignee name safely
---@param assignee {name: string}?
---@return string
local function get_assignee_name(assignee)
	return assignee and assignee.name or "Unassigned"
end

---Extract issue fields with defaults
---@param issue linear.Issue
---@return linear.IssueFields
local function extract_issue_fields(issue)
	return {
		identifier = issue.identifier or "N/A",
		title = issue.title or "",
		state = get_state_name(issue.state),
		priority = tostring(issue.priority or 0),
		assignee = get_assignee_name(issue.assignee),
		created = issue.createdAt or "",
		updated = issue.updatedAt or "",
		description = issue.description or "(No description)",
	}
end

---Format issue for detailed view
---@param issue linear.Issue?
---@return string
function M.format_issue_detail(issue)
	if not issue then
		return ""
	end

	local fields = extract_issue_fields(issue)

	local lines = {
		"",
		"Issue: " .. fields.identifier,
		"Title: " .. fields.title,
		"State: " .. fields.state,
		"Priority: " .. fields.priority,
		"Assignee: " .. fields.assignee,
		"Created: " .. fields.created,
		"Updated: " .. fields.updated,
		"",
		"Description:",
		"---",
		fields.description,
		"---",
		"",
	}

	return table.concat(lines, "\n")
end

---Convert priority number to label
---@param priority integer The priority number
---@return string
function M.priority_label(priority)
	local labels = {
		[0] = "None",
		[1] = "Urgent",
		[2] = "High",
		[3] = "Medium",
		[4] = "Low",
	}
	return labels[priority] or "Unknown"
end

---Parse ISO date to readable format
---@param iso_date string?
---@return string
function M.format_date(iso_date)
	if not iso_date then
		return "N/A"
	end
	-- Simple format: just take the date part
	return iso_date:sub(1, 10)
end

---Notify user with message
---@param msg string The message to display
---@param level? integer The notification level (vim.log.levels)
function M.notify(msg, level)
	level = level or vim.log.levels.INFO
	vim.notify("Linear.nvim: " .. msg, level)
end

---Check if string is empty or nil
---@param s string?
---@return boolean
function M.is_empty(s)
	return s == nil or s == ""
end

---Get status icon for display
---@param state_name string? The state name
---@return string
function M.status_icon(state_name)
	if not state_name then
		return "⚪"
	end

	local name_lower = state_name:lower()

	if name_lower:match("done") or name_lower:match("complete") then
		return "🟢"
	elseif name_lower:match("progress") or name_lower:match("started") then
		return "🟡"
	elseif name_lower:match("review") then
		return "🔵"
	elseif name_lower:match("cancel") then
		return "⚫"
	else
		return "⚪"
	end
end

---Get priority icon for display
---@param priority integer? The priority level (1=urgent, 2=high, 3=medium, 4=low, 0=none)
---@return string
function M.priority_icon(priority)
	if not priority or priority == 0 then
		return ""
	end

	local icons = {
		[1] = "🔴", -- Urgent
		[2] = "⬆️", -- High
		[3] = "➡️", -- Medium
		[4] = "⬇️", -- Low
	}

	return icons[priority] or ""
end

---Extract PR status from subtitle text
---@param subtitle string The attachment subtitle
---@return string PR status indicator
local function extract_pr_status(subtitle)
	local status_map = {
		{ pattern = "merged", label = "merged" },
		{ pattern = "closed", label = "closed" },
		{ pattern = "draft", label = "draft" },
		{ pattern = "open", label = "open" },
	}

	local lower = subtitle:lower()
	for _, entry in ipairs(status_map) do
		if lower:match(entry.pattern) then
			return " [PR:" .. entry.label .. "]"
		end
	end

	return subtitle ~= "" and " [PR:open]" or " [PR]"
end

---Get PR status indicator from issue attachments
---@param attachments table? The attachments object { nodes: table[] }
---@return string PR status indicator or empty string
function M.pr_status(attachments)
	if not attachments or not attachments.nodes then
		return ""
	end

	for _, attachment in ipairs(attachments.nodes) do
		local source = (attachment.sourceType or ""):lower()
		local is_pr = source:match("github") or source:match("pull")
		if is_pr then
			return extract_pr_status(attachment.subtitle or "")
		end
	end

	return ""
end

return M
