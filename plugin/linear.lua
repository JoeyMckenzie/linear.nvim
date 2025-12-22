---Plugin auto-load entry point for linear.nvim

if vim.g.loaded_linear ~= nil then
	return
end

---@type integer
vim.g.loaded_linear = 1

require("linear").setup()

-- Load test commands if test_phase2.lua exists
local plugin_dir = vim.fn.expand("<sfile>:p:h")
local project_root = vim.fn.fnamemodify(plugin_dir, ":h")
local test_file = vim.fn.join({ project_root, "test_phase2.lua" }, "/")

if vim.fn.filereadable(test_file) == 1 then
	dofile(test_file)
end
