---@class LinearTelescopeFinders
---Custom Telescope finders for Linear data
local finders = {}

local api = require("linear.api")
local state = require("linear.ui.telescope.state")
local telescope_finders = require("telescope.finders")
local utils = require("linear.utils")

---Transform issue data to Telescope entry format
---@param issue table Linear issue data
---@param opts table? Options { show_assignee: boolean }
---@return table Formatted entry
local function format_issue_entry(issue, opts)
	opts = opts or {}

	local state_name = issue.state and issue.state.name or nil
	local status_icon = utils.status_icon(state_name)
	local priority_icon = utils.priority_icon(issue.priority)
	local pr_status = utils.pr_status(issue.attachments)

	-- Build display string: {status} {priority} {identifier} - {title} [(assignee)] [PR:status]
	local parts = { status_icon }

	if priority_icon ~= "" then
		table.insert(parts, priority_icon)
	end

	table.insert(parts, issue.identifier .. " - " .. issue.title)

	if opts.show_assignee then
		local assignee = issue.assignee and issue.assignee.name or "Unassigned"
		table.insert(parts, "(" .. assignee .. ")")
	end

	local display = table.concat(parts, " ") .. pr_status

	return {
		value = issue.id,
		display = display,
		ordinal = issue.identifier .. " " .. issue.title,
		path = issue.url,
		_data = issue,
	}
end

---Transform project data to Telescope entry format
---@param project table Linear project data
---@return table Formatted entry
local function format_board_entry(project)
	return {
		value = project.id,
		display = project.name,
		ordinal = project.name .. " " .. (project.description or ""),
		path = project.url,
		_data = project,
	}
end

---Transform team data to Telescope entry format
---@param team table Linear team data
---@return table Formatted entry
local function format_team_entry(team)
	return {
		value = team.id,
		display = team.name,
		ordinal = team.name,
		_data = team,
	}
end

---Transform view data to Telescope entry format
---@param view table Linear custom view data
---@return table Formatted entry
local function format_view_entry(view)
	-- Use icon if available, otherwise just the name
	local display = view.icon and (view.icon .. " " .. view.name) or view.name

	return {
		value = view.id,
		display = display,
		ordinal = view.name .. " " .. (view.description or ""),
		_data = view,
	}
end

---Helper to create a finder from API call
---@param api_fn function API function to call
---@param entry_maker function Function to format entries
---@param cache_key string? Key for caching results
---@return table Telescope finder
local function async_issues_finder(api_fn, entry_maker, cache_key)
	local results = {}

	-- Check cache first
	if cache_key and state.cache_valid() and state.cache.issues[cache_key] then
		local cached = state.cache.issues[cache_key]
		return telescope_finders.new_table({
			results = cached,
			entry_maker = function(entry)
				return entry_maker(entry)
			end,
		})
	end

	-- Call API and populate results (plenary.curl is synchronous)
	api_fn(function(data, err)
		if err then
			vim.notify("Linear.nvim: " .. err, vim.log.levels.ERROR)
		elseif data and data.issues and data.issues.nodes then
			-- Populate results in-place (not reassign) so finder sees the data
			vim.list_extend(results, data.issues.nodes)
			if cache_key then
				state.cache.issues[cache_key] = data.issues.nodes
				state.update_cache_time()
			end
		end
	end)

	return telescope_finders.new_table({
		results = results,
		entry_maker = function(entry)
			return entry_maker(entry)
		end,
	})
end

---Helper to create a finder from API call (generic)
---@param api_fn function API function to call
---@param entry_maker function Function to format entries
---@param data_path string Path to data in response (e.g., "issues.nodes", "projects.nodes")
---@param cache_key string? Key for caching results
---@param cache_type string? Cache type: "boards", "teams", "views", "view_issues"
---@return table Telescope finder
local function async_finder(api_fn, entry_maker, data_path, cache_key, cache_type)
	local results = {}
	-- Use explicit cache_type if provided, otherwise infer from data_path
	local cache_field = cache_type or data_path:match("^([^.]+)")

	-- Check cache first
	if cache_key and state.cache_valid() then
		local cached
		if cache_field == "projects" and state.cache.boards[cache_key] then
			cached = state.cache.boards[cache_key]
		elseif cache_field == "teams" and state.cache.teams[cache_key] then
			cached = state.cache.teams[cache_key]
		elseif cache_field == "views" and state.cache.views[cache_key] then
			cached = state.cache.views[cache_key]
		elseif cache_field == "view_issues" and state.cache.view_issues[cache_key] then
			cached = state.cache.view_issues[cache_key]
		end
		if cached then
			return telescope_finders.new_table({
				results = cached,
				entry_maker = function(entry)
					return entry_maker(entry)
				end,
			})
		end
	end

	-- Call API and populate results (plenary.curl is synchronous)
	api_fn(function(data, err)
		if err then
			vim.notify("Linear.nvim: " .. err, vim.log.levels.ERROR)
		elseif data then
			-- Navigate to the data path (e.g., data.issues.nodes or data.projects.nodes)
			local current = data
			for part in data_path:gmatch("[^.]+") do
				current = current[part]
				if not current then
					break
				end
			end

			if current then
				-- Populate results in-place (not reassign) so finder sees the data
				vim.list_extend(results, current)

				-- Cache results
				if cache_key then
					if cache_field == "projects" then
						state.cache.boards[cache_key] = current
					elseif cache_field == "teams" then
						state.cache.teams[cache_key] = current
					elseif cache_field == "views" then
						state.cache.views[cache_key] = current
					elseif cache_field == "view_issues" then
						state.cache.view_issues[cache_key] = current
					end
					state.update_cache_time()
				end
			end
		end
	end)

	return telescope_finders.new_table({
		results = results,
		entry_maker = function(entry)
			return entry_maker(entry)
		end,
	})
end

---Create issues finder for assigned issues
---@param _filter_opts table? Filter options
---@return table Telescope finder
function finders.issues_assigned(_filter_opts)
	return async_issues_finder(
		function(callback)
			api.get_issues_filtered({ assignee = { isMe = { eq = true } } }, nil, 50, callback)
		end,
		format_issue_entry,
		"assigned"
	)
end

---Create finder for all issues
---@param _filter_opts table? Filter options
---@return table Telescope finder
function finders.issues_all(_filter_opts)
	return async_issues_finder(
		function(callback)
			api.get_issues_filtered({}, nil, 50, callback)
		end,
		format_issue_entry,
		"all"
	)
end

---Create finder for issues by team
---@param team_id string Team ID
---@param _filter_opts table? Filter options
---@return table Telescope finder
function finders.issues_by_team(team_id, _filter_opts)
	return async_issues_finder(
		function(callback)
			api.get_issues_filtered({ team = { id = { eq = team_id } } }, nil, 50, callback)
		end,
		format_issue_entry,
		"team_" .. team_id
	)
end

---Create finder for issues by board/project
---@param project_id string Project ID
---@param _filter_opts table? Filter options
---@return table Telescope finder
function finders.issues_by_board(project_id, _filter_opts)
	return async_issues_finder(
		function(callback)
			api.get_issues_filtered({ project = { id = { eq = project_id } } }, nil, 50, callback)
		end,
		format_issue_entry,
		"board_" .. project_id
	)
end

---Create finder for issue search
---@param query string Search query
---@param _filter_opts table? Filter options
---@return table Telescope finder
function finders.issues_search(query, _filter_opts)
	local results = {}

	-- plenary.curl is synchronous, so callback runs before return
	api.search_issues(query, 50, function(data, err)
		if err then
			vim.notify("Linear.nvim: " .. err, vim.log.levels.ERROR)
		elseif data and data.issueSearch and data.issueSearch.nodes then
			-- Populate results in-place (not reassign) so finder sees the data
			vim.list_extend(results, data.issueSearch.nodes)
		end
	end)

	return telescope_finders.new_table({
		results = results,
		entry_maker = function(entry)
			return format_issue_entry(entry)
		end,
	})
end

---Create finder for boards/projects
---@param _filter_opts table? Filter options
---@return table Telescope finder
function finders.boards(_filter_opts)
	return async_finder(
		function(callback)
			api.get_projects(callback)
		end,
		format_board_entry,
		"projects.nodes",
		"boards"
	)
end

---Create finder for teams
---@param _filter_opts table? Filter options
---@return table Telescope finder
function finders.teams(_filter_opts)
	return async_finder(
		function(callback)
			api.get_teams(callback)
		end,
		format_team_entry,
		"teams.nodes",
		"teams"
	)
end

---Create finder for cycle issues (shows assignee)
---@param team_id string Team ID
---@param cycle_data table Cycle data with issues
---@return table Telescope finder
function finders.cycle_issues(team_id, cycle_data)
	local results = {}

	if cycle_data and cycle_data.issues and cycle_data.issues.nodes then
		vim.list_extend(results, cycle_data.issues.nodes)
	end

	return telescope_finders.new_table({
		results = results,
		entry_maker = function(entry)
			return format_issue_entry(entry, { show_assignee = true })
		end,
	})
end

---Create finder for projects (alias to boards for semantic clarity)
---@param filter_opts table? Filter options
---@return table Telescope finder
function finders.projects(filter_opts)
	return finders.boards(filter_opts)
end

---Create finder for views of a specific project
---@param project_id string Project ID
---@return table Telescope finder
function finders.views(project_id)
	return async_finder(
		function(callback)
			api.get_project_views(project_id, callback)
		end,
		format_view_entry,
		"project.customViews.nodes",
		project_id,
		"views"
	)
end

---Create finder for all custom views
---@return table Telescope finder
function finders.all_views()
	return async_finder(
		function(callback)
			api.get_custom_views(callback)
		end,
		format_view_entry,
		"customViews.nodes",
		"all",
		"views"
	)
end

---Create finder for issues in a specific view
---@param view_id string View ID
---@return table Telescope finder
function finders.view_issues(view_id)
	return async_finder(
		function(callback)
			api.get_view_issues(view_id, callback)
		end,
		format_issue_entry,
		"customView.issues.nodes",
		view_id,
		"view_issues"
	)
end

return finders
