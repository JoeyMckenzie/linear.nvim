---@class LinearStatusline
---Statusline integration for displaying current issue
local M = {}

---@class StatuslineCache
---@field identifier string? Last resolved identifier
---@field status string? Cached status name
---@field title string? Cached issue title
---@field display string? Pre-formatted display string
local cache = {
	identifier = nil,
	status = nil,
	title = nil,
	display = nil,
}

---@type boolean
local fetch_in_progress = false

---Find issue by identifier in search results
---@param nodes table[] Array of issue nodes
---@param identifier string The identifier to match
---@return table? The matching issue or nil
local function find_issue_by_identifier(nodes, identifier)
	for _, issue in ipairs(nodes) do
		if issue.identifier == identifier then
			return issue
		end
	end
	return nil
end

---Truncate string to max length with ellipsis
---@param str string The string to truncate
---@param max_length number Maximum length
---@return string Truncated string
local function truncate(str, max_length)
	if not str or #str <= max_length then
		return str or ""
	end
	return str:sub(1, max_length - 1) .. "…"
end

---Build display string from cache
---@param identifier string The issue identifier
---@return string The formatted display string
local function build_display_string(identifier)
	local config = require("linear.config")
	local utils = require("linear.utils")
	local cfg = config.get()
	local statusline_cfg = cfg.ui and cfg.ui.statusline or {}

	local status_icon = utils.status_icon(cache.status)
	local parts = { status_icon, identifier }

	-- Add title if configured
	if statusline_cfg.show_title and cache.title then
		local max_len = statusline_cfg.title_max_length or 30
		local title = truncate(cache.title, max_len)
		table.insert(parts, "-")
		table.insert(parts, title)
	end

	return table.concat(parts, " ")
end

---Update cache with issue data and trigger redraw
---@param identifier string The issue identifier
---@param issue table The issue data
local function update_cache_from_issue(identifier, issue)
	cache.status = issue.state and issue.state.name or nil
	cache.title = issue.title
	cache.display = build_display_string(identifier)

	-- Trigger statusline redraw (if available)
	if vim.schedule and vim.cmd then
		vim.schedule(function()
			vim.cmd("redrawstatus")
		end)
	end
end

---Fetch issue status asynchronously and update cache
---@param identifier string The issue identifier to fetch
function M._fetch_status(identifier)
	if fetch_in_progress then
		return
	end

	fetch_in_progress = true

	local api = require("linear.api")

	api.search_issues(identifier, 5, function(data, err)
		fetch_in_progress = false

		if err or not data or not data.issueSearch or not data.issueSearch.nodes then
			return
		end

		local issue = find_issue_by_identifier(data.issueSearch.nodes, identifier)
		if issue then
			update_cache_from_issue(identifier, issue)
		end
	end)
end

---Get the statusline display string
---@return string The formatted statusline string or empty string if no issue
function M.get()
	local context = require("linear.context")
	local identifier = context.resolve()

	-- No issue detected
	if not identifier then
		-- Clear cache if we had one before
		if cache.identifier then
			M.clear_cache()
		end
		return ""
	end

	-- Cache hit - return cached display
	if identifier == cache.identifier and cache.display then
		return cache.display
	end

	-- Identifier changed - update cache
	cache.identifier = identifier
	cache.display = identifier -- Show identifier immediately while fetching
	cache.status = nil
	cache.title = nil

	-- Fetch status in background
	M._fetch_status(identifier)

	return cache.display
end

---Clear the statusline cache
function M.clear_cache()
	cache.identifier = nil
	cache.status = nil
	cache.title = nil
	cache.display = nil
end

return M
