---@class LinearUIWindows
---Window and buffer management for detail views
local M = {}

local config = require("linear.config")

---Helper to create centered floating window
---@param lines string[] Lines to display
---@param title string? Window title
---@return number Window ID
local function create_float_window(lines, title)
	local cfg = config.get()

	-- Calculate window dimensions
	local ui = vim.api.nvim_list_uis()[1]
	local width = math.floor(ui.width * (cfg.ui.details.width or 0.8))
	local height = math.floor(ui.height * (cfg.ui.details.height or 0.8))
	local row = math.floor((ui.height - height) / 2)
	local col = math.floor((ui.width - width) / 2)

	-- Create buffer
	local bufnr = vim.api.nvim_create_buf(false, true)
	vim.api.nvim_buf_set_lines(bufnr, 0, -1, false, lines)
	vim.api.nvim_buf_set_option(bufnr, "filetype", "markdown")
	vim.api.nvim_buf_set_option(bufnr, "modifiable", false)

	-- Create window
	local winnr = vim.api.nvim_open_win(bufnr, true, {
		relative = "editor",
		width = width,
		height = height,
		row = row,
		col = col,
		border = "rounded",
		title = title or "Linear Detail",
		title_pos = "center",
	})

	-- Set keybindings
	local opts = { noremap = true, silent = true, buffer = bufnr }
	vim.keymap.set("n", "q", function()
		vim.api.nvim_win_close(winnr, true)
	end, opts)

	vim.keymap.set("n", "<ESC>", function()
		vim.api.nvim_win_close(winnr, true)
	end, opts)

	return winnr
end

---Show detailed view of an issue
---@param issue_data table Issue data with full details
function M.show_issue_detail(issue_data)
	if not issue_data then
		vim.notify("Linear.nvim: No issue data provided", vim.log.levels.WARN)
		return
	end

	local lines = {}

	-- Title
	table.insert(lines, "# " .. issue_data.identifier .. ": " .. issue_data.title)
	table.insert(lines, "")

	-- Metadata section
	local state_name = issue_data.state and issue_data.state.name or "Unknown"
	table.insert(lines, "**Status:** " .. state_name)

	if issue_data.priority then
		table.insert(lines, "**Priority:** " .. tostring(issue_data.priority))
	end

	local assignee = issue_data.assignee and issue_data.assignee.name or "Unassigned"
	table.insert(lines, "**Assignee:** " .. assignee)

	if issue_data.project and issue_data.project.name then
		table.insert(lines, "**Project:** " .. issue_data.project.name)
	end

	if issue_data.team and issue_data.team.name then
		table.insert(lines, "**Team:** " .. issue_data.team.name)
	end

	table.insert(lines, "**Created:** " .. (issue_data.createdAt or "Unknown"))
	table.insert(lines, "**Updated:** " .. (issue_data.updatedAt or "Unknown"))

	if issue_data.url then
		table.insert(lines, "**URL:** " .. issue_data.url)
	end

	-- Description
	if issue_data.description and issue_data.description ~= "" then
		table.insert(lines, "")
		table.insert(lines, "## Description")
		table.insert(lines, "")
		for line in issue_data.description:gmatch("[^\n]+") do
			table.insert(lines, line)
		end
	end

	-- Comments if available
	if issue_data.comments and issue_data.comments.nodes and #issue_data.comments.nodes > 0 then
		table.insert(lines, "")
		table.insert(lines, "## Comments")
		table.insert(lines, "")
		for _, comment in ipairs(issue_data.comments.nodes) do
			local user_name = comment.user and comment.user.name or "Unknown"
			table.insert(lines, "**" .. user_name .. "** (" .. (comment.createdAt or "Unknown") .. "):")
			table.insert(lines, "")
			for line in comment.body:gmatch("[^\n]+") do
				table.insert(lines, "> " .. line)
			end
			table.insert(lines, "")
		end
	end

	-- Show instructions at bottom
	table.insert(lines, "")
	table.insert(lines, "---")
	table.insert(lines, "Press `q` or `<ESC>` to close")

	create_float_window(lines, issue_data.identifier)
end

---Show status change modal
---@param _issue_id string Issue ID
---@param _current_status string Current status name
---@param _states table Available states
---@param _callback function Callback when status is selected
function M.show_status_modal(_issue_id, _current_status, _states, _callback)
	-- Uses vim.ui.select instead - implementation not needed
end

---Show comment editor
---@param _issue_id string Issue ID
---@param _callback function Callback with comment text
function M.show_comment_editor(_issue_id, _callback)
	-- Future implementation for adding comments
end

---Close all linear UI windows
function M.close_all()
	-- Close all floating windows related to linear
	for _, winnr in ipairs(vim.api.nvim_list_wins()) do
		local cfg = vim.api.nvim_win_get_config(winnr)
		-- Check if this is a floating window (has relative position)
		if cfg.relative ~= "" then
			vim.api.nvim_win_close(winnr, false)
		end
	end
end

return M
