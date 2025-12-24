---@class LinearTelescope
---Telescope integration for Linear.nvim
local M = {}

M.finders = require("linear.ui.telescope.finders")
M.pickers = require("linear.ui.telescope.pickers")
M.actions = require("linear.ui.telescope.actions")
M.state = require("linear.ui.telescope.state")
M.previewer = require("linear.ui.telescope.previewer")

return M
