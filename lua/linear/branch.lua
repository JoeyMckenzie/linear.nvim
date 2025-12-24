---@class LinearBranch
---Branch creation utilities for Linear issues
local M = {}

local config = require("linear.config")
local context = require("linear.context")
local utils = require("linear.utils")

---Slugify a string for use in branch names
---@param str string The string to slugify
---@return string Slugified string
function M.slugify(str)
	if not str or str == "" then
		return ""
	end

	local result = str
		:lower()
		:gsub("[^%w%s-]", "") -- Remove special characters
		:gsub("%s+", "-") -- Replace spaces with hyphens
		:gsub("%-+", "-") -- Collapse multiple hyphens
		:gsub("^%-", "") -- Trim leading hyphens
		:gsub("%-$", "") -- Trim trailing hyphens

	-- Truncate to reasonable length (50 chars)
	if #result > 50 then
		result = result:sub(1, 50):gsub("%-$", "")
	end

	return result
end

---Generate branch name from issue
---@param issue table The issue data
---@param scope string The branch scope (feature, bugfix, etc.)
---@param include_title boolean Whether to include slugified title
---@return string The generated branch name
function M.generate_branch_name(issue, scope, include_title)
	local cfg = config.get()
	local branch_cfg = cfg.branch or {}

	local identifier = issue.identifier
	if branch_cfg.lowercase_identifier then
		identifier = identifier:lower()
	end

	local branch_name = scope .. "/" .. identifier

	if include_title and issue.title then
		local slug = M.slugify(issue.title)
		if slug ~= "" then
			branch_name = branch_name .. "-" .. slug
		end
	end

	return branch_name
end

---Create and checkout a git branch
---@param branch_name string The branch name to create
---@param callback fun(success: boolean, error: string?) Callback with result
function M.create_and_checkout(branch_name, callback)
	-- Check if branch already exists
	local check_handle = io.popen("git show-ref --verify --quiet refs/heads/" .. branch_name .. " 2>/dev/null; echo $?")
	if check_handle then
		local exit_code = check_handle:read("*l")
		check_handle:close()

		if exit_code == "0" then
			-- Branch exists, just checkout
			local checkout_handle = io.popen("git checkout " .. branch_name .. " 2>&1")
			if checkout_handle then
				local output = checkout_handle:read("*a")
				checkout_handle:close()
				if output:match("error") or output:match("fatal") then
					callback(false, "Failed to checkout branch: " .. output)
				else
					callback(true, nil)
				end
			else
				callback(false, "Failed to checkout branch")
			end
			return
		end
	end

	-- Create and checkout new branch
	local handle = io.popen("git checkout -b " .. branch_name .. " 2>&1")
	if not handle then
		callback(false, "Failed to create branch")
		return
	end

	local output = handle:read("*a")
	handle:close()

	if output:match("error") or output:match("fatal") then
		callback(false, "Failed to create branch: " .. output)
	else
		callback(true, nil)
	end
end

---Show scope picker and create branch for issue
---@param issue table The issue data (must have id, identifier, title)
---@param on_complete fun()? Optional callback when complete
function M.create_branch_for_issue(issue, on_complete)
	local cfg = config.get()
	local scopes = cfg.branch and cfg.branch.scopes or { "feature", "bugfix", "task", "chore" }

	-- Show scope picker
	vim.ui.select(scopes, {
		prompt = "Select branch type:",
	}, function(scope)
		if not scope then
			-- User cancelled
			if on_complete then
				on_complete()
			end
			return
		end

		-- Ask about including title
		vim.ui.select({ "Yes", "No" }, {
			prompt = "Include title in branch name?",
		}, function(include_choice)
			if not include_choice then
				-- User cancelled
				if on_complete then
					on_complete()
				end
				return
			end

			local include_title = include_choice == "Yes"
			local branch_name = M.generate_branch_name(issue, scope, include_title)

			-- Create and checkout the branch
			M.create_and_checkout(branch_name, function(success, err)
				if success then
					-- Set context to this issue
					context.set(issue.identifier)

					-- Clear statusline cache to refresh
					local statusline = require("linear.statusline")
					statusline.clear_cache()

					utils.notify("Created and switched to branch: " .. branch_name, vim.log.levels.INFO)
				else
					utils.notify(err or "Failed to create branch", vim.log.levels.ERROR)
				end

				if on_complete then
					on_complete()
				end
			end)
		end)
	end)
end

---Create branch from current context
---@return boolean success Whether context was available
function M.create_branch_from_context()
	local identifier = context.resolve()

	if not identifier then
		utils.notify("No issue context. Use :LinearCurrent PROJ-123 first.", vim.log.levels.WARN)
		return false
	end

	-- We need to fetch issue details to get the title
	local api = require("linear.api")
	api.search_issues(identifier, 1, function(data, err)
		if err then
			utils.notify("Failed to fetch issue: " .. err, vim.log.levels.ERROR)
			return
		end

		if not data or not data.issueSearch or not data.issueSearch.nodes or #data.issueSearch.nodes == 0 then
			utils.notify("Issue " .. identifier .. " not found", vim.log.levels.ERROR)
			return
		end

		-- Find exact match
		local issue = nil
		for _, node in ipairs(data.issueSearch.nodes) do
			if node.identifier == identifier then
				issue = node
				break
			end
		end

		if not issue then
			utils.notify("Issue " .. identifier .. " not found", vim.log.levels.ERROR)
			return
		end

		M.create_branch_for_issue(issue)
	end)

	return true
end

return M
