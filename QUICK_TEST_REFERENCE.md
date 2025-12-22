# Quick Test Reference

## Run All Tests

### Prerequisites

Install busted (one-time setup):

```bash
luarocks install busted
# or on macOS: brew install busted
```

### Running Tests

```bash
# Using just (recommended)
just test

# Using busted directly
busted tests/unit/*_spec.lua

# Run specific test file
busted tests/unit/config_spec.lua

# Run with verbose output
busted tests/unit/*_spec.lua --verbose

# Run in TAP format (CI friendly)
busted tests/unit/*_spec.lua --output=TAP
```

**Note:** Busted is configured to find tests in `tests/unit/*_spec.lua`.

## Run Tests in Watch Mode

```bash
just test-watch
```

Watches `lua/` and `tests/` directories and re-runs tests on file changes.

## Manual Testing in Neovim

### Setup

```bash
# Export your API key
export LINEAR_API_KEY="..."

# Add to Neovim config (~/.config/nvim/init.lua)
vim.opt.rtp:prepend('/Users/jmckenzie/github.com/joeymckenzie/linear.nvim')

# Start Neovim
nvim
```

### Run Tests

In Neovim:

```vim
:luafile tests/run.lua
```

### Test Individual Functions

```vim
" Test config module
:lua local cfg = require('linear.config'); print(vim.inspect(cfg.get()))

" Test authentication
:LinearTestAuth

" Test utils
:lua
local utils = require('linear.utils')
local mock_issue = {
  identifier = "LIN-123",
  title = "Test Issue",
  state = { name = "In Progress", color = "#0052CC" },
  priority = 2,
  assignee = { name = "User" },
  createdAt = "2025-12-21T10:30:00Z",
  updatedAt = "2025-12-21T10:30:00Z",
  description = "Test description"
}
print(utils.format_issue(mock_issue))
<CR>
```

## Test Suite Structure

```
tests/
├── minimal_init.lua        # Minimal Neovim init for tests
├── run.lua                 # Test runner (legacy, use busted instead)
└── unit/
    ├── config_spec.lua     # Tests for config module (18 tests)
    ├── utils_spec.lua      # Tests for utils module (24 tests)
    └── api_spec.lua        # Tests for API module (9 tests)
```

## Test Statistics

- **Total Tests**: 51
- **Config Tests**: 18 tests - Config loading, merging, API key resolution
- **Utils Tests**: 24 tests - Formatting, type conversions, validations
- **API Tests**: 9 tests - Setup, query execution, error handling (with mocks)

## Code Quality Commands

```bash
# Lint check
just lint

# Type checking
just type-check

# Format code
just format

# Clean up
just clean
```

## Example Test Output

```
========== Linear.nvim Test Suite ==========

Found 3 test file(s):
  • api_spec.lua
  • config_spec.lua
  • utils_spec.lua

[Tests running...]

Config Tests
  ✓ Config module loads without errors
  ✓ Default configuration has correct values
  ✓ Setup merges user options
  ... (27 total)

Utils Tests
  ✓ Format issue for display
  ✓ Format issue detail view
  ✓ Priority label conversion
  ... (25 total)

API Tests
  ✓ API setup initializes with key
  ✓ GraphQL query execution
  ✓ Error handling
  ... (15 total)

========== All Tests Passed ==========
```

## Debugging

### Run single test file

Edit the test file and change `describe` to `fdescribe`:

```lua
fdescribe("linear.config", function()
  -- Only this describe block will run
end)
```

### Print debugging

Add `print()` statements in tests:

```lua
it("should work", function()
  local result = my_function()
  print("DEBUG:", vim.inspect(result))
end)
```

### Inspect values

```lua
print(vim.inspect({a = 1, b = {c = 2}}))
-- Output: { a = 1, b = { c = 2 } }
```

## CI Integration

To run tests in CI/CD (GitHub Actions, etc.):

```bash
#!/bin/bash
set -e

# Run all tests
nvim --headless -u NONE -c "luafile tests/run.lua" -c "qa!"

# Check linting
luacheck .

# Type check
lua-language-server --check .
```

## Troubleshooting

### "plenary.nvim not found"

Install plenary in your plugin manager:

```lua
-- packer.nvim
use 'nvim-lua/plenary.nvim'

-- lazy.nvim
{ 'nvim-lua/plenary.nvim' }
```

### Tests don't run

Make sure LINEAR_API_KEY is set:

```bash
export LINEAR_API_KEY="your-key-here"
nvim --headless -u NONE -c "luafile tests/run.lua"
```

### Type errors in tests

Tests use plenary's busted framework. Assertions available:

- `assert.equal(a, b)` - equality check
- `assert.is_nil(x)` - nil check
- `assert.is_true(x)` - boolean check
- `assert.matches(pattern, string)` - pattern matching
- `assert.contains(table, value)` - table contains

See [TESTING_GUIDE.md](./TESTING_GUIDE.md) for more details.

## Resources

- Full testing guide: [TESTING_GUIDE.md](./TESTING_GUIDE.md)
- Plenary testing: <https://github.com/nvim-lua/plenary.nvim#testing>
- Busted framework: <https://olivinelabs.com/busted/>
