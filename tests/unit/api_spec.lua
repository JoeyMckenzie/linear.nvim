---Mock curl module for testing
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
end)
