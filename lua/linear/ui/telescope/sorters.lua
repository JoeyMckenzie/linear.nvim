---@class LinearTelescopeSorters
---Custom sorters for Telescope pickers
local M = {}

---Create priority-based sorter
---@return table Telescope sorter
function M.priority_sorter()
	-- Implementation will be added in Phase 2
	return {}
end

---Create date-based sorter
---@param field string Field to sort by (createdAt, updatedAt)
---@return table Telescope sorter
function M.date_sorter(field)
	-- Implementation will be added in Phase 2
	return {}
end

---Create custom search scorer
---@return table Telescope sorter
function M.search_sorter()
	-- Implementation will be added in Phase 2
	return {}
end

return M
