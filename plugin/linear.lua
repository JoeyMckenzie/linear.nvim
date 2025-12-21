-- Plugin auto-load entry point for linear.nvim

if vim.g.loaded_linear ~= nil then
	return
end

vim.g.loaded_linear = 1

require("linear").setup()
