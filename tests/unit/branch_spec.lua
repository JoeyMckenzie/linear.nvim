---@diagnostic disable: missing-fields, duplicate-set-field, need-check-nil
local branch

-- Mock modules
local mock_config
local mock_context
local mock_utils

describe("linear.branch", function()
	before_each(function()
		-- Reset modules
		package.loaded["linear.branch"] = nil
		package.loaded["linear.config"] = nil
		package.loaded["linear.context"] = nil
		package.loaded["linear.utils"] = nil
		package.loaded["linear.api"] = nil
		package.loaded["linear.statusline"] = nil

		-- Mock config
		mock_config = {
			get = function()
				return {
					branch = {
						scopes = { "feature", "bugfix", "task", "chore" },
						lowercase_identifier = false,
					},
				}
			end,
		}
		package.loaded["linear.config"] = mock_config

		-- Mock context
		mock_context = {
			set = function() end,
			resolve = function()
				return nil
			end,
		}
		package.loaded["linear.context"] = mock_context

		-- Mock utils
		mock_utils = {
			notify = function() end,
		}
		package.loaded["linear.utils"] = mock_utils

		-- Mock statusline
		package.loaded["linear.statusline"] = {
			clear_cache = function() end,
		}

		branch = require("linear.branch")
	end)

	describe("slugify()", function()
		it("converts to lowercase", function()
			assert.equal("hello-world", branch.slugify("Hello World"))
		end)

		it("replaces spaces with hyphens", function()
			assert.equal("fix-the-bug", branch.slugify("fix the bug"))
		end)

		it("removes special characters", function()
			assert.equal("fix-login-bug", branch.slugify("Fix login bug!!!"))
		end)

		it("collapses multiple hyphens", function()
			assert.equal("fix-bug", branch.slugify("fix---bug"))
		end)

		it("trims leading hyphens", function()
			assert.equal("fix-bug", branch.slugify("---fix bug"))
		end)

		it("trims trailing hyphens", function()
			assert.equal("fix-bug", branch.slugify("fix bug---"))
		end)

		it("handles empty string", function()
			assert.equal("", branch.slugify(""))
		end)

		it("handles nil", function()
			assert.equal("", branch.slugify(nil))
		end)

		it("truncates long strings to 50 chars", function()
			local long_title = "this is a very long title that should be truncated because it exceeds fifty characters"
			local result = branch.slugify(long_title)
			assert.is_true(#result <= 50)
		end)

		it("removes trailing hyphen after truncation", function()
			local long_title = "this is a very long title that should be truncated"
			local result = branch.slugify(long_title)
			assert.is_not_equal("-", result:sub(-1))
		end)

		it("handles mixed special characters", function()
			assert.equal("fix-bug-in-login-form", branch.slugify("Fix: bug in login form!?"))
		end)

		it("preserves numbers", function()
			assert.equal("fix-bug-123", branch.slugify("Fix bug 123"))
		end)
	end)

	describe("generate_branch_name()", function()
		it("generates branch with scope and identifier", function()
			local issue = { identifier = "PROJ-123", title = "Fix login bug" }
			local result = branch.generate_branch_name(issue, "feature", false)
			assert.equal("feature/PROJ-123", result)
		end)

		it("includes slugified title when requested", function()
			local issue = { identifier = "PROJ-123", title = "Fix login bug" }
			local result = branch.generate_branch_name(issue, "feature", true)
			assert.equal("feature/PROJ-123-fix-login-bug", result)
		end)

		it("uses different scopes", function()
			local issue = { identifier = "PROJ-456", title = "Fix crash" }
			assert.equal("bugfix/PROJ-456", branch.generate_branch_name(issue, "bugfix", false))
			assert.equal("task/PROJ-456", branch.generate_branch_name(issue, "task", false))
			assert.equal("chore/PROJ-456", branch.generate_branch_name(issue, "chore", false))
		end)

		it("lowercases identifier when configured", function()
			mock_config.get = function()
				return {
					branch = {
						scopes = { "feature" },
						lowercase_identifier = true,
					},
				}
			end

			local issue = { identifier = "PROJ-123", title = "Fix bug" }
			local result = branch.generate_branch_name(issue, "feature", false)
			assert.equal("feature/proj-123", result)
		end)

		it("handles issue without title gracefully", function()
			local issue = { identifier = "PROJ-123" }
			local result = branch.generate_branch_name(issue, "feature", true)
			assert.equal("feature/PROJ-123", result)
		end)

		it("handles empty title", function()
			local issue = { identifier = "PROJ-123", title = "" }
			local result = branch.generate_branch_name(issue, "feature", true)
			assert.equal("feature/PROJ-123", result)
		end)
	end)

	describe("config defaults", function()
		it("has default scopes", function()
			package.loaded["linear.config"] = nil
			local real_config = require("linear.config")

			local cfg = real_config.get()
			assert.is_table(cfg.branch.scopes)
			assert.equal(4, #cfg.branch.scopes)
			assert.is_true(vim.tbl_contains(cfg.branch.scopes, "feature"))
			assert.is_true(vim.tbl_contains(cfg.branch.scopes, "bugfix"))
		end)

		it("defaults lowercase_identifier to false", function()
			package.loaded["linear.config"] = nil
			local real_config = require("linear.config")

			local cfg = real_config.get()
			assert.is_false(cfg.branch.lowercase_identifier)
		end)
	end)
end)
