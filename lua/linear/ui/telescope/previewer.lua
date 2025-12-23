---@class LinearTelescopePreviewer
---Custom Telescope previewer for issue details
local M = {}

local previewers = require("telescope.previewers")
local utils = require("linear.utils")

---Cache for full issue details (including comments)
---@type table<string, table>
local issue_cache = {}

---Helper function to format date string
---@param iso_date string ISO 8601 date string
---@return string Formatted date
local function format_date(iso_date)
	if not iso_date then
		return "Unknown"
	end
	-- Try to use utils.format_date if available
	local ok, result = pcall(utils.format_date, iso_date)
	if ok then
		return result
	end
	-- Fallback: extract just the date part
	return iso_date:match("^([^T]+)")
end

---Format a relative date string
---@param iso_date string ISO 8601 date string
---@return string Relative or formatted date
local function format_relative_date(iso_date)
	if not iso_date then
		return "Unknown"
	end
	-- Use utils.format_date for consistent formatting
	local ok, result = pcall(utils.format_date, iso_date)
	if ok then
		return result
	end
	return iso_date:match("^([^T]+)") or "Unknown"
end

---Build comments section lines
---@param comments table[] Array of comment objects
---@param limit number Maximum comments to show
---@return string[] Lines for the comments section
local function build_comments_section(comments, limit)
	local lines = {}

	if not comments or #comments == 0 then
		return lines
	end

	-- Add separator and header
	table.insert(lines, "")
	table.insert(lines, "---")
	table.insert(lines, "")
	table.insert(lines, "## Comments (" .. #comments .. ")")
	table.insert(lines, "")

	-- Show most recent comments first, limited by config
	local count = 0
	for i = #comments, 1, -1 do
		if count >= limit then
			break
		end

		local comment = comments[i]
		local author = comment.user and comment.user.name or "Unknown"
		local date = format_relative_date(comment.createdAt)

		table.insert(lines, "**" .. author .. "** · " .. date)

		-- Add comment body, handling multiline
		if comment.body and comment.body ~= "" then
			for line in comment.body:gmatch("[^\n]+") do
				table.insert(lines, line)
			end
		end

		table.insert(lines, "")
		count = count + 1
	end

	return lines
end

---Helper function to get priority label
---@param priority number Priority level
---@return string Priority label
local function priority_label(priority)
	if not priority then
		return "No Priority"
	end
	if priority <= 0 then
		return "None"
	elseif priority <= 50 then
		return "Low"
	elseif priority <= 100 then
		return "Medium"
	else
		return "High"
	end
end

---Build base issue lines (without comments)
---@param issue table Issue data
---@return string[] Lines for the issue preview
local function build_issue_lines(issue)
	local lines = {}

	-- Safely build lines with defensive checks
	if issue.identifier and issue.title then
		table.insert(lines, "# " .. issue.identifier .. ": " .. issue.title)
		table.insert(lines, "")
	end

	-- Status
	if issue.state then
		table.insert(lines, "**Status:** " .. (issue.state.name or "Unknown"))
	else
		table.insert(lines, "**Status:** Unknown")
	end

	-- Priority
	table.insert(lines, "**Priority:** " .. priority_label(issue.priority))

	-- Assignee
	if issue.assignee then
		table.insert(lines, "**Assignee:** " .. (issue.assignee.name or "Unassigned"))
	else
		table.insert(lines, "**Assignee:** Unassigned")
	end

	-- Project
	if issue.project and issue.project.name then
		table.insert(lines, "**Project:** " .. issue.project.name)
	end

	-- Team
	if issue.team and issue.team.name then
		table.insert(lines, "**Team:** " .. issue.team.name)
	end

	-- Dates
	table.insert(lines, "**Created:** " .. format_date(issue.createdAt))
	table.insert(lines, "**Updated:** " .. format_date(issue.updatedAt))

	-- URL
	if issue.url then
		table.insert(lines, "**URL:** " .. issue.url)
	end

	-- Description section
	if issue.description and issue.description ~= "" then
		table.insert(lines, "")
		table.insert(lines, "## Description")
		table.insert(lines, "")
		-- Split description by newlines safely
		for line in issue.description:gmatch("[^\n]+") do
			table.insert(lines, line)
		end
	end

	return lines
end

---Create custom previewer for Linear issues (summary view)
---@param _opts table? Previewer options
---@return table Telescope previewer
function M.make_previewer(_opts)
	return previewers.new_buffer_previewer({
		title = "Issue Preview",
		define_preview = function(self, entry, _status)
			if not entry or not entry._data then
				pcall(vim.api.nvim_buf_set_lines, self.state.bufnr, 0, -1, false, { "No issue data" })
				return
			end

			local issue = entry._data
			local bufnr = self.state.bufnr

			-- Get config for comment limit
			local config = require("linear.config")
			local cfg = config.get()
			local comment_limit = cfg.ui and cfg.ui.telescope and cfg.ui.telescope.preview_comment_limit or 5

			-- Build base issue lines immediately
			local lines = build_issue_lines(issue)

			-- Check if we have cached full details with comments
			if issue_cache[issue.id] then
				local cached = issue_cache[issue.id]
				if cached.comments and cached.comments.nodes and comment_limit > 0 then
					local comment_lines = build_comments_section(cached.comments.nodes, comment_limit)
					vim.list_extend(lines, comment_lines)
				end
			end

			-- Set buffer content
			pcall(vim.api.nvim_buf_set_lines, bufnr, 0, -1, false, lines)
			pcall(vim.api.nvim_buf_set_option, bufnr, "filetype", "markdown")
			pcall(vim.api.nvim_buf_set_option, bufnr, "modifiable", false)

			-- If not cached and comments enabled, fetch full details async
			if not issue_cache[issue.id] and comment_limit > 0 then
				local api = require("linear.api")
				api.get_issue_full(issue.id, function(data, err)
					if err or not data or not data.issue then
						return
					end

					-- Cache the full issue data
					issue_cache[issue.id] = data.issue

					-- Update preview if buffer still valid and has comments
					if data.issue.comments and data.issue.comments.nodes and #data.issue.comments.nodes > 0 then
						vim.schedule(function()
							-- Check buffer is still valid
							if not vim.api.nvim_buf_is_valid(bufnr) then
								return
							end

							-- Rebuild lines with comments
							local updated_lines = build_issue_lines(issue)
							local comment_lines = build_comments_section(data.issue.comments.nodes, comment_limit)
							vim.list_extend(updated_lines, comment_lines)

							-- Update buffer
							pcall(vim.api.nvim_buf_set_option, bufnr, "modifiable", true)
							pcall(vim.api.nvim_buf_set_lines, bufnr, 0, -1, false, updated_lines)
							pcall(vim.api.nvim_buf_set_option, bufnr, "modifiable", false)
						end)
					end
				end)
			end
		end,
	})
end

---Clear the issue cache
function M.clear_cache()
	issue_cache = {}
end

return M
