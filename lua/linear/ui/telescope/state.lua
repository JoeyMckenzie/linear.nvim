---@class LinearTelescopeState
---State management for Telescope picker views
local M = {}

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

return M
