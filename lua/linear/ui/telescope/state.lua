---@class LinearTelescopeState
---State management for Telescope picker views
local M = {}

---Current project context for navigation (projects → views → issues)
---@type { id: string, name: string }?
M.current_project = nil

---Current view context for navigation
---@type { id: string, name: string, project_id: string }?
M.current_view = nil

---Cached data
---@type table
M.cache = {
	issues = {},
	boards = {},
	teams = {},
	views = {}, -- keyed by project_id
	view_issues = {}, -- keyed by view_id
	last_update = 0,
}

---Navigation history
---@type table
M.history = {}

---Switch to a different view
---@param view_name string Name of view to switch to
---@param context table? Context data for the view
function M.switch_view(view_name, context)
	if context then
		M.history[view_name] = context
	end
end

---Check if cache is still valid (within 5 minutes)
---@return boolean
function M.cache_valid()
	return (os.time() - M.cache.last_update) < 300
end

---Update cache timestamp
function M.update_cache_time()
	M.cache.last_update = os.time()
end

---Set current project context for navigation
---@param project { id: string, name: string }?
function M.set_current_project(project)
	M.current_project = project
end

---Set current view context for navigation
---@param view { id: string, name: string, project_id: string }?
function M.set_current_view(view)
	M.current_view = view
end

---Clear navigation state (both project and view)
function M.clear_navigation()
	M.current_project = nil
	M.current_view = nil
end

return M
