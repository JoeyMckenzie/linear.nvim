#!/usr/bin/env lua

---Run all tests using plenary's test framework
---Usage: nvim --headless -u NONE -c "luafile run_tests.lua"
---Or from Neovim: :luafile run_tests.lua

local plenary_dir = vim.fn.fnamemodify(vim.fn.stdpath("data") .. "/site/pack/packer/start/plenary.nvim", ":p")

if not vim.loop.fs_stat(plenary_dir) then
	print("Error: plenary.nvim not found. Install it with your plugin manager first.")
	os.exit(1)
end

-- Add plenary to the path
vim.opt.rtp:prepend(plenary_dir)
vim.opt.rtp:prepend(".")

-- Set up test environment
local busted = require("plenary.busted")

-- Export test utilities globally
_G.describe = busted.describe
_G.it = busted.it
_G.before_each = busted.before_each
_G.after_each = busted.after_each
_G.after_all = busted.after_all
_G.before_all = busted.before_all

-- Load and run tests
print("\n========== Running Linear.nvim Tests ==========\n")

local test_dir = "tests/unit"
local test_files = vim.fn.glob(test_dir .. "/*_spec.lua", false, true)

for _, test_file in ipairs(test_files) do
	print("Loading: " .. test_file)
	dofile(test_file)
end

print("\n========== Test Run Complete ==========\n")
