---@class LinearTelescopePickers
---Telescope picker configuration and entry points
local M = {}

local pickers = require("telescope.pickers")
local finders_module = require("linear.ui.telescope.finders")
local actions_module = require("linear.ui.telescope.actions")
local previewer = require("linear.ui.telescope.previewer")
local state = require("linear.ui.telescope.state")
local config = require("linear.config")
local telescope_actions = require("telescope.actions")

---Helper to create base picker configuration
---@param finder_obj table Telescope finder object
---@param opts table? Picker options
---@return table Picker configuration
local function create_picker_config(finder_obj, opts)
	opts = opts or {}
	local cfg = config.get()

	local picker_opts = {
		prompt_title = opts.prompt_title or "Linear Issues",
		finder = finder_obj,
		sorter = require("telescope.config").values.generic_sorter(opts),
		attach_mappings = function(prompt_bufnr, map)
			-- Default action: open in browser
			map("i", "<CR>", actions_module.open_in_browser)
			map("n", "<CR>", actions_module.open_in_browser)

			-- Copy identifier
			map("i", "<C-y>", actions_module.copy_identifier)
			map("n", "<C-y>", actions_module.copy_identifier)

			-- Copy URL
			map("i", "<M-y>", actions_module.copy_url)
			map("n", "<M-y>", actions_module.copy_url)

			-- Toggle status
			map("i", "<C-s>", actions_module.toggle_status)
			map("n", "<C-s>", actions_module.toggle_status)

			-- Show details
			map("i", "<C-d>", actions_module.show_details)
			map("n", "<C-d>", actions_module.show_details)

			-- Navigate to board
			map("i", "<C-b>", actions_module.navigate_board)
			map("n", "<C-b>", actions_module.navigate_board)

			-- Close picker with q
			map("i", "<C-c>", telescope_actions.close)
			map("n", "q", telescope_actions.close)

			return true
		end,
	}

	-- Add previewer if enabled
	if cfg.ui.telescope.previewer then
		picker_opts.previewer = previewer.make_previewer(opts)
	end

	-- Apply theme from config
	if cfg.ui.telescope.theme and cfg.ui.telescope.theme ~= "" then
		local theme_getter = require("telescope.themes")["get_" .. cfg.ui.telescope.theme]
		if theme_getter then
			picker_opts = theme_getter(picker_opts)
		end
	end

	return picker_opts
end

---Create issues picker (assigned issues by default)
---@param opts table? Picker options
---@return void
function M.issues(opts)
	opts = opts or {}

	-- Use provided finder or default to assigned issues
	local finder_obj
	if opts.filter then
		-- Custom filter provided
		if opts.filter.project and opts.filter.project.id then
			finder_obj = finders_module.issues_by_board(opts.filter.project.id.eq, opts)
		elseif opts.filter.team and opts.filter.team.id then
			finder_obj = finders_module.issues_by_team(opts.filter.team.id.eq, opts)
		else
			finder_obj = finders_module.issues_all(opts)
		end
	else
		-- Default: assigned issues
		finder_obj = finders_module.issues_assigned(opts)
	end

	local picker_opts = create_picker_config(finder_obj, opts)
	pickers.new(picker_opts):find()
end

---Create search picker
---@param query string? Initial search query
---@param opts table? Picker options
---@return void
function M.search_issues(query, opts)
	opts = opts or {}

	-- Prompt for query if not provided
	if not query or query == "" then
		vim.ui.input(
			{ prompt = "Search Linear issues: " },
			function(input)
				if input and input ~= "" then
					M.search_issues(input, opts)
				end
			end
		)
		return
	end

	local finder_obj = finders_module.issues_search(query, opts)
	opts.prompt_title = "Search: " .. query

	local picker_opts = create_picker_config(finder_obj, opts)
	pickers.new(picker_opts):find()
end

---Create board/project picker
---@param opts table? Picker options
---@return void
function M.board_picker(opts)
	opts = opts or {}
	opts.prompt_title = "Linear Boards/Projects"

	local finder_obj = finders_module.boards(opts)

	local picker_opts = create_picker_config(finder_obj, opts)

	-- Override mappings for board selection
	picker_opts.attach_mappings = function(prompt_bufnr, map)
		-- Select board: navigate to that board's issues
		map("i", "<CR>", function()
			local action_state = require("telescope.actions.state")
			local selection = action_state.get_selected_entry()
			if selection and selection._data then
				telescope_actions.close(prompt_bufnr)
				-- Navigate to board issues
				M.issues({
					filter = { project = { id = { eq = selection._data.id } } },
					prompt_title = "Issues in " .. selection._data.name,
				})
			end
		end)

		-- Close with q
		map("i", "<C-c>", telescope_actions.close)
		map("n", "q", telescope_actions.close)

		return true
	end

	pickers.new(picker_opts):find()
end

---Create team picker
---@param opts table? Picker options
---@return void
function M.team_picker(opts)
	opts = opts or {}
	opts.prompt_title = "Linear Teams"

	local finder_obj = finders_module.teams(opts)

	local picker_opts = create_picker_config(finder_obj, opts)

	-- Override mappings for team selection
	picker_opts.attach_mappings = function(prompt_bufnr, map)
		-- Select team: navigate to that team's issues
		map("i", "<CR>", function()
			local action_state = require("telescope.actions.state")
			local selection = action_state.get_selected_entry()
			if selection and selection._data then
				telescope_actions.close(prompt_bufnr)
				-- Navigate to team issues
				M.issues({
					filter = { team = { id = { eq = selection._data.id } } },
					prompt_title = "Issues in " .. selection._data.name,
				})
			end
		end)

		-- Close with q
		map("i", "<C-c>", telescope_actions.close)
		map("n", "q", telescope_actions.close)

		return true
	end

	pickers.new(picker_opts):find()
end

return M
