local curl = require("plenary.curl")
local config = require("linear.config")

local M = {}

local api_key = nil
local base_url = "https://api.linear.app/graphql"

-- Initialize API with key
M.setup = function(key)
	api_key = key or config.get_api_key()
	if not api_key then
		error("Linear.nvim: API key is required")
	end
end

-- Make a GraphQL request
M.query = function(query_str, variables, callback)
	if not api_key then
		callback(nil, "API not initialized. Call M.setup(api_key) first")
		return
	end

	local body = vim.json.encode({
		query = query_str,
		variables = variables or {},
	})

	local request = curl.post(base_url, {
		headers = {
			["Content-Type"] = "application/json",
			["Authorization"] = api_key,
		},
		body = body,
		timeout = 30000,
	})

	request:after(function(result)
		if result.status ~= 200 then
			local error_msg = "HTTP " .. result.status
			if result.body then
				error_msg = error_msg .. ": " .. result.body
			end
			callback(nil, error_msg)
			return
		end

		if not result.body then
			callback(nil, "Empty response from Linear API")
			return
		end

		local ok, response = pcall(vim.json.decode, result.body)
		if not ok then
			callback(nil, "Failed to parse response: " .. response)
			return
		end

		-- Check for GraphQL errors
		if response.errors then
			local error_msgs = {}
			for _, err in ipairs(response.errors) do
				table.insert(error_msgs, err.message or tostring(err))
			end
			callback(nil, table.concat(error_msgs, ", "))
			return
		end

		callback(response.data, nil)
	end):catch(function(err)
		callback(nil, "Request failed: " .. tostring(err))
	end)
end

-- Convenience wrapper: Get current viewer (for auth test)
M.get_viewer = function(callback)
	local query = [[
    query Me {
      viewer {
        id
        name
        email
      }
    }
  ]]
	M.query(query, {}, callback)
end

-- Convenience wrapper: Get assigned issues
M.get_issues = function(filters, callback)
	local query = [[
    query MyIssues($filter: IssueFilter, $first: Int) {
      issues(filter: $filter, first: $first) {
        nodes {
          id
          identifier
          title
          description
          state {
            name
            color
          }
          priority
          assignee {
            name
          }
          createdAt
          updatedAt
        }
      }
    }
  ]]

	local variables = {
		filter = filters or {},
		first = 50,
	}

	M.query(query, variables, callback)
end

-- Get single issue
M.get_issue = function(id, callback)
	local query = [[
    query GetIssue($id: String!) {
      issue(id: $id) {
        id
        identifier
        title
        description
        state {
          name
          color
        }
        priority
        assignee {
          name
        }
        createdAt
        updatedAt
      }
    }
  ]]

	M.query(query, { id = id }, callback)
end

-- Create an issue
M.create_issue = function(data, callback)
	local mutation = [[
    mutation CreateIssue($input: IssueCreateInput!) {
      issueCreate(input: $input) {
        success
        issue {
          id
          identifier
          title
        }
      }
    }
  ]]

	M.query(mutation, { input = data }, callback)
end

-- Update an issue
M.update_issue = function(id, updates, callback)
	local mutation = [[
    mutation UpdateIssue($id: String!, $input: IssueUpdateInput!) {
      issueUpdate(id: $id, input: $input) {
        success
        issue {
          id
          identifier
          title
          state {
            name
          }
        }
      }
    }
  ]]

	M.query(mutation, { id = id, input = updates }, callback)
end

-- Create a comment on an issue
M.create_comment = function(issue_id, body, callback)
	local mutation = [[
    mutation CreateComment($input: CommentCreateInput!) {
      commentCreate(input: $input) {
        success
        comment {
          id
          body
        }
      }
    }
  ]]

	M.query(mutation, { input = { issueId = issue_id, body = body } }, callback)
end

-- Get teams
M.get_teams = function(callback)
	local query = [[
    query GetTeams {
      teams {
        nodes {
          id
          name
        }
      }
    }
  ]]

	M.query(query, {}, callback)
end

-- Get issue states
M.get_states = function(callback)
	local query = [[
    query GetStates {
      workflowStates {
        nodes {
          id
          name
          color
        }
      }
    }
  ]]

	M.query(query, {}, callback)
end

return M
