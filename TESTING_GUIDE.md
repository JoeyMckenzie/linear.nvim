# Linear.nvim Testing Guide

This guide explains how to write and run unit and integration tests for linear.nvim using Plenary's test framework.

## Quick Start

### Run All Tests

```bash
# From the project directory
make test

# Or directly with Neovim
nvim --headless -u NONE -c "luafile tests/run.lua"
```

### Run Tests in Watch Mode

```bash
make test-watch
```

The tests will re-run automatically whenever you save a file in `lua/` or `tests/`.

### Run Specific Tests

```bash
# Run only unit tests
make test-unit

# Run a specific test file
nvim --headless -u NONE -c "luafile tests/run.lua tests/unit/config_spec.lua"
```

## Test Structure

Tests use Plenary's Busted test framework. Each test file follows this pattern:

```lua
describe("module name", function()
  before_each(function()
    -- Setup before each test
  end)

  after_each(function()
    -- Cleanup after each test
  end)

  describe("function name", function()
    it("should do something", function()
      -- Test assertions
      assert.equals(1, 1)
    end)
  end)
end)
```

## Writing Tests

### 1. Unit Tests - Config Module

File: `tests/unit/config_spec.lua`

Tests the configuration system:

```lua
describe("linear.config", function()
  it("loads default configuration", function()
    local config = require("linear.config")
    local cfg = config.get()
    assert.is_not_nil(cfg.keymaps)
  end)

  it("merges user options", function()
    local config = require("linear.config")
    local result = config.setup({ api_key = "test-key" })
    assert.equal(result.api_key, "test-key")
  end)
end)
```

### 2. Unit Tests - Utils Module

File: `tests/unit/utils_spec.lua`

Tests utility functions with mock data:

```lua
describe("linear.utils", function()
  local mock_issue = {
    identifier = "LIN-123",
    title = "Test",
    -- ... other fields
  }

  it("formats issues correctly", function()
    local utils = require("linear.utils")
    local result = utils.format_issue(mock_issue)
    assert.matches("LIN%-123", result)
  end)
end)
```

### 3. Unit Tests - API Module

File: `tests/unit/api_spec.lua`

Tests API functions with mocked HTTP responses:

```lua
describe("linear.api", function()
  before_each(function()
    -- Mock curl before loading api module
    package.loaded["plenary.curl"] = mock_curl
    package.loaded["linear.api"] = nil
  end)

  it("sends GraphQL queries", function()
    local api = require("linear.api")
    api.setup("test-key")

    local callback_called = false
    api.query("query { test }", {}, function()
      callback_called = true
    end)

    assert.is_true(callback_called)
  end)
end)
```

## Common Assertions

Plenary provides many useful assertions:

```lua
-- Equality checks
assert.equal(a, b)
assert.equals(a, b)
assert.not_equal(a, b)

-- Type checks
assert.is_nil(x)
assert.is_not_nil(x)
assert.is_true(x)
assert.is_false(x)
assert.is_table(x)
assert.is_string(x)
assert.is_number(x)

-- String matching
assert.matches("pattern", "test string")

-- List operations
assert.contains(table, value)

-- Function behavior
assert.has.errors(function() end)
assert.has_no.errors(function() end)
```

## Mocking and Test Doubles

### Mocking External Dependencies

```lua
-- Save original module
local original_module = package.loaded["module"]

-- Replace with mock
package.loaded["module"] = {
  function_name = function(args)
    return mock_result
  end
}

-- Test your code

-- Restore original
package.loaded["module"] = original_module
```

### Mocking Callbacks

```lua
local callback_data = nil
local callback_called = false

local mock_callback = function(data, error)
  callback_called = true
  callback_data = data
end

-- Pass mock callback to function under test
my_function(mock_callback)

-- Assert callback was called correctly
assert.is_true(callback_called)
assert.equals(callback_data.id, "expected-id")
```

### Mocking HTTP Requests

For API testing, mock the curl library:

```lua
local mock_request = {
  _after_fn = nil,
  _catch_fn = nil,
}

function mock_request:after(callback)
  self._after_fn = callback
  return self
end

function mock_request:trigger_after(result)
  if self._after_fn then
    self._after_fn(result)
  end
end

-- In test:
api.query("query", {}, callback)
mock_request:trigger_after({
  status = 200,
  body = vim.json.encode({ data = { ... } })
})
```

## Test Organization

### Describe Blocks

Use nested `describe` blocks to organize tests:

```lua
describe("linear.api", function()
  describe("setup()", function()
    it("initializes with key", function() end)
    it("throws without key", function() end)
  end)

  describe("query()", function()
    it("makes POST request", function() end)
    it("handles errors", function() end)
  end)
end)
```

### Before/After Hooks

Control test setup and teardown:

```lua
before_each(function()
  -- Runs before each test
  mock_api = {}
end)

after_each(function()
  -- Cleanup after each test
  mock_api = nil
end)

before_all(function()
  -- Runs once before all tests in this describe block
end)

after_all(function()
  -- Runs once after all tests
end)
```

## Running Tests Programmatically

### From Neovim Command Line

```vim
:luafile tests/run.lua
```

### From Shell

```bash
# Run all tests (headless)
nvim --headless -u NONE -c "luafile tests/run.lua"

# Run with minimal config
nvim --headless -u tests/minimal_init.lua -c "luafile tests/run.lua"

# Run and exit with status
nvim --headless -u NONE -c "luafile tests/run.lua" -c "qa!"
```

### Using Make

```bash
# See all available commands
make help

# Run tests
make test

# Run in watch mode
make test-watch

# Check code quality
make lint
make type-check
```

## Test Coverage

Currently tested:

- ✓ Config module: loading, merging, API key resolution
- ✓ Utils module: formatting, type conversions, empty checks
- ✓ API module: setup, query execution, error handling
- ✓ Commands module: command registration

### Coverage Goals

- Add integration tests for full workflows
- Add tests for Phase 2 (Telescope integration)
- Add tests for Phase 3 (issue creation/updates)
- Aim for >80% code coverage

## Debugging Tests

### Print Debugging

```lua
it("should work", function()
  local result = my_function()
  print("Result: " .. vim.inspect(result))  -- Inspect complex values
  print("Type: " .. type(result))
end)
```

### Run Single Test

```bash
# Edit a test file and change "describe" to "fdescribe" (focused describe)
# Or change "it" to "fit" (focused it)
fdescribe("module", function()
  it("test", function() end)
end)
```

### Verbose Output

```bash
nvim --headless -u NONE -c "luafile tests/run.lua" -v
```

## Best Practices

1. **One assertion per test** - Each test should verify one behavior
2. **Clear test names** - Use descriptive names: "should handle missing API key"
3. **Isolate tests** - Don't depend on test execution order
4. **Use setup/teardown** - Clean up mocks and state between tests
5. **Test edge cases** - nil values, empty strings, invalid inputs
6. **Mock external dependencies** - Don't make real API calls
7. **Test behavior, not implementation** - Focus on what the code does, not how

## Continuous Integration

To run tests in CI (GitHub Actions, etc.):

```bash
#!/bin/bash
set -e

# Install dependencies
nvim --headless -u NONE -c "PackerSync" -c "qa!"

# Run tests
nvim --headless -u NONE -c "luafile tests/run.lua" -c "qa!"

# Check linting
luacheck .

# Run type checking
lua-language-server --check .
```

## Resources

- [Plenary.nvim Testing](https://github.com/nvim-lua/plenary.nvim#testing)
- [Busted Test Framework](https://olivinelabs.com/busted/)
- [Luassert Assertions](https://olivinelabs.com/busted/#assertions)
- [Neovim Plugin Testing](https://github.com/nanotee/nvim-lua-guide#testing)
