---@diagnostic disable: missing-fields, inject-field, duplicate-set-field
---@type any
local context

-- Mock handle for io.popen
local mock_handle = {
	output = nil,
	read = function(self, _mode)
		return self.output
	end,
	close = function(_self) end,
}

-- Store original io.popen
local original_popen

describe("linear.context", function()
	before_each(function()
		-- Reset module before each test
		package.loaded["linear.context"] = nil
		context = require("linear.context")

		-- Store and mock io.popen
		original_popen = io.popen
	end)

	after_each(function()
		-- Restore original io.popen
		io.popen = original_popen
	end)

	describe("session context (get/set/clear)", function()
		it("returns nil when no context is set", function()
			assert.is_nil(context.get())
		end)

		it("stores and retrieves identifier", function()
			context.set("SUP-1234")
			assert.equal("SUP-1234", context.get())
		end)

		it("clears context", function()
			context.set("SUP-1234")
			context.clear()
			assert.is_nil(context.get())
		end)

		it("overwrites previous context", function()
			context.set("SUP-1234")
			context.set("RAISE-999")
			assert.equal("RAISE-999", context.get())
		end)
	end)

	describe("detect_from_branch()", function()
		it("extracts identifier from feature/SUP-1234 branch", function()
			io.popen = function(_cmd)
				mock_handle.output = "feature/SUP-1234"
				return mock_handle
			end
			assert.equal("SUP-1234", context.detect_from_branch())
		end)

		it("extracts identifier from SUP-1234-feature branch", function()
			io.popen = function(_cmd)
				mock_handle.output = "SUP-1234-feature"
				return mock_handle
			end
			assert.equal("SUP-1234", context.detect_from_branch())
		end)

		it("extracts identifier from fix/RAISE-999-bug branch", function()
			io.popen = function(_cmd)
				mock_handle.output = "fix/RAISE-999-bug"
				return mock_handle
			end
			assert.equal("RAISE-999", context.detect_from_branch())
		end)

		it("extracts first identifier when multiple present", function()
			io.popen = function(_cmd)
				mock_handle.output = "SUP-1234-related-to-SUP-5678"
				return mock_handle
			end
			assert.equal("SUP-1234", context.detect_from_branch())
		end)

		it("handles single letter team prefix", function()
			io.popen = function(_cmd)
				mock_handle.output = "feature/A-123"
				return mock_handle
			end
			assert.equal("A-123", context.detect_from_branch())
		end)

		it("handles long team prefix", function()
			io.popen = function(_cmd)
				mock_handle.output = "feature/LONGTEAM-9999"
				return mock_handle
			end
			assert.equal("LONGTEAM-9999", context.detect_from_branch())
		end)

		it("returns nil for main branch", function()
			io.popen = function(_cmd)
				mock_handle.output = "main"
				return mock_handle
			end
			assert.is_nil(context.detect_from_branch())
		end)

		it("returns nil for develop branch", function()
			io.popen = function(_cmd)
				mock_handle.output = "develop"
				return mock_handle
			end
			assert.is_nil(context.detect_from_branch())
		end)

		it("returns nil for branch without identifier pattern", function()
			io.popen = function(_cmd)
				mock_handle.output = "feature/add-new-button"
				return mock_handle
			end
			assert.is_nil(context.detect_from_branch())
		end)

		it("returns nil when not in git repo (empty output)", function()
			io.popen = function(_cmd)
				mock_handle.output = ""
				return mock_handle
			end
			assert.is_nil(context.detect_from_branch())
		end)

		it("returns nil when not in git repo (nil output)", function()
			io.popen = function(_cmd)
				mock_handle.output = nil
				return mock_handle
			end
			assert.is_nil(context.detect_from_branch())
		end)

		it("returns nil when popen fails", function()
			io.popen = function(_cmd)
				return nil
			end
			assert.is_nil(context.detect_from_branch())
		end)

		it("ignores lowercase identifiers", function()
			io.popen = function(_cmd)
				mock_handle.output = "feature/sup-1234"
				return mock_handle
			end
			assert.is_nil(context.detect_from_branch())
		end)
	end)

	describe("resolve()", function()
		it("returns session context when set", function()
			context.set("SUP-1234")
			io.popen = function(_cmd)
				mock_handle.output = "feature/RAISE-999"
				return mock_handle
			end
			assert.equal("SUP-1234", context.resolve())
		end)

		it("falls back to branch detection when no session context", function()
			io.popen = function(_cmd)
				mock_handle.output = "feature/RAISE-999"
				return mock_handle
			end
			assert.equal("RAISE-999", context.resolve())
		end)

		it("returns nil when no session context and no branch match", function()
			io.popen = function(_cmd)
				mock_handle.output = "main"
				return mock_handle
			end
			assert.is_nil(context.resolve())
		end)
	end)

	describe("is_git_repo()", function()
		it("returns true when in git repository", function()
			io.popen = function(_cmd)
				mock_handle.output = "true"
				return mock_handle
			end
			assert.is_true(context.is_git_repo())
		end)

		it("returns false when not in git repository", function()
			io.popen = function(_cmd)
				mock_handle.output = "false"
				return mock_handle
			end
			assert.is_false(context.is_git_repo())
		end)

		it("returns false when git command fails (nil output)", function()
			io.popen = function(_cmd)
				mock_handle.output = nil
				return mock_handle
			end
			assert.is_false(context.is_git_repo())
		end)

		it("returns false when popen fails", function()
			io.popen = function(_cmd)
				return nil
			end
			assert.is_false(context.is_git_repo())
		end)
	end)
end)
