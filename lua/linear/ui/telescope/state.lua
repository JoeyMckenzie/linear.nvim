---@class LinearTelescopeState
---State management for Telescope picker views
local M = {}

---Current filter context
---@type table
M.current_filters = {
	assignee = "me",
	status = nil,
	team = nil,
	project = nil,
	search_query = nil,
}

---Current view mode
---@type string
M.current_view = "issues"

---Cached data
---@type table
M.cache = {
	issues = {},
	boards = {},
	teams = {},
	last_update = 0,
}

---Navigation history
---@type table
M.history = {}

---Apply filters and merge with existing
---@param new_filters table New filters to apply
---@return void
function M.apply_filters(new_filters)
	M.current_filters = vim.tbl_deep_extend("force", M.current_filters, new_filters or {})
end

---Reset filters to defaults
---@return void
function M.reset_filters()
	M.current_filters = {
		assignee = "me",
		status = nil,
		team = nil,
		project = nil,
		search_query = nil,
	}
end

---Switch to a different view
---@param view_name string Name of view to switch to
---@param context table? Context data for the view
---@return void
function M.switch_view(view_name, context)
	M.current_view = view_name
	if context then
		M.history[view_name] = context
	end
end

---Get current view context
---@param view_name string Name of view
---@return table|nil
function M.get_view_context(view_name)
	return M.history[view_name]
end

---Clear cache
---@return void
function M.clear_cache()
	M.cache = {
		issues = {},
		boards = {},
		teams = {},
		last_update = 0,
	}
end

---Check if cache is still valid (within 5 minutes)
---@return boolean
function M.cache_valid()
	return (os.time() - M.cache.last_update) < 300
end

---Update cache timestamp
---@return void
function M.update_cache_time()
	M.cache.last_update = os.time()
end

return M
