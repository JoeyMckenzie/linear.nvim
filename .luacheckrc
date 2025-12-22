-- Strict Luacheck configuration for linear.nvim
-- Based on Neovim's standards

stds.nvim = {
	globals = { "vim" },
}

std = "lua51+nvim"

-- Code quality standards
max_line_length = 120
max_cyclomatic_complexity = 10

-- Strict checking
unused = true
unused_args = true
redefined = true
self = false

-- Only ignore idiomatic Lua patterns
-- 212: unused argument with underscore prefix (idiomatic in Lua)
ignore = { "212" }

-- Tests are less strict
files["tests/**"] = {
	std = "lua51+nvim+busted",
	ignore = { "212", "213", "542" },  -- unused args, variables, and empty blocks
	max_cyclomatic_complexity = 50,    -- tests can be more complex (includes JSON parser)
}

-- Test runner files
files["run_tests.lua"] = {
	std = "lua51+nvim",
}

-- UI module (has stubs with unused arguments)
files["lua/linear/ui/**"] = {
	std = "lua51+nvim",
	ignore = { "211", "212", "213", "221", "542" },  -- unused functions, args, variables, empty blocks
	max_cyclomatic_complexity = 50,    -- allow complex finders
}

-- Phase 2 manual test file (has complex formatting helpers)
files["test_phase2.lua"] = {
	std = "lua51+nvim",
	max_cyclomatic_complexity = 50,    -- test file with formatting functions
}

-- Ignore Makefile (not Lua)
files["Makefile"] = {}
