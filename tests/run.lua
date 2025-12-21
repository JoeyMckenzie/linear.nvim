-- Set up the test environment
vim.opt.rtp:prepend(".")

-- Lightweight test framework (no dependencies)
local current_describe = nil
local tests_passed = 0
local tests_failed = 0
local test_failures = {}

---@type function[]
local setup_hooks = {}
---@type function[]
local teardown_hooks = {}

---Register a test suite
---@param name string
---@param fn function
function _G.describe(name, fn)
	current_describe = name
	fn()
	current_describe = nil
end

---Register a test case
---@param name string
---@param fn function
function _G.it(name, fn)
	local test_name = (current_describe or "Global") .. " > " .. name
	local success, err = pcall(function()
		for _, hook in ipairs(setup_hooks) do
			hook()
		end
		fn()
		for _, hook in ipairs(teardown_hooks) do
			hook()
		end
	end)

	if success then
		tests_passed = tests_passed + 1
		print("  ✓ " .. name)
	else
		tests_failed = tests_failed + 1
		print("  ✗ " .. name)
		table.insert(test_failures, { test = test_name, error = err })
	end
end

---Register a before_each hook
---@param fn function
function _G.before_each(fn)
	table.insert(setup_hooks, fn)
end

---Register an after_each hook
---@param fn function
function _G.after_each(fn)
	table.insert(teardown_hooks, fn)
end

-- Stub before_all and after_all
function _G.before_all(fn) end
function _G.after_all(fn) end

-- Simple assertion object
local assert = {}

function assert.equal(a, b)
	if a ~= b then
		error(("assertion failed: %s ~= %s"):format(tostring(a), tostring(b)))
	end
end

function assert.equals(a, b)
	assert.equal(a, b)
end

function assert.not_equal(a, b)
	if a == b then
		error(("assertion failed: %s == %s"):format(tostring(a), tostring(b)))
	end
end

function assert.is_nil(v)
	if v ~= nil then
		error(("assertion failed: expected nil, got %s"):format(type(v)))
	end
end

function assert.is_not_nil(v)
	if v == nil then
		error("assertion failed: expected non-nil value")
	end
end

function assert.is_true(v)
	if v ~= true then
		error(("assertion failed: expected true, got %s"):format(tostring(v)))
	end
end

function assert.is_false(v)
	if v ~= false then
		error(("assertion failed: expected false, got %s"):format(tostring(v)))
	end
end

function assert.is_table(v)
	if type(v) ~= "table" then
		error(("assertion failed: expected table, got %s"):format(type(v)))
	end
end

function assert.is_string(v)
	if type(v) ~= "string" then
		error(("assertion failed: expected string, got %s"):format(type(v)))
	end
end

function assert.is_number(v)
	if type(v) ~= "number" then
		error(("assertion failed: expected number, got %s"):format(type(v)))
	end
end

function assert.matches(pattern, str)
	if not tostring(str):match(pattern) then
		error(("assertion failed: '%s' does not match pattern '%s'"):format(str, pattern))
	end
end

function assert.contains(tbl, val)
	for _, v in ipairs(tbl) do
		if v == val then
			return
		end
	end
	error(("assertion failed: value %s not found in table"):format(tostring(val)))
end

function assert.has_errors(fn)
	local ok = pcall(fn)
	if ok then
		error("assertion failed: expected function to error but it succeeded")
	end
end

function assert.has_no_errors(fn)
	local ok, err = pcall(fn)
	if not ok then
		error(("assertion failed: expected no errors but got: %s"):format(err))
	end
end

-- Custom matchers
function assert.has() end
assert.has.errors = function(fn)
	assert.has_errors(fn)
end

function assert.has_no() end
assert.has_no.errors = function(fn)
	assert.has_no_errors(fn)
end

_G.assert = assert

print("\n========== Linear.nvim Test Suite ==========\n")

-- Load test files manually
local test_files = {
	"tests/unit/config_spec.lua",
	"tests/unit/utils_spec.lua",
	"tests/unit/api_spec.lua",
}

print("Found " .. #test_files .. " test file(s):")
for _, file in ipairs(test_files) do
	print("  • " .. file)
end
print("")

-- Load each test file
for _, file in ipairs(test_files) do
	print("\n" .. file .. ":")
	dofile(file)
end

print("\n========== Test Results ==========")
print("Passed: " .. tests_passed)
print("Failed: " .. tests_failed)
print("Total:  " .. (tests_passed + tests_failed))
print("")

if tests_failed > 0 then
	print("Failures:")
	for _, failure in ipairs(test_failures) do
		print("  - " .. failure.test .. ": " .. failure.error)
	end
	print("")
	os.exit(1)
else
	print("All tests passed!")
	os.exit(0)
end
