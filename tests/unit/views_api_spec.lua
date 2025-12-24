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

describe("linear.api views", function()
	before_each(function()
		-- Replace plenary.curl with our mock
		package.loaded["plenary.curl"] = mock_curl
		package.loaded["linear.api"] = nil
	end)

	after_each(function()
		-- Restore plenary.curl
		package.loaded["plenary.curl"] = require("plenary.curl")
	end)

	describe("get_project_views()", function()
		it("queries for custom views associated with a project", function()
			local api = require("linear.api")
			api.setup("lin_api_test_key")

			local query_called = false
			local captured_query = nil
			local captured_vars = nil

			local original_query = api.query
			api.query = function(query_str, variables, _callback)
				query_called = true
				captured_query = query_str
				captured_vars = variables
			end

			api.get_project_views("project-123", function() end)

			assert.is_true(query_called)
			assert.matches("project%(id:", captured_query)
			assert.matches("customViews", captured_query)
			assert.equal("project-123", captured_vars.projectId)

			api.query = original_query
		end)

		it("includes required view fields in query", function()
			local api = require("linear.api")
			api.setup("lin_api_test_key")

			local captured_query = nil

			local original_query = api.query
			api.query = function(query_str, _variables, _callback)
				captured_query = query_str
			end

			api.get_project_views("project-123", function() end)

			-- Check all required fields are present
			assert.matches("id", captured_query)
			assert.matches("name", captured_query)
			assert.matches("description", captured_query)
			assert.matches("icon", captured_query)
			assert.matches("color", captured_query)
			assert.matches("shared", captured_query)
			assert.matches("team", captured_query)

			api.query = original_query
		end)

		it("calls callback with error when project_id is nil", function()
			local api = require("linear.api")
			api.setup("lin_api_test_key")

			local callback_error = nil
			local callback_data = nil

			api.get_project_views(nil, function(data, err)
				callback_data = data
				callback_error = err
			end)

			assert.is_nil(callback_data)
			assert.is_not_nil(callback_error)
			assert.matches("project_id is required", callback_error)
		end)

		it("calls callback with error when project_id is empty string", function()
			local api = require("linear.api")
			api.setup("lin_api_test_key")

			local callback_error = nil
			local callback_data = nil

			api.get_project_views("", function(data, err)
				callback_data = data
				callback_error = err
			end)

			assert.is_nil(callback_data)
			assert.is_not_nil(callback_error)
			assert.matches("project_id is required", callback_error)
		end)
	end)

	describe("get_custom_views()", function()
		it("queries for all custom views", function()
			local api = require("linear.api")
			api.setup("lin_api_test_key")

			local query_called = false
			local captured_query = nil

			local original_query = api.query
			api.query = function(query_str, _variables, _callback)
				query_called = true
				captured_query = query_str
			end

			api.get_custom_views(function() end)

			assert.is_true(query_called)
			assert.matches("customViews", captured_query)

			api.query = original_query
		end)

		it("includes required view fields in query", function()
			local api = require("linear.api")
			api.setup("lin_api_test_key")

			local captured_query = nil

			local original_query = api.query
			api.query = function(query_str, _variables, _callback)
				captured_query = query_str
			end

			api.get_custom_views(function() end)

			-- Check all required fields are present
			assert.matches("id", captured_query)
			assert.matches("name", captured_query)
			assert.matches("description", captured_query)
			assert.matches("icon", captured_query)
			assert.matches("color", captured_query)
			assert.matches("shared", captured_query)
			assert.matches("team", captured_query)

			api.query = original_query
		end)

		it("passes empty variables to query", function()
			local api = require("linear.api")
			api.setup("lin_api_test_key")

			local captured_vars = nil

			local original_query = api.query
			api.query = function(_query_str, variables, _callback)
				captured_vars = variables
			end

			api.get_custom_views(function() end)

			assert.is_table(captured_vars)
			assert.is_nil(next(captured_vars)) -- empty table

			api.query = original_query
		end)
	end)

	describe("get_view_issues()", function()
		it("queries for issues in a custom view", function()
			local api = require("linear.api")
			api.setup("lin_api_test_key")

			local query_called = false
			local captured_query = nil
			local captured_vars = nil

			local original_query = api.query
			api.query = function(query_str, variables, _callback)
				query_called = true
				captured_query = query_str
				captured_vars = variables
			end

			api.get_view_issues("view-456", function() end)

			assert.is_true(query_called)
			assert.matches("customView%(id:", captured_query)
			assert.matches("issues", captured_query)
			assert.equal("view-456", captured_vars.viewId)

			api.query = original_query
		end)

		it("includes full issue fields matching get_issues_filtered", function()
			local api = require("linear.api")
			api.setup("lin_api_test_key")

			local captured_query = nil

			local original_query = api.query
			api.query = function(query_str, _variables, _callback)
				captured_query = query_str
			end

			api.get_view_issues("view-456", function() end)

			-- Check issue fields are present
			assert.matches("identifier", captured_query)
			assert.matches("title", captured_query)
			assert.matches("description", captured_query)
			assert.matches("state", captured_query)
			assert.matches("priority", captured_query)
			assert.matches("assignee", captured_query)
			assert.matches("project", captured_query)
			assert.matches("team", captured_query)
			assert.matches("attachments", captured_query)
			assert.matches("createdAt", captured_query)
			assert.matches("updatedAt", captured_query)
			assert.matches("url", captured_query)
			assert.matches("pageInfo", captured_query)

			api.query = original_query
		end)

		it("calls callback with error when view_id is nil", function()
			local api = require("linear.api")
			api.setup("lin_api_test_key")

			local callback_error = nil
			local callback_data = nil

			api.get_view_issues(nil, function(data, err)
				callback_data = data
				callback_error = err
			end)

			assert.is_nil(callback_data)
			assert.is_not_nil(callback_error)
			assert.matches("view_id is required", callback_error)
		end)

		it("calls callback with error when view_id is empty string", function()
			local api = require("linear.api")
			api.setup("lin_api_test_key")

			local callback_error = nil
			local callback_data = nil

			api.get_view_issues("", function(data, err)
				callback_data = data
				callback_error = err
			end)

			assert.is_nil(callback_data)
			assert.is_not_nil(callback_error)
			assert.matches("view_id is required", callback_error)
		end)
	end)
end)
