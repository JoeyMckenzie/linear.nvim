---@type any
local curl
local ok, curl_module = pcall(require, "plenary.curl")

if ok then
	curl = curl_module
end

---
---@type any
local config = require("linear.config")

---@alias APICallback fun(data: table|nil, error: string|nil)

---@class LinearAPI
local M = {}

---@type string?
local api_key = nil

---@type string
local base_url = "https://api.linear.app/graphql"

---Initialize API with key
---@param key? string The Linear API key
function M.setup(key)
	api_key = key or config.get_api_key()
	if not api_key then
		error("Linear.nvim: API key is required")
	end
end

---Handle GraphQL response
---@param result table The HTTP response
---@param callback APICallback Callback with (data, error)
local function handle_response(result, callback)
	if not result then
		callback(nil, "No response from Linear API")
		return
	end

	if result.status and result.status ~= 200 then
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

	local decode_ok, response = pcall(vim.json.decode, result.body, { luanil = { object = true, array = true } })
	if not decode_ok then
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
end

---Make a GraphQL request to Linear API
---@param query_str string The GraphQL query or mutation
---@param variables? table GraphQL variables
---@param callback APICallback Callback with (data, error)
function M.query(query_str, variables, callback)
	if not api_key then
		callback(nil, "API not initialized. Call M.setup(api_key) first")
		return
	end

	if not curl then
		callback(nil, "plenary.nvim is not installed. Please install it with your plugin manager")
		return
	end

	-- Build request body
	local body_table = {
		query = query_str,
	}
	-- Only include variables if provided and non-empty
	if variables and next(variables) then
		body_table.variables = variables
	end
	local body = vim.json.encode(body_table)

	-- Make the request
	-- Note: Linear API expects the API key directly, not as a Bearer token
	local request = curl.post(base_url, {
		headers = {
			["Content-Type"] = "application/json",
			["Authorization"] = api_key,
		},
		body = body,
		timeout = 30000,
	})

	if not request then
		callback(nil, "Failed to initialize HTTP request. Is plenary.nvim properly installed?")
		return
	end

	-- Check if we got a response directly (synchronous) or a request builder (asynchronous)
	if request.after and type(request.after) == "function" then
		-- Asynchronous API with callbacks
		local request_ok, request_err = pcall(function()
			request
				:after(function(result)
					handle_response(result, callback)
				end)
				:catch(function(err)
					callback(nil, "Request failed: " .. tostring(err))
				end)
		end)

		if not request_ok then
			callback(nil, "Error setting up request handlers: " .. tostring(request_err))
		end
	else
		-- Synchronous API - response is returned directly
		handle_response(request, callback)
	end
end

---Get current viewer (authenticated user)
---@param callback fun(data: {viewer: {id: string, name: string, email: string}}|nil, error: string|nil)
function M.get_viewer(callback)
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

---Get assigned issues
---@param filters? table Filter criteria
---@param callback APICallback Callback with (data, error)
function M.get_issues(filters, callback)
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

---Get single issue by ID
---@param id string The issue ID
---@param callback APICallback Callback with (data, error)
function M.get_issue(id, callback)
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

---Create a new issue
---@param data table Issue creation input
---@param callback APICallback Callback with (data, error)
function M.create_issue(data, callback)
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

---Create a comment on an issue
---@param issue_id string The issue ID
---@param body string The comment body
---@param callback APICallback Callback with (data, error)
function M.create_comment(issue_id, body, callback)
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

---Get all teams
---@param callback APICallback Callback with (data, error)
function M.get_teams(callback)
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

---Get workflow states
---@param callback APICallback Callback with (data, error)
function M.get_states(callback)
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

---Get projects/boards for navigation
---@param callback APICallback Callback with (data, error)
function M.get_projects(callback)
	local query = [[
    query GetProjects {
      projects {
        nodes {
          id
          name
          description
          icon
          url
        }
        pageInfo {
          hasNextPage
          endCursor
        }
      }
    }
  ]]

	M.query(query, {}, callback)
end

---Get issues with filtering and sorting
---@param filter table Filter criteria
---@param _sort table? Sort configuration (unused)
---@param limit number Max results
---@param callback APICallback Callback with (data, error)
function M.get_issues_filtered(filter, _sort, limit, callback)
	limit = limit or 50
	filter = filter or {}

	local query = [[
    query GetIssuesFiltered($filter: IssueFilter, $first: Int) {
      issues(filter: $filter, first: $first) {
        nodes {
          id
          identifier
          title
          description
          state {
            id
            name
            color
          }
          priority
          assignee {
            id
            name
            avatarUrl
          }
          project {
            id
            name
          }
          team {
            id
            name
          }
          attachments {
            nodes {
              sourceType
              title
              subtitle
              url
            }
          }
          createdAt
          updatedAt
          url
        }
        pageInfo {
          hasNextPage
          endCursor
        }
      }
    }
  ]]

	local variables = {
		filter = filter,
		first = limit,
	}

	M.query(query, variables, callback)
end

---Get full issue details including comments
---@param issue_id string Issue ID
---@param callback APICallback Callback with (data, error)
function M.get_issue_full(issue_id, callback)
	local query = [[
    query GetIssueFull($id: String!) {
      issue(id: $id) {
        id
        identifier
        title
        description
        state {
          id
          name
          color
        }
        priority
        assignee {
          id
          name
          email
          avatarUrl
        }
        project {
          id
          name
        }
        team {
          id
          name
        }
        createdAt
        updatedAt
        url
        comments(first: 10) {
          nodes {
            id
            body
            user {
              id
              name
              avatarUrl
            }
            createdAt
          }
        }
      }
    }
  ]]

	local variables = { id = issue_id }

	M.query(query, variables, callback)
end

---Search issues by text query or identifier
---@param query_text string Search query (can be identifier like "PROJ-7444" or text)
---@param limit number Max results
---@param callback APICallback Callback with (data, error)
function M.search_issues(query_text, limit, callback)
	limit = limit or 50

	-- Use issues query with filter
	local query = [[
    query SearchIssues($filter: IssueFilter, $first: Int) {
      issues(filter: $filter, first: $first) {
        nodes {
          id
          identifier
          title
          description
          state {
            id
            name
            color
          }
          priority
          assignee {
            id
            name
          }
          attachments {
            nodes {
              sourceType
              title
              subtitle
              url
            }
          }
          createdAt
          updatedAt
          url
        }
        pageInfo {
          hasNextPage
          endCursor
        }
      }
    }
  ]]

	-- Build filter based on query type
	-- Check if query looks like an identifier (e.g., "PROJ-7444" or just "7444")
	local filter
	local number_match = query_text:match("%-?(%d+)$")

	if number_match then
		-- Query contains a number - search by issue number OR title
		local issue_number = tonumber(number_match)
		filter = {
			["or"] = {
				{ number = { eq = issue_number } },
				{ title = { containsIgnoreCase = query_text } },
			},
		}
	else
		-- Text search only - search title and description
		filter = {
			["or"] = {
				{ title = { containsIgnoreCase = query_text } },
				{ description = { contains = query_text } },
			},
		}
	end

	local variables = {
		filter = filter,
		first = limit,
	}

	-- Wrap callback to normalize response structure
	M.query(query, variables, function(data, err)
		if err then
			callback(nil, err)
			return
		end
		-- Return data with issueSearch key for backward compatibility with finders
		if data and data.issues then
			callback({ issueSearch = data.issues }, nil)
		else
			callback(data, nil)
		end
	end)
end

---Update an issue
---@param issue_id string Issue ID
---@param updates table Fields to update
---@param callback APICallback Callback with (data, error)
function M.update_issue(issue_id, updates, callback)
	local query = [[
    mutation UpdateIssue($id: String!, $input: IssueUpdateInput!) {
      issueUpdate(id: $id, input: $input) {
        issue {
          id
          identifier
          title
          state {
            id
            name
          }
          priority
          updatedAt
        }
      }
    }
  ]]

	local variables = {
		id = issue_id,
		input = updates,
	}

	M.query(query, variables, callback)
end

---Get active cycle for a team
---@param team_id string Team ID
---@param callback APICallback Callback with (data, error)
function M.get_active_cycle(team_id, callback)
	local query = [[
    query GetActiveCycle($teamId: String!) {
      team(id: $teamId) {
        id
        name
        activeCycle {
          id
          name
          startsAt
          endsAt
          issues {
            nodes {
              id
              identifier
              title
              description
              state {
                id
                name
                color
              }
              priority
              assignee {
                id
                name
              }
              attachments {
                nodes {
                  sourceType
                  title
                  subtitle
                  url
                }
              }
              createdAt
              updatedAt
              url
            }
          }
        }
      }
    }
  ]]

	M.query(query, { teamId = team_id }, callback)
end

---Get custom views for a specific project
---@param project_id string The project ID
---@param callback APICallback Callback with (data, error)
function M.get_project_views(project_id, callback)
	if not project_id or project_id == "" then
		callback(nil, "project_id is required")
		return
	end

	local query = [[
    query GetProjectViews($projectId: String!) {
      project(id: $projectId) {
        id
        name
        customViews {
          nodes {
            id
            name
            description
            icon
            color
            shared
            team {
              id
              name
            }
          }
        }
      }
    }
  ]]

	M.query(query, { projectId = project_id }, callback)
end

---Get all custom views the user has access to
---@param callback APICallback Callback with (data, error)
function M.get_custom_views(callback)
	local query = [[
    query GetCustomViews {
      customViews {
        nodes {
          id
          name
          description
          icon
          color
          shared
          team {
            id
            name
          }
        }
      }
    }
  ]]

	M.query(query, {}, callback)
end

---Get issues for a specific custom view
---@param view_id string The custom view ID
---@param callback APICallback Callback with (data, error)
function M.get_view_issues(view_id, callback)
	if not view_id or view_id == "" then
		callback(nil, "view_id is required")
		return
	end

	local query = [[
    query GetViewIssues($viewId: String!) {
      customView(id: $viewId) {
        id
        name
        issues {
          nodes {
            id
            identifier
            title
            description
            state {
              id
              name
              color
            }
            priority
            assignee {
              id
              name
              avatarUrl
            }
            project {
              id
              name
            }
            team {
              id
              name
            }
            attachments {
              nodes {
                sourceType
                title
                subtitle
                url
              }
            }
            createdAt
            updatedAt
            url
          }
          pageInfo {
            hasNextPage
            endCursor
          }
        }
      }
    }
  ]]

	M.query(query, { viewId = view_id }, callback)
end

return M
