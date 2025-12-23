---@diagnostic disable: missing-fields, duplicate-set-field, need-check-nil
local statusline

-- Mock modules
local mock_context
local mock_api
local mock_utils
local mock_config
local api_callback

describe("linear.statusline", function()
	before_each(function()
		-- Reset modules
		package.loaded["linear.statusline"] = nil
		package.loaded["linear.context"] = nil
		package.loaded["linear.api"] = nil
		package.loaded["linear.utils"] = nil
		package.loaded["linear.config"] = nil

		api_callback = nil

		-- Mock context module
		mock_context = {
			resolve = function()
				return nil
			end,
		}
		package.loaded["linear.context"] = mock_context

		-- Mock api module
		mock_api = {
			search_issues = function(_query, _limit, callback)
				api_callback = callback
			end,
		}
		package.loaded["linear.api"] = mock_api

		-- Mock utils module
		mock_utils = {
			status_icon = function(state)
				local icons = {
					["In Progress"] = "🟡",
					["Done"] = "🟢",
					["Todo"] = "⚪",
				}
				return icons[state] or "⚪"
			end,
		}
		package.loaded["linear.utils"] = mock_utils

		-- Mock config module (default: no title)
		mock_config = {
			get = function()
				return {
					ui = {
						statusline = {
							show_title = false,
							title_max_length = 30,
						},
					},
				}
			end,
		}
		package.loaded["linear.config"] = mock_config

		statusline = require("linear.statusline")
	end)

	describe("get()", function()
		it("returns empty string when no context resolved", function()
			mock_context.resolve = function()
				return nil
			end

			assert.equal("", statusline.get())
		end)

		it("returns identifier immediately on first call", function()
			mock_context.resolve = function()
				return "PROJ-1234"
			end

			local result = statusline.get()
			assert.equal("PROJ-1234", result)
		end)

		it("returns cached display on subsequent calls with same identifier", function()
			mock_context.resolve = function()
				return "PROJ-1234"
			end

			-- First call
			statusline.get()

			-- Simulate API response
			if api_callback then
				api_callback({
					issueSearch = {
						nodes = {
							{ identifier = "PROJ-1234", state = { name = "In Progress" } },
						},
					},
				}, nil)
			end

			-- Second call should return cached display
			local result = statusline.get()
			assert.equal("🟡 PROJ-1234", result)
		end)

		it("updates display after successful API fetch", function()
			mock_context.resolve = function()
				return "PROJ-1234"
			end

			-- First call returns just identifier
			local first = statusline.get()
			assert.equal("PROJ-1234", first)

			-- Simulate API response
			if api_callback then
				api_callback({
					issueSearch = {
						nodes = {
							{ identifier = "PROJ-1234", state = { name = "Done" } },
						},
					},
				}, nil)
			end

			-- Now should return with icon
			local second = statusline.get()
			assert.equal("🟢 PROJ-1234", second)
		end)

		it("clears cache when identifier changes", function()
			-- Start with PROJ-1234
			mock_context.resolve = function()
				return "PROJ-1234"
			end
			statusline.get()

			-- Simulate API response for first issue
			if api_callback then
				api_callback({
					issueSearch = {
						nodes = {
							{ identifier = "PROJ-1234", state = { name = "In Progress" } },
						},
					},
				}, nil)
			end

			-- Change to different identifier
			mock_context.resolve = function()
				return "PROJ-999"
			end

			local result = statusline.get()
			-- Should return new identifier (cache was invalidated)
			assert.equal("PROJ-999", result)
		end)

		it("handles API errors gracefully", function()
			mock_context.resolve = function()
				return "PROJ-1234"
			end

			statusline.get()

			-- Simulate API error
			if api_callback then
				api_callback(nil, "Network error")
			end

			-- Should still return identifier without icon
			local result = statusline.get()
			assert.equal("PROJ-1234", result)
		end)

		it("handles empty API response gracefully", function()
			mock_context.resolve = function()
				return "PROJ-1234"
			end

			statusline.get()

			-- Simulate empty response
			if api_callback then
				api_callback({ issueSearch = { nodes = {} } }, nil)
			end

			-- Should still return identifier without icon
			local result = statusline.get()
			assert.equal("PROJ-1234", result)
		end)

		it("handles no exact match in API response", function()
			mock_context.resolve = function()
				return "PROJ-1234"
			end

			statusline.get()

			-- Simulate response with different identifier
			if api_callback then
				api_callback({
					issueSearch = {
						nodes = {
							{ identifier = "PROJ-1235", state = { name = "Done" } },
						},
					},
				}, nil)
			end

			-- Should still return identifier without icon
			local result = statusline.get()
			assert.equal("PROJ-1234", result)
		end)

		it("clears cache when context becomes nil", function()
			-- Start with an issue
			mock_context.resolve = function()
				return "PROJ-1234"
			end
			statusline.get()

			-- Simulate API response
			if api_callback then
				api_callback({
					issueSearch = {
						nodes = {
							{ identifier = "PROJ-1234", state = { name = "In Progress" } },
						},
					},
				}, nil)
			end

			-- Context becomes nil (switched to main branch)
			mock_context.resolve = function()
				return nil
			end

			local result = statusline.get()
			assert.equal("", result)
		end)
	end)

	describe("clear_cache()", function()
		it("clears all cached values", function()
			mock_context.resolve = function()
				return "PROJ-1234"
			end

			-- Populate cache
			statusline.get()
			if api_callback then
				api_callback({
					issueSearch = {
						nodes = {
							{ identifier = "PROJ-1234", state = { name = "In Progress" } },
						},
					},
				}, nil)
			end

			-- Verify cache is populated
			assert.equal("🟡 PROJ-1234", statusline.get())

			-- Clear cache
			statusline.clear_cache()

			-- Next call should return just identifier (cache cleared)
			local result = statusline.get()
			assert.equal("PROJ-1234", result)
		end)
	end)

	describe("title display", function()
		it("shows title when show_title is enabled", function()
			mock_config.get = function()
				return {
					ui = {
						statusline = {
							show_title = true,
							title_max_length = 30,
						},
					},
				}
			end

			mock_context.resolve = function()
				return "PROJ-1234"
			end

			statusline.get()

			if api_callback then
				api_callback({
					issueSearch = {
						nodes = {
							{
								identifier = "PROJ-1234",
								state = { name = "In Progress" },
								title = "Fix login bug",
							},
						},
					},
				}, nil)
			end

			local result = statusline.get()
			assert.equal("🟡 PROJ-1234 - Fix login bug", result)
		end)

		it("truncates long titles", function()
			mock_config.get = function()
				return {
					ui = {
						statusline = {
							show_title = true,
							title_max_length = 10,
						},
					},
				}
			end

			mock_context.resolve = function()
				return "PROJ-1234"
			end

			statusline.get()

			if api_callback then
				api_callback({
					issueSearch = {
						nodes = {
							{
								identifier = "PROJ-1234",
								state = { name = "Done" },
								title = "This is a very long title that should be truncated",
							},
						},
					},
				}, nil)
			end

			local result = statusline.get()
			assert.equal("🟢 PROJ-1234 - This is a…", result)
		end)

		it("does not show title when show_title is false", function()
			mock_config.get = function()
				return {
					ui = {
						statusline = {
							show_title = false,
							title_max_length = 30,
						},
					},
				}
			end

			mock_context.resolve = function()
				return "PROJ-1234"
			end

			statusline.get()

			if api_callback then
				api_callback({
					issueSearch = {
						nodes = {
							{
								identifier = "PROJ-1234",
								state = { name = "In Progress" },
								title = "Fix login bug",
							},
						},
					},
				}, nil)
			end

			local result = statusline.get()
			assert.equal("🟡 PROJ-1234", result)
		end)

		it("handles missing title gracefully when show_title is enabled", function()
			mock_config.get = function()
				return {
					ui = {
						statusline = {
							show_title = true,
							title_max_length = 30,
						},
					},
				}
			end

			mock_context.resolve = function()
				return "PROJ-1234"
			end

			statusline.get()

			if api_callback then
				api_callback({
					issueSearch = {
						nodes = {
							{
								identifier = "PROJ-1234",
								state = { name = "In Progress" },
								-- no title
							},
						},
					},
				}, nil)
			end

			local result = statusline.get()
			assert.equal("🟡 PROJ-1234", result)
		end)
	end)
end)
