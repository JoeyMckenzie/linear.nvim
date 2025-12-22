---@class LinearTelescopeActions
---Custom Telescope actions and event handlers
local M = {}

local api = require("linear.api")
local state = require("linear.ui.telescope.state")
local actions = require("telescope.actions")
local action_state = require("telescope.actions.state")

---Helper to get selected entry safely
---@param prompt_bufnr number Telescope prompt buffer number
---@return table? Selected entry or nil
local function get_selection(prompt_bufnr)
	local selection = action_state.get_selected_entry()
	if not selection or not selection._data then
		vim.notify("Linear.nvim: No issue selected", vim.log.levels.WARN)
		return nil
	end
	return selection
end

---Open selected issue in browser
---@param prompt_bufnr number Telescope prompt buffer number
---@return void
function M.open_in_browser(prompt_bufnr)
	local selection = get_selection(prompt_bufnr)
	if not selection or not selection.path then
		return
	end

	local url = selection.path
	-- Try vim.ui.open first (Neovim >= 0.10)
	if vim.ui.open then
		vim.ui.open(url)
	else
		-- Fallback to shell commands
		local cmd = "open"
		if vim.fn.has("linux") == 1 then
			cmd = "xdg-open"
		elseif vim.fn.has("win32") == 1 then
			cmd = "start"
		end
		vim.fn.jobstart({ cmd, url })
	end

	actions.close(prompt_bufnr)
end

---Copy issue identifier to clipboard
---@param prompt_bufnr number Telescope prompt buffer number
---@return void
function M.copy_identifier(prompt_bufnr)
	local selection = get_selection(prompt_bufnr)
	if not selection or not selection._data then
		return
	end

	local identifier = selection._data.identifier
	vim.fn.setreg("+", identifier)
	vim.notify("Linear.nvim: Copied " .. identifier .. " to clipboard", vim.log.levels.INFO)
end

---Copy issue URL to clipboard
---@param prompt_bufnr number Telescope prompt buffer number
---@return void
function M.copy_url(prompt_bufnr)
	local selection = get_selection(prompt_bufnr)
	if not selection or not selection.path then
		return
	end

	vim.fn.setreg("+", selection.path)
	vim.notify("Linear.nvim: Copied URL to clipboard", vim.log.levels.INFO)
end

---Show detailed view of selected issue
---@param prompt_bufnr number Telescope prompt buffer number
---@return void
function M.show_details(prompt_bufnr)
	local selection = get_selection(prompt_bufnr)
	if not selection or not selection._data then
		return
	end

	-- Use windows module for detail view
	local windows = require("linear.ui.windows")
	windows.show_issue_detail(selection._data)
	-- Keep picker open
end

---Toggle/change status of selected issue
---@param prompt_bufnr number Telescope prompt buffer number
---@return void
function M.toggle_status(prompt_bufnr)
	local selection = get_selection(prompt_bufnr)
	if not selection or not selection._data then
		return
	end

	local issue = selection._data

	-- Fetch available states
	api.get_states(function(states_data, err)
		if err then
			vim.notify("Linear.nvim: Error fetching states: " .. err, vim.log.levels.ERROR)
			return
		end

		if not states_data or not states_data.workflowStates or not states_data.workflowStates.nodes then
			vim.notify("Linear.nvim: No states available", vim.log.levels.WARN)
			return
		end

		local states = states_data.workflowStates.nodes
		local choices = {}
		for _, state_obj in ipairs(states) do
			table.insert(choices, state_obj.name)
		end

		vim.ui.select(choices, { prompt = "Select new status for " .. issue.identifier .. ":" }, function(choice)
			if not choice then
				return
			end

			-- Find the state ID
			local selected_state = nil
			for _, state_obj in ipairs(states) do
				if state_obj.name == choice then
					selected_state = state_obj
					break
				end
			end

			if selected_state then
				api.update_issue(issue.id, { stateId = selected_state.id }, function(_update_data, update_err)
					if update_err then
						vim.notify("Linear.nvim: Error updating status: " .. update_err, vim.log.levels.ERROR)
					else
						vim.notify("Linear.nvim: Updated " .. issue.identifier .. " status to " .. choice, vim.log.levels.INFO)
						-- Refresh picker to show updated status
						M.refresh()
					end
				end)
			end
		end)
	end)
end

---Navigate to board containing selected issue
---@param prompt_bufnr number Telescope prompt buffer number
---@return void
function M.navigate_board(prompt_bufnr)
	local selection = get_selection(prompt_bufnr)
	if not selection or not selection._data or not selection._data.project then
		vim.notify("Linear.nvim: Issue has no associated project", vim.log.levels.WARN)
		return
	end

	local project = selection._data.project

	-- Store context and navigate to board
	state.switch_view("board", { project_id = project.id })

	-- Close current picker and open new one for the board
	actions.close(prompt_bufnr)

	-- Launch picker for board issues
	local pickers = require("linear.ui.telescope.pickers")
	pickers.issues({
		filter = { project = { id = { eq = project.id } } },
		prompt_title = "Issues in " .. project.name,
	})
end

---Navigate back to previous view
---@return void
function M.navigate_back()
	local previous_view = state.history["issues"]
	if not previous_view then
		vim.notify("Linear.nvim: No previous view to navigate to", vim.log.levels.WARN)
		return
	end

	-- Clear current view and restore previous
	state.switch_view("issues", previous_view)

	-- Reopen picker with previous context
	local pickers = require("linear.ui.telescope.pickers")
	pickers.issues(previous_view)
end

---Refresh current picker
---@return void
function M.refresh()
	-- Clear cache to force fresh data
	state.clear_cache()

	-- Notify user
	vim.notify("Linear.nvim: Refreshing data...", vim.log.levels.INFO)

	-- Close any open pickers and reopen
	-- This is a simple approach - in a more advanced implementation,
	-- we would refresh the current picker directly
	require("telescope.builtin").command_history()
end

return M
