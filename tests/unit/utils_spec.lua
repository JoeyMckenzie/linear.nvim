---@diagnostic disable: duplicate-set-field, assign-type-mismatch
---@type any
local utils = require("linear.utils")

describe("linear.utils", function()
	---@type linear.Issue
	local mock_issue = {
		id = "issue-1",
		identifier = "LIN-123",
		title = "Test Issue",
		description = "This is a test issue",
		state = { name = "In Progress", color = "#0052CC" },
		priority = 2,
		assignee = { name = "Joey McKenzie" },
		createdAt = "2025-12-21T10:30:00Z",
		updatedAt = "2025-12-21T11:00:00Z",
	}

	describe("format_issue()", function()
		it("formats issue with all fields", function()
			local result = utils.format_issue(mock_issue)
			assert.is_string(result)
			assert.matches("LIN%-123", result)
			assert.matches("Test Issue", result)
			assert.matches("In Progress", result)
			assert.matches("2", result) -- priority
			assert.matches("Joey McKenzie", result)
		end)

		it("returns empty string for nil issue", function()
			local result = utils.format_issue(nil)
			assert.equal(result, "")
		end)

		it("handles missing assignee", function()
			---@type linear.Issue
			local issue_no_assignee = {
				id = "issue-2",
				identifier = "LIN-124",
				title = "No Assignee",
				description = "",
				state = { name = "Todo", color = "#CCCCCC" },
				priority = 0,
				assignee = nil,
				createdAt = "2025-12-21T10:30:00Z",
				updatedAt = "2025-12-21T10:30:00Z",
			}
			local result = utils.format_issue(issue_no_assignee)
			assert.matches("Unassigned", result)
		end)

		it("handles missing state", function()
			---@type linear.Issue
			local issue_no_state = {
				id = "issue-3",
				identifier = "LIN-125",
				title = "No State",
				description = "",
				state = nil,
				priority = 1,
				assignee = { name = "User" },
				createdAt = "2025-12-21T10:30:00Z",
				updatedAt = "2025-12-21T10:30:00Z",
			}
			local result = utils.format_issue(issue_no_state)
			assert.matches("Unknown", result)
		end)
	end)

	describe("format_issue_detail()", function()
		it("formats detailed issue view", function()
			local result = utils.format_issue_detail(mock_issue)
			assert.is_string(result)
			assert.matches("Issue: LIN%-123", result)
			assert.matches("Title: Test Issue", result)
			assert.matches("State: In Progress", result)
			assert.matches("Assignee: Joey McKenzie", result)
			assert.matches("Description:", result)
			assert.matches("This is a test issue", result)
		end)

		it("returns empty string for nil issue", function()
			local result = utils.format_issue_detail(nil)
			assert.equal(result, "")
		end)

		it("handles missing fields gracefully", function()
			---@type linear.Issue
			local minimal_issue = {
				id = "issue-4",
				identifier = "LIN-126",
				title = "Minimal",
				description = nil,
				state = nil,
				priority = 0,
				assignee = nil,
				createdAt = nil,
				updatedAt = nil,
			}
			local result = utils.format_issue_detail(minimal_issue)
			assert.matches("LIN%-126", result)
			assert.matches("Minimal", result)
			assert.matches("No description", result)
		end)

		it("includes date separators", function()
			local result = utils.format_issue_detail(mock_issue)
			assert.matches("%-%-%-", result) -- The --- separator
		end)
	end)

	describe("priority_label()", function()
		it("returns correct label for priority 0", function()
			assert.equal(utils.priority_label(0), "None")
		end)

		it("returns correct label for priority 1", function()
			assert.equal(utils.priority_label(1), "Urgent")
		end)

		it("returns correct label for priority 2", function()
			assert.equal(utils.priority_label(2), "High")
		end)

		it("returns correct label for priority 3", function()
			assert.equal(utils.priority_label(3), "Medium")
		end)

		it("returns correct label for priority 4", function()
			assert.equal(utils.priority_label(4), "Low")
		end)

		it("returns Unknown for invalid priority", function()
			assert.equal(utils.priority_label(99), "Unknown")
		end)
	end)

	describe("format_date()", function()
		it("extracts date from ISO timestamp", function()
			local result = utils.format_date("2025-12-21T10:30:00Z")
			assert.equal(result, "2025-12-21")
		end)

		it("returns N/A for nil date", function()
			local result = utils.format_date(nil)
			assert.equal(result, "N/A")
		end)

		it("returns N/A for empty date", function()
			local result = utils.format_date("")
			assert.equal(result, "")
		end)

		it("handles dates without timestamp", function()
			local result = utils.format_date("2025-12-21")
			assert.equal(result, "2025-12-21")
		end)
	end)

	describe("is_empty()", function()
		it("returns true for nil", function()
			assert.is_true(utils.is_empty(nil))
		end)

		it("returns true for empty string", function()
			assert.is_true(utils.is_empty(""))
		end)

		it("returns false for non-empty string", function()
			assert.is_false(utils.is_empty("content"))
		end)

		it("returns false for space character", function()
			assert.is_false(utils.is_empty(" "))
		end)

		it("returns false for zero", function()
			assert.is_false(utils.is_empty("0"))
		end)
	end)

	describe("notify()", function()
		it("calls vim.notify with message", function()
			local notify_called = false
			local captured_msg = ""

			-- Mock vim.notify
			local original_notify = vim.notify
			vim.notify = function(msg, _level)
				notify_called = true
				captured_msg = msg
			end

			utils.notify("Test message")

			assert.is_true(notify_called)
			assert.matches("Linear%.nvim", captured_msg)
			assert.matches("Test message", captured_msg)

			-- Restore
			vim.notify = original_notify
		end)

		it("uses default INFO level", function()
			local captured_level = nil

			local original_notify = vim.notify
			vim.notify = function(_msg, level)
				captured_level = level
			end

			utils.notify("Test")

			assert.equal(captured_level, vim.log.levels.INFO)

			vim.notify = original_notify
		end)

		it("accepts custom log level", function()
			local captured_level = nil

			local original_notify = vim.notify
			vim.notify = function(_msg, level)
				captured_level = level
			end

			utils.notify("Test", vim.log.levels.ERROR)

			assert.equal(captured_level, vim.log.levels.ERROR)

			vim.notify = original_notify
		end)
	end)

	describe("status_icon", function()
		it("returns white circle for backlog/todo states", function()
			assert.equals("⚪", utils.status_icon("Backlog"))
			assert.equals("⚪", utils.status_icon("Todo"))
		end)

		it("returns yellow circle for in progress", function()
			assert.equals("🟡", utils.status_icon("In Progress"))
		end)

		it("returns blue circle for in review", function()
			assert.equals("🔵", utils.status_icon("In Review"))
		end)

		it("returns green circle for done", function()
			assert.equals("🟢", utils.status_icon("Done"))
		end)

		it("returns black circle for canceled", function()
			assert.equals("⚫", utils.status_icon("Canceled"))
		end)

		it("returns white circle for unknown states", function()
			assert.equals("⚪", utils.status_icon("Unknown"))
			assert.equals("⚪", utils.status_icon(nil))
		end)
	end)

	describe("priority_icon", function()
		it("returns red circle for urgent (1)", function()
			assert.equals("🔴", utils.priority_icon(1))
		end)

		it("returns up arrow for high (2)", function()
			assert.equals("⬆️", utils.priority_icon(2))
		end)

		it("returns right arrow for medium (3)", function()
			assert.equals("➡️", utils.priority_icon(3))
		end)

		it("returns down arrow for low (4)", function()
			assert.equals("⬇️", utils.priority_icon(4))
		end)

		it("returns empty string for no priority (0 or nil)", function()
			assert.equals("", utils.priority_icon(0))
			assert.equals("", utils.priority_icon(nil))
		end)
	end)

	describe("pr_status", function()
		it("returns empty string for nil attachments", function()
			assert.equals("", utils.pr_status(nil))
		end)

		it("returns empty string for attachments without nodes", function()
			assert.equals("", utils.pr_status({}))
		end)

		it("returns empty string for empty nodes", function()
			assert.equals("", utils.pr_status({ nodes = {} }))
		end)

		it("returns empty string for non-GitHub attachments", function()
			local attachments = {
				nodes = {
					{ sourceType = "Figma", subtitle = "Design file" },
					{ sourceType = "Slack", subtitle = "Message" },
				},
			}
			assert.equals("", utils.pr_status(attachments))
		end)

		it("returns [PR:merged] for merged PR", function()
			local attachments = {
				nodes = {
					{ sourceType = "GitHub", subtitle = "Merged" },
				},
			}
			assert.equals(" [PR:merged]", utils.pr_status(attachments))
		end)

		it("returns [PR:open] for open PR", function()
			local attachments = {
				nodes = {
					{ sourceType = "GitHub", subtitle = "Open" },
				},
			}
			assert.equals(" [PR:open]", utils.pr_status(attachments))
		end)

		it("returns [PR:closed] for closed PR", function()
			local attachments = {
				nodes = {
					{ sourceType = "GitHub", subtitle = "Closed" },
				},
			}
			assert.equals(" [PR:closed]", utils.pr_status(attachments))
		end)

		it("returns [PR:draft] for draft PR", function()
			local attachments = {
				nodes = {
					{ sourceType = "GitHub", subtitle = "Draft" },
				},
			}
			assert.equals(" [PR:draft]", utils.pr_status(attachments))
		end)

		it("handles case-insensitive sourceType", function()
			local attachments = {
				nodes = {
					{ sourceType = "github", subtitle = "Merged" },
				},
			}
			assert.equals(" [PR:merged]", utils.pr_status(attachments))
		end)

		it("handles case-insensitive subtitle", function()
			local attachments = {
				nodes = {
					{ sourceType = "GitHub", subtitle = "MERGED" },
				},
			}
			assert.equals(" [PR:merged]", utils.pr_status(attachments))
		end)

		it("returns [PR:open] for unknown status", function()
			local attachments = {
				nodes = {
					{ sourceType = "GitHub", subtitle = "Some other status" },
				},
			}
			assert.equals(" [PR:open]", utils.pr_status(attachments))
		end)

		it("returns [PR] for empty subtitle", function()
			local attachments = {
				nodes = {
					{ sourceType = "GitHub", subtitle = "" },
				},
			}
			assert.equals(" [PR]", utils.pr_status(attachments))
		end)

		it("handles nil subtitle", function()
			local attachments = {
				nodes = {
					{ sourceType = "GitHub" },
				},
			}
			assert.equals(" [PR]", utils.pr_status(attachments))
		end)

		it("finds GitHub PR among multiple attachments", function()
			local attachments = {
				nodes = {
					{ sourceType = "Figma", subtitle = "Design" },
					{ sourceType = "GitHub", subtitle = "Merged" },
					{ sourceType = "Slack", subtitle = "Thread" },
				},
			}
			assert.equals(" [PR:merged]", utils.pr_status(attachments))
		end)

		it("handles sourceType containing 'pull'", function()
			local attachments = {
				nodes = {
					{ sourceType = "GitHubPullRequest", subtitle = "Open" },
				},
			}
			assert.equals(" [PR:open]", utils.pr_status(attachments))
		end)
	end)
end)
