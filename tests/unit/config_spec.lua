---@type any
local config = require("linear.config")

describe("linear.config", function()
	before_each(function()
		-- Reset to defaults before each test
		package.loaded["linear.config"] = nil
		config = require("linear.config")
	end)

	describe("setup()", function()
		it("merges user options with defaults", function()
			---@type linear.Config
			local opts = {
				api_key = "test-key",
			}

			local result = config.setup(opts)
			assert.is_not_nil(result.api_key)
			assert.equal(result.api_key, "test-key")
		end)

		it("preserves default values for unspecified options", function()
			config.setup({})
			local result = config.get()
			assert.is_not_nil(result.default_filters)
			assert.is_not_nil(result.ui)
			assert.is_not_nil(result.keymaps)
		end)

		it("allows partial configuration updates", function()
			config.setup({
				keymaps = {
					list_issues = "<leader>ln",
				},
			})
			local result = config.get()
			assert.equal(result.keymaps.list_issues, "<leader>ln")
			-- Other keymaps should still exist
			assert.is_not_nil(result.keymaps.create_issue)
		end)
	end)

	describe("get()", function()
		it("returns current configuration", function()
			local result = config.get()
			assert.is_not_nil(result)
			assert.is_table(result)
		end)

		it("has all required top-level keys", function()
			local result = config.get()
			assert.is_not_nil(result.default_filters)
			assert.is_not_nil(result.ui)
			assert.is_not_nil(result.keymaps)
		end)

		it("has correct default keymaps", function()
			local result = config.get()
			assert.equal(result.keymaps.list_issues, "<leader>li")
			assert.equal(result.keymaps.create_issue, "<leader>lc")
		end)

		it("has correct default filter states", function()
			local result = config.get()
			assert.is_table(result.default_filters.states)
			assert.is_true(vim.tbl_contains(result.default_filters.states, "in_progress"))
			assert.is_true(vim.tbl_contains(result.default_filters.states, "todo"))
		end)
	end)

	describe("get_api_key()", function()
		it("returns API key from environment variable", function()
			-- This test relies on LINEAR_API_KEY being set
			local api_key = config.get_api_key()
			if os.getenv("LINEAR_API_KEY") then
				assert.is_not_nil(api_key)
				assert.matches("^lin_api_", api_key)
			end
		end)

		it("returns configured API key", function()
			config.setup({
				api_key = "lin_api_test_key",
			})
			local api_key = config.get_api_key()
			assert.equal(api_key, "lin_api_test_key")
		end)

		it("handles missing API key gracefully", function()
			-- When no API key is configured or in environment,
			-- get_api_key should return nil and show a notification
			local unconfigured_config = require("linear.config")
			unconfigured_config.setup({})
			-- This will return nil if LINEAR_API_KEY is not set
			local api_key = unconfigured_config.get_api_key()
			-- Either we get a key (if env var is set) or nil
			if os.getenv("LINEAR_API_KEY") == nil then
				assert.is_nil(api_key)
			end
		end)
	end)

	describe("default_filters", function()
		it("has assignee set to me", function()
			local result = config.get()
			assert.equal(result.default_filters.assignee, "me")
		end)

		it("has states list with in_progress and todo", function()
			local result = config.get()
			local states = result.default_filters.states
			assert.equal(#states, 2)
			assert.equal(states[1], "in_progress")
			assert.equal(states[2], "todo")
		end)
	end)

	describe("ui configuration", function()
		it("has telescope configuration", function()
			local result = config.get()
			assert.is_not_nil(result.ui.telescope)
			assert.equal(result.ui.telescope.theme, "dropdown")
			assert.is_true(result.ui.telescope.previewer)
		end)

		it("has details configuration", function()
			local result = config.get()
			assert.is_not_nil(result.ui.details)
			assert.equal(result.ui.details.window_type, "float")
			assert.equal(result.ui.details.width, 0.8)
			assert.equal(result.ui.details.height, 0.8)
		end)
	end)
end)
