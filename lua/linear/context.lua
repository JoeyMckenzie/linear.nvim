---@class LinearContext
---Session-scoped context for tracking current working issue
local M = {}

---@type string?
local current_identifier = nil

---Get the manually set session context
---@return string? identifier The current issue identifier or nil
function M.get()
	return current_identifier
end

---Set the session context to an issue identifier
---@param identifier string The issue identifier (e.g., "SUP-1234")
function M.set(identifier)
	current_identifier = identifier
end

---Clear the session context
function M.clear()
	current_identifier = nil
end

---Detect issue identifier from current git branch
---@return string? identifier The detected identifier or nil
function M.detect_from_branch()
	-- Get current branch name
	local handle = io.popen("git branch --show-current 2>/dev/null")
	if not handle then
		return nil
	end

	local branch = handle:read("*l")
	handle:close()

	if not branch or branch == "" then
		return nil
	end

	-- Match pattern like SUP-1234, RAISE-999, etc. anywhere in branch name
	local identifier = branch:match("([A-Z]+-[0-9]+)")
	return identifier
end

---Resolve the current issue identifier (session context or auto-detect)
---@return string? identifier The resolved identifier or nil
function M.resolve()
	-- Session context takes priority
	local session = M.get()
	if session then
		return session
	end

	-- Fall back to branch detection
	return M.detect_from_branch()
end

---Check if we're in a git repository
---@return boolean
function M.is_git_repo()
	local handle = io.popen("git rev-parse --is-inside-work-tree 2>/dev/null")
	if not handle then
		return false
	end

	local result = handle:read("*l")
	handle:close()

	return result == "true"
end

return M
