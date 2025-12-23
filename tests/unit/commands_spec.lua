---@diagnostic disable: missing-fields, duplicate-set-field, need-check-nil
local commands

-- Track created commands
local created_commands = {}

-- Store original functions
local original_create_user_command = vim.api.nvim_create_user_command

-- Mock pickers module (must be set before requiring commands)
local mock_pickers = {
	issues = function() end,
	search_issues = function() end,
	board_picker = function() end,
	team_picker = function() end,
	cycle_picker = function() end,
	current_issue = function() end,
}

describe("linear.commands", function()
	before_each(function()
		-- Reset modules
		package.loaded["linear.commands"] = nil
		package.loaded["linear.context"] = nil
		package.loaded["linear.utils"] = nil
		package.loaded["linear.api"] = nil
		package.loaded["linear.ui.telescope.pickers"] = nil

		-- Pre-load mock pickers BEFORE commands.lua requires it
		package.loaded["linear.ui.telescope.pickers"] = mock_pickers

		-- Mock vim.api.nvim_create_user_command
		created_commands = {}
		vim.api.nvim_create_user_command = function(name, callback, opts)
			created_commands[name] = {
				callback = callback,
				opts = opts,
			}
		end

		commands = require("linear.commands")
	end)

	after_each(function()
		vim.api.nvim_create_user_command = original_create_user_command
	end)

	describe("setup_commands()", function()
		it("registers LinearIssues command", function()
			commands.setup_commands()
			assert.is_not_nil(created_commands["LinearIssues"])
			assert.equal(created_commands["LinearIssues"].opts.desc, "Browse your assigned Linear issues")
		end)

		it("registers LinearSearch command", function()
			commands.setup_commands()
			assert.is_not_nil(created_commands["LinearSearch"])
			assert.equal(created_commands["LinearSearch"].opts.desc, "Search Linear issues")
			assert.equal(created_commands["LinearSearch"].opts.nargs, "?")
		end)

		it("registers LinearBoards command", function()
			commands.setup_commands()
			assert.is_not_nil(created_commands["LinearBoards"])
			assert.equal(created_commands["LinearBoards"].opts.desc, "Browse Linear boards/projects")
		end)

		it("registers LinearTeams command", function()
			commands.setup_commands()
			assert.is_not_nil(created_commands["LinearTeams"])
			assert.equal(created_commands["LinearTeams"].opts.desc, "Browse Linear teams")
		end)

		it("registers LinearCycle command", function()
			commands.setup_commands()
			assert.is_not_nil(created_commands["LinearCycle"])
			assert.equal(created_commands["LinearCycle"].opts.nargs, "*")
		end)

		it("registers LinearCurrent command", function()
			commands.setup_commands()
			assert.is_not_nil(created_commands["LinearCurrent"])
			assert.equal(created_commands["LinearCurrent"].opts.nargs, "?")
		end)

		it("registers all 6 commands", function()
			commands.setup_commands()
			local count = 0
			for _ in pairs(created_commands) do
				count = count + 1
			end
			assert.equal(6, count)
		end)
	end)

	describe("LinearCycle argument parsing", function()
		local picker_opts_received

		before_each(function()
			picker_opts_received = nil

			-- Override cycle_picker to capture opts
			mock_pickers.cycle_picker = function(opts)
				picker_opts_received = opts
			end

			commands.setup_commands()
		end)

		it("passes show_all=false by default", function()
			created_commands["LinearCycle"].callback({ fargs = {} })
			assert.is_false(picker_opts_received.show_all)
			assert.is_nil(picker_opts_received.team_name)
		end)

		it("passes show_all=true when 'all' argument provided", function()
			created_commands["LinearCycle"].callback({ fargs = { "all" } })
			assert.is_true(picker_opts_received.show_all)
		end)

		it("passes show_all=true when 'ALL' argument provided (case insensitive)", function()
			created_commands["LinearCycle"].callback({ fargs = { "ALL" } })
			assert.is_true(picker_opts_received.show_all)
		end)

		it("passes team_name when provided", function()
			created_commands["LinearCycle"].callback({ fargs = { "Fundraising" } })
			assert.equal("Fundraising", picker_opts_received.team_name)
			assert.is_false(picker_opts_received.show_all)
		end)

		it("passes both team_name and show_all", function()
			created_commands["LinearCycle"].callback({ fargs = { "Fundraising", "all" } })
			assert.equal("Fundraising", picker_opts_received.team_name)
			assert.is_true(picker_opts_received.show_all)
		end)

		it("handles team name with 'all' in different order", function()
			created_commands["LinearCycle"].callback({ fargs = { "all", "Fundraising" } })
			assert.equal("Fundraising", picker_opts_received.team_name)
			assert.is_true(picker_opts_received.show_all)
		end)

		it("handles quoted team name with spaces", function()
			created_commands["LinearCycle"].callback({ fargs = { "Technical Debt" } })
			assert.equal("Technical Debt", picker_opts_received.team_name)
		end)

		it("handles quoted team name with 'all'", function()
			created_commands["LinearCycle"].callback({ fargs = { "Technical Debt", "all" } })
			assert.equal("Technical Debt", picker_opts_received.team_name)
			assert.is_true(picker_opts_received.show_all)
		end)
	end)

	describe("LinearCurrent command", function()
		local context_state = {}
		local notifications = {}
		local api_callback = nil
		local picker_called = false
		local picker_identifier = nil
		local mock_context
		local mock_utils
		local mock_api

		before_each(function()
			context_state = { identifier = nil }
			notifications = {}
			api_callback = nil
			picker_called = false
			picker_identifier = nil

			-- Reset modules
			package.loaded["linear.commands"] = nil
			package.loaded["linear.context"] = nil
			package.loaded["linear.utils"] = nil
			package.loaded["linear.api"] = nil
			package.loaded["linear.ui.telescope.pickers"] = nil

			-- Mock context module
			mock_context = {
				get = function()
					return context_state.identifier
				end,
				set = function(id)
					context_state.identifier = id
				end,
				clear = function()
					context_state.identifier = nil
				end,
				resolve = function()
					return context_state.identifier
				end,
				is_git_repo = function()
					return true
				end,
			}
			package.loaded["linear.context"] = mock_context

			-- Mock utils module
			mock_utils = {
				notify = function(msg, level)
					table.insert(notifications, { msg = msg, level = level })
				end,
			}
			package.loaded["linear.utils"] = mock_utils

			-- Mock api module
			mock_api = {
				search_issues = function(_query, _limit, callback)
					api_callback = callback
				end,
			}
			package.loaded["linear.api"] = mock_api

			-- Mock pickers module
			package.loaded["linear.ui.telescope.pickers"] = {
				current_issue = function(identifier)
					picker_called = true
					picker_identifier = identifier
				end,
				cycle_picker = function() end,
				issues = function() end,
				search_issues = function() end,
				board_picker = function() end,
				team_picker = function() end,
			}

			-- Mock vim command creation
			created_commands = {}
			vim.api.nvim_create_user_command = function(name, callback, opts)
				created_commands[name] = {
					callback = callback,
					opts = opts,
				}
			end

			-- Re-require commands with mocked dependencies
			commands = require("linear.commands")
			commands.setup_commands()
		end)

		it("clears context when 'clear' argument provided", function()
			context_state.identifier = "SUP-1234"
			created_commands["LinearCurrent"].callback({ args = "clear" })

			assert.is_nil(context_state.identifier)
			assert.equal(1, #notifications)
			assert.matches("context cleared", notifications[1].msg)
		end)

		it("clears context case-insensitively", function()
			context_state.identifier = "SUP-1234"
			created_commands["LinearCurrent"].callback({ args = "CLEAR" })

			assert.is_nil(context_state.identifier)
		end)

		it("validates issue before setting context", function()
			created_commands["LinearCurrent"].callback({ args = "SUP-1234" })

			-- Should have triggered API call
			assert.is_not_nil(api_callback)
		end)

		it("sets context on successful validation", function()
			created_commands["LinearCurrent"].callback({ args = "sup-1234" })

			-- Simulate successful API response with exact match
			api_callback({
				issueSearch = {
					nodes = {
						{ identifier = "SUP-1234", title = "Test Issue" },
					},
				},
			}, nil)

			assert.equal("SUP-1234", context_state.identifier)
			assert.equal(1, #notifications)
			assert.matches("context set to SUP%-1234", notifications[1].msg)
		end)

		it("shows error when issue not found", function()
			created_commands["LinearCurrent"].callback({ args = "SUP-9999" })

			-- Simulate empty API response
			api_callback({
				issueSearch = {
					nodes = {},
				},
			}, nil)

			assert.is_nil(context_state.identifier)
			assert.equal(1, #notifications)
			assert.matches("not found", notifications[1].msg)
		end)

		it("shows error when no exact match found", function()
			created_commands["LinearCurrent"].callback({ args = "SUP-1234" })

			-- Simulate API response without exact match
			api_callback({
				issueSearch = {
					nodes = {
						{ identifier = "SUP-1235", title = "Similar Issue" },
					},
				},
			}, nil)

			assert.is_nil(context_state.identifier)
			assert.matches("not found", notifications[1].msg)
		end)

		it("shows error on API failure", function()
			created_commands["LinearCurrent"].callback({ args = "SUP-1234" })

			-- Simulate API error
			api_callback(nil, "Network error")

			assert.is_nil(context_state.identifier)
			assert.matches("Failed to validate", notifications[1].msg)
		end)

		it("opens picker when context is resolved", function()
			context_state.identifier = "SUP-1234"
			created_commands["LinearCurrent"].callback({ args = "" })

			assert.is_true(picker_called)
			assert.equal("SUP-1234", picker_identifier)
		end)

		it("shows notification when no context and not in git repo", function()
			context_state.identifier = nil
			mock_context.is_git_repo = function()
				return false
			end

			created_commands["LinearCurrent"].callback({ args = "" })

			assert.is_false(picker_called)
			assert.matches("Not in a git repository", notifications[1].msg)
		end)

		it("shows notification when no context detected", function()
			context_state.identifier = nil

			created_commands["LinearCurrent"].callback({ args = "" })

			assert.is_false(picker_called)
			assert.matches("No issue detected", notifications[1].msg)
		end)
	end)

	describe("LinearSearch command", function()
		local search_query = nil

		before_each(function()
			search_query = nil

			-- Reset modules
			package.loaded["linear.commands"] = nil
			package.loaded["linear.ui.telescope.pickers"] = nil

			package.loaded["linear.ui.telescope.pickers"] = {
				search_issues = function(query)
					search_query = query
				end,
				issues = function() end,
				cycle_picker = function() end,
				board_picker = function() end,
				team_picker = function() end,
				current_issue = function() end,
			}

			-- Mock vim command creation
			created_commands = {}
			vim.api.nvim_create_user_command = function(name, callback, opts)
				created_commands[name] = {
					callback = callback,
					opts = opts,
				}
			end

			commands = require("linear.commands")
			commands.setup_commands()
		end)

		it("passes query to search_issues picker", function()
			created_commands["LinearSearch"].callback({ args = "bug fix" })
			assert.equal("bug fix", search_query)
		end)

		it("passes nil for empty query", function()
			created_commands["LinearSearch"].callback({ args = "" })
			assert.is_nil(search_query)
		end)

		it("passes nil when no args", function()
			created_commands["LinearSearch"].callback({ args = nil })
			assert.is_nil(search_query)
		end)
	end)
end)
