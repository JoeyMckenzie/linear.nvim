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

			-- Create git branch
			map("i", "<C-g>", actions_module.create_branch)
			map("n", "<C-g>", actions_module.create_branch)

			-- Switch to views picker
			local function switch_to_views()
				telescope_actions.close(prompt_bufnr)
				-- Use current project's ID if available, otherwise show all views
				local project_id = state.current_project and state.current_project.id or nil
				M.views(project_id)
			end
			map("i", "<C-v>", switch_to_views)
			map("n", "<C-v>", switch_to_views)

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

	-- Apply theme or custom layout from config
	if cfg.ui.telescope.theme and cfg.ui.telescope.theme ~= "" then
		-- Use a built-in theme (dropdown, ivy, cursor)
		local theme_getter = require("telescope.themes")["get_" .. cfg.ui.telescope.theme]
		if theme_getter then
			picker_opts = theme_getter(vim.tbl_extend("force", picker_opts, {
				layout_config = {
					width = cfg.ui.telescope.width or 0.8,
				},
			}))
		end
	else
		-- Use custom centered horizontal/vertical layout
		picker_opts.layout_strategy = cfg.ui.telescope.layout or "horizontal"
		picker_opts.layout_config = {
			width = cfg.ui.telescope.width or 0.8,
			height = cfg.ui.telescope.height or 0.8,
			prompt_position = "top",
			preview_width = 0.5,
		}
		picker_opts.sorting_strategy = "ascending"
	end

	return picker_opts
end

---Create issues picker (assigned issues by default)
---@param opts table? Picker options
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

---Create cycle picker (current sprint for selected team)
---@param opts table? Picker options { show_all: boolean, team_name: string? }
function M.cycle_picker(opts)
	opts = opts or {}
	local api = require("linear.api")
	local utils = require("linear.utils")
	local show_all = opts.show_all or false
	local team_name = opts.team_name

	-- First, fetch teams to let user select
	api.get_teams(function(teams_data, teams_err)
		if teams_err then
			utils.notify("Failed to fetch teams: " .. teams_err, vim.log.levels.ERROR)
			return
		end

		if not teams_data or not teams_data.teams or not teams_data.teams.nodes then
			utils.notify("No teams found", vim.log.levels.WARN)
			return
		end

		local teams = teams_data.teams.nodes

		-- If team name provided, find matching team (case-insensitive)
		if team_name then
			local team_name_lower = team_name:lower()
			for _, team in ipairs(teams) do
				if team.name:lower() == team_name_lower or team.name:lower():find(team_name_lower, 1, true) then
					M._open_cycle_for_team(team, show_all)
					return
				end
			end
			-- Team not found, show warning and fall back to picker
			utils.notify("Team '" .. team_name .. "' not found, showing picker", vim.log.levels.WARN)
		end

		-- If only one team, skip selection
		if #teams == 1 then
			M._open_cycle_for_team(teams[1], show_all)
			return
		end

		-- Show team picker
		local finder_obj = finders_module.teams(opts)
		local picker_opts = {
			prompt_title = "Select Team for Sprint View",
			finder = finder_obj,
			sorter = require("telescope.config").values.generic_sorter(opts),
			attach_mappings = function(prompt_bufnr, map)
				map("i", "<CR>", function()
					local action_state = require("telescope.actions.state")
					local selection = action_state.get_selected_entry()
					if selection and selection._data then
						telescope_actions.close(prompt_bufnr)
						M._open_cycle_for_team(selection._data, show_all)
					end
				end)
				map("n", "<CR>", function()
					local action_state = require("telescope.actions.state")
					local selection = action_state.get_selected_entry()
					if selection and selection._data then
						telescope_actions.close(prompt_bufnr)
						M._open_cycle_for_team(selection._data, show_all)
					end
				end)
				map("i", "<C-c>", telescope_actions.close)
				map("n", "q", telescope_actions.close)
				return true
			end,
		}

		pickers.new(picker_opts):find()
	end)
end

---Open cycle view for a specific team (internal)
---@param team table Team data
---@param show_all boolean Whether to show all team issues or just current user's
function M._open_cycle_for_team(team, show_all)
	local api = require("linear.api")
	local utils = require("linear.utils")

	-- Fetch viewer first if filtering by current user
	local function fetch_and_display(viewer_id)
		api.get_active_cycle(team.id, function(data, err)
			if err then
				utils.notify("Failed to fetch cycle: " .. err, vim.log.levels.ERROR)
				return
			end

			if not data or not data.team or not data.team.activeCycle then
				utils.notify("No active cycle for " .. team.name, vim.log.levels.WARN)
				return
			end

			local cycle = data.team.activeCycle
			local start_date = cycle.startsAt and cycle.startsAt:sub(1, 10) or "?"
			local end_date = cycle.endsAt and cycle.endsAt:sub(1, 10) or "?"

			-- Filter issues if not showing all
			local filtered_cycle = cycle
			if not show_all and viewer_id and cycle.issues and cycle.issues.nodes then
				local my_issues = {}
				for _, issue in ipairs(cycle.issues.nodes) do
					if issue.assignee and issue.assignee.id == viewer_id then
						table.insert(my_issues, issue)
					end
				end
				filtered_cycle = vim.tbl_extend("force", cycle, {
					issues = { nodes = my_issues },
				})
			end

			local finder_obj = finders_module.cycle_issues(team.id, filtered_cycle)
			local cfg = config.get()

			local view_indicator = show_all and " (Team)" or " (My Issues)"
			local picker_opts = {
				prompt_title = "Sprint: " .. cycle.name .. " (" .. start_date .. " - " .. end_date .. ")" .. view_indicator,
				finder = finder_obj,
				sorter = require("telescope.config").values.generic_sorter({}),
				attach_mappings = function(prompt_bufnr, map)
					map("i", "<CR>", actions_module.open_in_browser)
					map("n", "<CR>", actions_module.open_in_browser)
					map("i", "<C-y>", actions_module.copy_identifier)
					map("n", "<C-y>", actions_module.copy_identifier)
					map("i", "<C-g>", actions_module.create_branch)
					map("n", "<C-g>", actions_module.create_branch)
					map("i", "<C-c>", telescope_actions.close)
					map("n", "q", telescope_actions.close)
					return true
				end,
			}

			-- Add previewer if enabled
			if cfg.ui.telescope.previewer then
				picker_opts.previewer = previewer.make_previewer({})
			end

			-- Apply theme or custom layout from config
			if cfg.ui.telescope.theme and cfg.ui.telescope.theme ~= "" then
				local theme_getter = require("telescope.themes")["get_" .. cfg.ui.telescope.theme]
				if theme_getter then
					picker_opts = theme_getter(vim.tbl_extend("force", picker_opts, {
						layout_config = {
							width = cfg.ui.telescope.width or 0.8,
						},
					}))
				end
			else
				picker_opts.layout_strategy = cfg.ui.telescope.layout or "horizontal"
				picker_opts.layout_config = {
					width = cfg.ui.telescope.width or 0.8,
					height = cfg.ui.telescope.height or 0.8,
					prompt_position = "top",
					preview_width = 0.5,
				}
				picker_opts.sorting_strategy = "ascending"
			end

			pickers.new(picker_opts):find()
		end)
	end

	if show_all then
		-- Show all team issues
		fetch_and_display(nil)
	else
		-- Fetch viewer to filter by current user
		api.get_viewer(function(viewer_data, viewer_err)
			if viewer_err or not viewer_data or not viewer_data.viewer then
				utils.notify("Failed to fetch current user, showing all issues", vim.log.levels.WARN)
				fetch_and_display(nil)
				return
			end
			fetch_and_display(viewer_data.viewer.id)
		end)
	end
end

---Create project picker for navigating to project views
---@param opts table? Picker options
function M.projects(opts)
	opts = opts or {}
	opts.prompt_title = "Linear Projects"

	local finder_obj = finders_module.projects(opts)

	local picker_opts = create_picker_config(finder_obj, opts)

	-- Override mappings for project selection
	picker_opts.attach_mappings = function(prompt_bufnr, map)
		-- Select project: set state and navigate to views picker
		local function select_project()
			local action_state = require("telescope.actions.state")
			local selection = action_state.get_selected_entry()
			if selection and selection._data then
				-- Set current project in state
				state.set_current_project({ id = selection._data.id, name = selection._data.name })
				telescope_actions.close(prompt_bufnr)
				-- Navigate to views picker for this project
				M.views(selection._data.id)
			end
		end

		map("i", "<CR>", select_project)
		map("n", "<CR>", select_project)

		-- Close with q and Ctrl-c
		map("i", "<C-c>", telescope_actions.close)
		map("n", "q", telescope_actions.close)

		return true
	end

	pickers.new(picker_opts):find()
end

---Create views picker (views for a project or all views)
---@param project_id string? Optional project ID to filter views
function M.views(project_id)
	local finder_obj
	local prompt_title

	if project_id then
		-- Views for a specific project
		finder_obj = finders_module.views(project_id)
		local project_name = state.current_project and state.current_project.name or "Project"
		prompt_title = "Views: " .. project_name
	else
		-- All views
		finder_obj = finders_module.all_views()
		prompt_title = "All Views"
	end

	local picker_opts = create_picker_config(finder_obj, { prompt_title = prompt_title })

	-- Override mappings for view selection
	picker_opts.attach_mappings = function(prompt_bufnr, map)
		-- Select view: set state and navigate to view issues
		local function select_view()
			local action_state = require("telescope.actions.state")
			local selection = action_state.get_selected_entry()
			if selection and selection._data then
				-- Set current view in state
				state.set_current_view({
					id = selection._data.id,
					name = selection._data.name,
					project_id = project_id or (selection._data.project and selection._data.project.id),
				})
				telescope_actions.close(prompt_bufnr)
				-- Navigate to view issues picker
				M.view_issues(selection._data.id)
			end
		end

		map("i", "<CR>", select_view)
		map("n", "<CR>", select_view)

		-- Close with q and Ctrl-c
		map("i", "<C-c>", telescope_actions.close)
		map("n", "q", telescope_actions.close)

		return true
	end

	pickers.new(picker_opts):find()
end

---Create view issues picker (issues in a specific view)
---@param view_id string View ID
function M.view_issues(view_id)
	local finder_obj = finders_module.view_issues(view_id)

	-- Build title from state context
	local view_name = state.current_view and state.current_view.name or "View"
	local project_name = state.current_project and state.current_project.name or nil
	local prompt_title
	if project_name then
		prompt_title = view_name .. " (" .. project_name .. ")"
	else
		prompt_title = view_name
	end

	local picker_opts = create_picker_config(finder_obj, { prompt_title = prompt_title })

	-- Use existing issue picker mappings
	picker_opts.attach_mappings = function(prompt_bufnr, map)
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

		-- Create git branch
		map("i", "<C-g>", actions_module.create_branch)
		map("n", "<C-g>", actions_module.create_branch)

		-- Close picker with q
		map("i", "<C-c>", telescope_actions.close)
		map("n", "q", telescope_actions.close)

		return true
	end

	pickers.new(picker_opts):find()
end

---Show the current working issue (from context or branch detection)
---@param identifier string The issue identifier to display
function M.current_issue(identifier)
	local api = require("linear.api")
	local utils = require("linear.utils")

	-- Search for the issue by identifier
	api.search_issues(identifier, 10, function(data, err)
		if err then
			utils.notify("Failed to fetch issue: " .. err, vim.log.levels.ERROR)
			return
		end

		if not data or not data.issueSearch or not data.issueSearch.nodes or #data.issueSearch.nodes == 0 then
			utils.notify("Issue " .. identifier .. " not found", vim.log.levels.WARN)
			return
		end

		-- Find exact match by identifier
		local issue = nil
		for _, node in ipairs(data.issueSearch.nodes) do
			if node.identifier == identifier then
				issue = node
				break
			end
		end

		-- Fall back to first result if no exact match
		if not issue then
			issue = data.issueSearch.nodes[1]
		end

		-- Create single-item finder
		local finder_obj = require("telescope.finders").new_table({
			results = { issue },
			entry_maker = function(entry)
				local state_name = entry.state and entry.state.name or nil
				local status_icon = utils.status_icon(state_name)
				local priority_icon = utils.priority_icon(entry.priority)
				local pr_status = utils.pr_status(entry.attachments)

				local parts = { status_icon }
				if priority_icon ~= "" then
					table.insert(parts, priority_icon)
				end
				table.insert(parts, entry.identifier .. " - " .. entry.title)

				local display = table.concat(parts, " ") .. pr_status

				return {
					value = entry.id,
					display = display,
					ordinal = entry.identifier .. " " .. entry.title,
					path = entry.url,
					_data = entry,
				}
			end,
		})

		local cfg = config.get()
		local picker_opts = {
			prompt_title = "Current Issue: " .. identifier,
			finder = finder_obj,
			sorter = require("telescope.config").values.generic_sorter({}),
			attach_mappings = function(prompt_bufnr, map)
				map("i", "<CR>", actions_module.open_in_browser)
				map("n", "<CR>", actions_module.open_in_browser)
				map("i", "<C-y>", actions_module.copy_identifier)
				map("n", "<C-y>", actions_module.copy_identifier)
				map("i", "<M-y>", actions_module.copy_url)
				map("n", "<M-y>", actions_module.copy_url)
				map("i", "<C-s>", actions_module.toggle_status)
				map("n", "<C-s>", actions_module.toggle_status)
				map("i", "<C-g>", actions_module.create_branch)
				map("n", "<C-g>", actions_module.create_branch)
				map("i", "<C-c>", telescope_actions.close)
				map("n", "q", telescope_actions.close)
				return true
			end,
		}

		-- Add previewer if enabled
		if cfg.ui.telescope.previewer then
			picker_opts.previewer = previewer.make_previewer({})
		end

		-- Apply theme or custom layout from config
		if cfg.ui.telescope.theme and cfg.ui.telescope.theme ~= "" then
			local theme_getter = require("telescope.themes")["get_" .. cfg.ui.telescope.theme]
			if theme_getter then
				picker_opts = theme_getter(vim.tbl_extend("force", picker_opts, {
					layout_config = {
						width = cfg.ui.telescope.width or 0.8,
					},
				}))
			end
		else
			picker_opts.layout_strategy = cfg.ui.telescope.layout or "horizontal"
			picker_opts.layout_config = {
				width = cfg.ui.telescope.width or 0.8,
				height = cfg.ui.telescope.height or 0.8,
				prompt_position = "top",
				preview_width = 0.5,
			}
			picker_opts.sorting_strategy = "ascending"
		end

		pickers.new(picker_opts):find()
	end)
end

return M
