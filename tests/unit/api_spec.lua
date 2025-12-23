---@diagnostic disable: need-check-nil, undefined-field
---@type any
local mock_curl = {}

---@class MockRequest
---@field private _after_fn function?
---@field private _catch_fn function?
local MockRequest = {}

---@param callback function
---@return MockRequest
function MockRequest:after(callback)
	self._after_fn = callback
	return self
end

---@param callback function
---@return MockRequest
function MockRequest:catch(callback)
	self._catch_fn = callback
	return self
end

---Trigger the after callback with a response
---@param result table
function MockRequest:trigger_after(result)
	if self._after_fn then
		self._after_fn(result)
	end
end

---Trigger the catch callback with an error
---@param error any
function MockRequest:trigger_catch(error)
	if self._catch_fn then
		self._catch_fn(error)
	end
end

---Mock curl.post function
---@param _url string
---@param _config table
---@return MockRequest
function mock_curl.post(_url, _config)
	return setmetatable({}, { __index = MockRequest })
end

describe("linear.api", function()
	before_each(function()
		-- Replace plenary.curl with our mock
		package.loaded["plenary.curl"] = mock_curl
		package.loaded["linear.api"] = nil
	end)

	after_each(function()
		-- Restore plenary.curl
		package.loaded["plenary.curl"] = require("plenary.curl")
	end)

	describe("setup()", function()
		it("initializes API with provided key", function()
			local api = require("linear.api")
			assert.has_no.errors(function()
				api.setup("lin_api_test_key_12345")
			end)
		end)

		it("throws error if no key provided and none available", function()
			-- Mock config to return nil for API key
			package.loaded["linear.config"] = {
				get_api_key = function()
					return nil
				end,
			}

			local api = require("linear.api")
			assert.has.errors(function()
				api.setup(nil)
			end)
		end)
	end)

	describe("query()", function()
		it("makes POST request with GraphQL query", function()
			local api = require("linear.api")
			api.setup("lin_api_test_key")

			local request_made = false
			local captured_body = nil

			-- Mock curl.post to capture the request
			mock_curl.post = function(_url, config)
				request_made = true
				captured_body = config.body
				return setmetatable({}, { __index = MockRequest })
			end

			api.query("query { test }", {}, function() end)

			assert.is_true(request_made)
			assert.is_not_nil(captured_body)
		end)

		it("includes Authorization header with API key", function()
			local api = require("linear.api")
			api.setup("lin_api_test_key_xyz")

			local captured_headers = nil

			mock_curl.post = function(_url, config)
				captured_headers = config.headers
				return setmetatable({}, { __index = MockRequest })
			end

			api.query("query { test }", {}, function() end)

			assert.is_not_nil(captured_headers)
			assert.equal(captured_headers["Authorization"], "lin_api_test_key_xyz")
		end)

		it("calls callback with data on successful response", function()
			local api = require("linear.api")
			api.setup("lin_api_test_key")

			local callback_invoked = false
			local callback_data = nil
			local callback_error = nil

			local last_request = nil
			mock_curl.post = function(_url, _config)
				local request = setmetatable({}, { __index = MockRequest })
				last_request = request
				return request
			end

			api.query("query { test }", {}, function(data, error)
				callback_invoked = true
				callback_data = data
				callback_error = error
			end)

			-- Simulate successful response
			if last_request then
				-- Use a properly formatted JSON string for the response body
				local response_json = '{"data":{"viewer":{"id":"user-1","name":"Test User"}}}'
				last_request:trigger_after({
					status = 200,
					body = response_json,
				})
			end

			assert.is_true(callback_invoked)
			assert.is_nil(callback_error)
			assert.is_not_nil(callback_data)
			assert.is_table(callback_data)
			assert.equal(callback_data.viewer.id, "user-1")
		end)

		it("calls callback with error on HTTP error", function()
			local api = require("linear.api")
			api.setup("lin_api_test_key")

			local callback_invoked = false
			local callback_error = nil

			local last_request = nil
			mock_curl.post = function(_url, _config)
				local request = setmetatable({}, { __index = MockRequest })
				last_request = request
				return request
			end

			api.query("query { test }", {}, function(_data, error)
				callback_invoked = true
				callback_error = error
			end)

			-- Simulate error response
			if last_request then
				last_request:trigger_after({
					status = 401,
					body = "Unauthorized",
				})
			end

			assert.is_true(callback_invoked)
			assert.is_not_nil(callback_error)
			assert.matches("401", callback_error)
		end)

		it("handles GraphQL errors in response", function()
			local api = require("linear.api")
			api.setup("lin_api_test_key")

			local callback_error = nil

			local last_request = nil
			mock_curl.post = function(_url, _config)
				local request = setmetatable({}, { __index = MockRequest })
				last_request = request
				return request
			end

			api.query("query { test }", {}, function(_data, error)
				callback_error = error
			end)

			-- Simulate GraphQL error
			if last_request then
				local response_json = '{"errors":[{"message":"Invalid query"}]}'
				last_request:trigger_after({
					status = 200,
					body = response_json,
				})
			end

			assert.is_not_nil(callback_error)
			assert.matches("Invalid query", callback_error)
		end)

		it("handles empty response", function()
			local api = require("linear.api")
			api.setup("lin_api_test_key")

			local callback_error = nil

			local last_request = nil
			mock_curl.post = function(_url, _config)
				local request = setmetatable({}, { __index = MockRequest })
				last_request = request
				return request
			end

			api.query("query { test }", {}, function(_data, error)
				callback_error = error
			end)

			-- Simulate empty response
			if last_request then
				last_request:trigger_after({
					status = 200,
					body = nil,
				})
			end

			assert.is_not_nil(callback_error)
			assert.matches("Empty response", callback_error)
		end)
	end)

	describe("get_viewer()", function()
		it("queries for current user information", function()
			local api = require("linear.api")
			api.setup("lin_api_test_key")

			local query_called = false

			-- Mock the query function
			local original_query = api.query
			api.query = function(query_str, _vars, _callback)
				query_called = true
				assert.matches("viewer", query_str)
			end

			api.get_viewer(function() end)

			assert.is_true(query_called)

			-- Restore
			api.query = original_query
		end)
	end)

	describe("get_issues()", function()
		it("queries for issues with filters", function()
			local api = require("linear.api")
			api.setup("lin_api_test_key")

			local query_called = false
			local captured_filters = nil

			local original_query = api.query
			api.query = function(_query_str, variables, _callback)
				query_called = true
				captured_filters = variables.filter
			end

			local filters = { assignee = { id = { eq = "user-1" } } }
			api.get_issues(filters, function() end)

			assert.is_true(query_called)
			assert.is_not_nil(captured_filters)

			api.query = original_query
		end)

		it("defaults to empty filters if not provided", function()
			local api = require("linear.api")
			api.setup("lin_api_test_key")

			local captured_filters = nil

			local original_query = api.query
			api.query = function(_query_str, variables, _callback)
				captured_filters = variables.filter
			end

			api.get_issues(nil, function() end)

			assert.is_table(captured_filters)

			api.query = original_query
		end)
	end)

	describe("get_issue()", function()
		it("queries for a single issue by ID", function()
			local api = require("linear.api")
			api.setup("lin_api_test_key")

			local query_called = false
			local captured_id = nil

			local original_query = api.query
			api.query = function(query_str, variables, _callback)
				query_called = true
				captured_id = variables.id
				assert.matches("issue%(id:", query_str)
			end

			api.get_issue("issue-123", function() end)

			assert.is_true(query_called)
			assert.equal("issue-123", captured_id)

			api.query = original_query
		end)
	end)

	describe("create_issue()", function()
		it("sends mutation with issue data", function()
			local api = require("linear.api")
			api.setup("lin_api_test_key")

			local mutation_called = false
			local captured_input = nil

			local original_query = api.query
			api.query = function(query_str, variables, _callback)
				mutation_called = true
				captured_input = variables.input
				assert.matches("issueCreate", query_str)
			end

			local issue_data = {
				title = "New Issue",
				description = "Description",
				teamId = "team-1",
			}
			api.create_issue(issue_data, function() end)

			assert.is_true(mutation_called)
			assert.equal("New Issue", captured_input.title)
			assert.equal("team-1", captured_input.teamId)

			api.query = original_query
		end)
	end)

	describe("create_comment()", function()
		it("sends mutation with issue ID and body", function()
			local api = require("linear.api")
			api.setup("lin_api_test_key")

			local mutation_called = false
			local captured_input = nil

			local original_query = api.query
			api.query = function(query_str, variables, _callback)
				mutation_called = true
				captured_input = variables.input
				assert.matches("commentCreate", query_str)
			end

			api.create_comment("issue-123", "This is a comment", function() end)

			assert.is_true(mutation_called)
			assert.equal("issue-123", captured_input.issueId)
			assert.equal("This is a comment", captured_input.body)

			api.query = original_query
		end)
	end)

	describe("get_teams()", function()
		it("queries for all teams", function()
			local api = require("linear.api")
			api.setup("lin_api_test_key")

			local query_called = false

			local original_query = api.query
			api.query = function(query_str, _variables, _callback)
				query_called = true
				assert.matches("teams", query_str)
			end

			api.get_teams(function() end)

			assert.is_true(query_called)

			api.query = original_query
		end)
	end)

	describe("get_states()", function()
		it("queries for workflow states", function()
			local api = require("linear.api")
			api.setup("lin_api_test_key")

			local query_called = false

			local original_query = api.query
			api.query = function(query_str, _variables, _callback)
				query_called = true
				assert.matches("workflowStates", query_str)
			end

			api.get_states(function() end)

			assert.is_true(query_called)

			api.query = original_query
		end)
	end)

	describe("get_projects()", function()
		it("queries for projects/boards", function()
			local api = require("linear.api")
			api.setup("lin_api_test_key")

			local query_called = false

			local original_query = api.query
			api.query = function(query_str, _variables, _callback)
				query_called = true
				assert.matches("projects", query_str)
			end

			api.get_projects(function() end)

			assert.is_true(query_called)

			api.query = original_query
		end)
	end)

	describe("get_issues_filtered()", function()
		it("queries with filter and limit", function()
			local api = require("linear.api")
			api.setup("lin_api_test_key")

			local captured_vars = nil

			local original_query = api.query
			api.query = function(_query_str, variables, _callback)
				captured_vars = variables
			end

			local filter = { team = { id = { eq = "team-1" } } }
			api.get_issues_filtered(filter, nil, 25, function() end)

			assert.is_not_nil(captured_vars)
			assert.equal(25, captured_vars.first)
			assert.is_not_nil(captured_vars.filter.team)

			api.query = original_query
		end)

		it("defaults to 50 limit", function()
			local api = require("linear.api")
			api.setup("lin_api_test_key")

			local captured_vars = nil

			local original_query = api.query
			api.query = function(_query_str, variables, _callback)
				captured_vars = variables
			end

			api.get_issues_filtered({}, nil, nil, function() end)

			assert.equal(50, captured_vars.first)

			api.query = original_query
		end)
	end)

	describe("get_issue_full()", function()
		it("queries for full issue details with comments", function()
			local api = require("linear.api")
			api.setup("lin_api_test_key")

			local query_called = false
			local captured_id = nil

			local original_query = api.query
			api.query = function(query_str, variables, _callback)
				query_called = true
				captured_id = variables.id
				assert.matches("comments", query_str)
			end

			api.get_issue_full("issue-456", function() end)

			assert.is_true(query_called)
			assert.equal("issue-456", captured_id)

			api.query = original_query
		end)
	end)

	describe("search_issues()", function()
		it("searches by issue number when query contains number", function()
			local api = require("linear.api")
			api.setup("lin_api_test_key")

			local captured_filter = nil

			local original_query = api.query
			api.query = function(_query_str, variables, callback)
				captured_filter = variables.filter
				-- Simulate response
				callback({ issues = { nodes = {} } }, nil)
			end

			api.search_issues("PROJ-1234", 10, function() end)

			assert.is_not_nil(captured_filter)
			assert.is_not_nil(captured_filter["or"])

			api.query = original_query
		end)

		it("searches by title when query is text only", function()
			local api = require("linear.api")
			api.setup("lin_api_test_key")

			local captured_filter = nil

			local original_query = api.query
			api.query = function(_query_str, variables, callback)
				captured_filter = variables.filter
				callback({ issues = { nodes = {} } }, nil)
			end

			api.search_issues("bug fix", 10, function() end)

			assert.is_not_nil(captured_filter)
			assert.is_not_nil(captured_filter["or"])

			api.query = original_query
		end)

		it("wraps response with issueSearch key for compatibility", function()
			local api = require("linear.api")
			api.setup("lin_api_test_key")

			local callback_data = nil

			local original_query = api.query
			api.query = function(_query_str, _variables, callback)
				callback({
					issues = {
						nodes = { { id = "1", identifier = "PROJ-1" } },
					},
				}, nil)
			end

			api.search_issues("test", 10, function(data, _err)
				callback_data = data
			end)

			assert.is_not_nil(callback_data)
			assert.is_not_nil(callback_data.issueSearch)
			assert.equal(1, #callback_data.issueSearch.nodes)

			api.query = original_query
		end)

		it("defaults to 50 limit", function()
			local api = require("linear.api")
			api.setup("lin_api_test_key")

			local captured_vars = nil

			local original_query = api.query
			api.query = function(_query_str, variables, callback)
				captured_vars = variables
				callback({ issues = { nodes = {} } }, nil)
			end

			api.search_issues("test", nil, function() end)

			assert.equal(50, captured_vars.first)

			api.query = original_query
		end)
	end)

	describe("update_issue()", function()
		it("sends mutation with issue ID and updates", function()
			local api = require("linear.api")
			api.setup("lin_api_test_key")

			local mutation_called = false
			local captured_vars = nil

			local original_query = api.query
			api.query = function(query_str, variables, _callback)
				mutation_called = true
				captured_vars = variables
				assert.matches("issueUpdate", query_str)
			end

			local updates = { stateId = "state-2", priority = 1 }
			api.update_issue("issue-123", updates, function() end)

			assert.is_true(mutation_called)
			assert.equal("issue-123", captured_vars.id)
			assert.equal("state-2", captured_vars.input.stateId)
			assert.equal(1, captured_vars.input.priority)

			api.query = original_query
		end)
	end)

	describe("get_active_cycle()", function()
		it("queries for team's active cycle with issues", function()
			local api = require("linear.api")
			api.setup("lin_api_test_key")

			local query_called = false
			local captured_team_id = nil

			local original_query = api.query
			api.query = function(query_str, variables, _callback)
				query_called = true
				captured_team_id = variables.teamId
				assert.matches("activeCycle", query_str)
				assert.matches("issues", query_str)
			end

			api.get_active_cycle("team-abc", function() end)

			assert.is_true(query_called)
			assert.equal("team-abc", captured_team_id)

			api.query = original_query
		end)
	end)
end)
