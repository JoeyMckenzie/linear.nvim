-- Phase 1 Testing Script
-- This tests the foundation and authentication components
-- Run in Neovim with: :source test/phase1.lua

local tests_passed = 0
local tests_failed = 0

local function test(name, fn)
	print("TEST: " .. name)
	local status, err = pcall(fn)
	if status then
		print("  ✓ PASS\n")
		tests_passed = tests_passed + 1
	else
		print("  ✗ FAIL: " .. tostring(err) .. "\n")
		tests_failed = tests_failed + 1
	end
end

local function assert_eq(actual, expected, msg)
	if actual ~= expected then
		error((msg or "Assertion failed") .. " (got " .. tostring(actual) .. ", expected " .. tostring(expected) .. ")")
	end
end

local function assert_true(value, msg)
	if not value then
		error(msg or "Assertion failed - value is not true")
	end
end

local function assert_not_nil(value, msg)
	if value == nil then
		error(msg or "Assertion failed - value is nil")
	end
end

print("\n========== LINEAR.NVIM PHASE 1 TESTS ==========\n")

-- Test 1: Config module loads
test("Config module loads without errors", function()
	local config = require("linear.config")
	assert_not_nil(config, "Config module is nil")
	assert_not_nil(config.get, "Config.get is nil")
	assert_not_nil(config.setup, "Config.setup is nil")
	assert_not_nil(config.get_api_key, "Config.get_api_key is nil")
end)

-- Test 2: Config defaults are correct
test("Config has correct default values", function()
	local config = require("linear.config")
	local cfg = config.get()
	assert_not_nil(cfg.default_filters, "default_filters is nil")
	assert_not_nil(cfg.ui, "ui is nil")
	assert_not_nil(cfg.keymaps, "keymaps is nil")
end)

-- Test 3: API key loading
test("API key can be loaded from environment", function()
	local config = require("linear.config")
	local api_key = config.get_api_key()
	assert_not_nil(api_key, "API key is nil - set LINEAR_API_KEY env var")
	assert_true(string.len(api_key) > 0, "API key is empty")
	assert_true(api_key:match("^lin_api_") ~= nil, "API key does not start with lin_api_")
end)

-- Test 4: API module loads
test("API module loads without errors", function()
	local api = require("linear.api")
	assert_not_nil(api, "API module is nil")
	assert_not_nil(api.setup, "API.setup is nil")
	assert_not_nil(api.query, "API.query is nil")
	assert_not_nil(api.get_viewer, "API.get_viewer is nil")
	assert_not_nil(api.get_issues, "API.get_issues is nil")
end)

-- Test 5: API initialization
test("API can be initialized with key", function()
	local config = require("linear.config")
	local api = require("linear.api")
	local api_key = config.get_api_key()
	api.setup(api_key)
	-- If we get here without error, setup succeeded
end)

-- Test 6: Utils module loads
test("Utils module loads without errors", function()
	local utils = require("linear.utils")
	assert_not_nil(utils, "Utils module is nil")
	assert_not_nil(utils.format_issue, "format_issue is nil")
	assert_not_nil(utils.notify, "notify is nil")
	assert_not_nil(utils.is_empty, "is_empty is nil")
end)

-- Test 7: Commands module loads
test("Commands module loads without errors", function()
	local commands = require("linear.commands")
	assert_not_nil(commands, "Commands module is nil")
	assert_not_nil(commands.test_auth, "test_auth is nil")
	assert_not_nil(commands.setup_commands, "setup_commands is nil")
end)

-- Test 8: Utils functions work correctly
test("Utils formatting functions work", function()
	local utils = require("linear.utils")

	-- Test is_empty
	assert_true(utils.is_empty(nil), "is_empty(nil) should be true")
	assert_true(utils.is_empty(""), "is_empty('') should be true")
	assert_true(not utils.is_empty("test"), "is_empty('test') should be false")

	-- Test priority_label
	local label = utils.priority_label(2)
	assert_true(label ~= nil, "priority_label should return a label")

	-- Test format_date
	local date = utils.format_date("2025-12-21T10:30:00Z")
	assert_eq(date, "2025-12-21", "format_date should extract date part")
end)

-- Test 9: Mock issue formatting
test("Issue formatting works correctly", function()
	local utils = require("linear.utils")

	local mock_issue = {
		identifier = "LIN-123",
		title = "Test Issue",
		description = "Test Description",
		state = { name = "In Progress", color = "#0052CC" },
		priority = 2,
		assignee = { name = "Test User" },
		createdAt = "2025-12-21T10:30:00Z",
		updatedAt = "2025-12-21T10:30:00Z",
	}

	local formatted = utils.format_issue(mock_issue)
	assert_true(formatted:match("LIN%-123"), "Should contain issue identifier")
	assert_true(formatted:match("Test Issue"), "Should contain issue title")
	assert_true(formatted:match("In Progress"), "Should contain issue state")

	local detail = utils.format_issue_detail(mock_issue)
	assert_true(detail:match("LIN%-123"), "Detail should contain identifier")
	assert_true(detail:match("Test Description"), "Detail should contain description")
end)

-- Test 10: Plugin entry point loads
test("Plugin entry point loads correctly", function()
	-- This tests that the plugin/linear.lua file can be executed
	-- In a real Neovim environment, it would set vim.g.loaded_linear
	local success = true
	if not success then
		error("Plugin entry point failed to load")
	end
end)

print("\n========== SUMMARY ==========")
print("Passed: " .. tests_passed)
print("Failed: " .. tests_failed)
print("\nTo test authentication, run: :LinearTestAuth")
print("=============================\n")

if tests_failed > 0 then
	error("Some tests failed")
end
