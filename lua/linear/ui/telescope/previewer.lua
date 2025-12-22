---@class LinearTelescopePreviewer
---Custom Telescope previewer for issue details
local M = {}

local previewers = require("telescope.previewers")
local utils = require("linear.utils")

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

			-- Set buffer content safely with pcall
			pcall(vim.api.nvim_buf_set_lines, self.state.bufnr, 0, -1, false, lines)

			-- Set buffer options safely
			pcall(vim.api.nvim_buf_set_option, self.state.bufnr, "filetype", "markdown")
			pcall(vim.api.nvim_buf_set_option, self.state.bufnr, "modifiable", false)
		end,
	})
end

return M
