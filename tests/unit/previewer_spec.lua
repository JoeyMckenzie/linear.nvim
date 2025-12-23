---@diagnostic disable: missing-fields, duplicate-set-field, need-check-nil
local previewer

-- Mock modules
local mock_previewers
local mock_utils
local mock_config
local mock_api

describe("linear.ui.telescope.previewer", function()
	before_each(function()
		-- Reset modules
		package.loaded["linear.ui.telescope.previewer"] = nil
		package.loaded["telescope.previewers"] = nil
		package.loaded["linear.utils"] = nil
		package.loaded["linear.config"] = nil
		package.loaded["linear.api"] = nil

		-- Mock telescope previewers
		mock_previewers = {
			new_buffer_previewer = function(opts)
				return {
					_opts = opts,
					title = opts.title,
					define_preview = opts.define_preview,
				}
			end,
		}
		package.loaded["telescope.previewers"] = mock_previewers

		-- Mock utils
		mock_utils = {
			format_date = function(date)
				return date and date:match("^([^T]+)") or "Unknown"
			end,
		}
		package.loaded["linear.utils"] = mock_utils

		-- Mock config
		mock_config = {
			get = function()
				return {
					ui = {
						telescope = {
							preview_comment_limit = 5,
						},
					},
				}
			end,
		}
		package.loaded["linear.config"] = mock_config

		-- Mock api
		mock_api = {
			get_issue_full = function(_id, callback)
				-- Default: no-op, tests can override
			end,
		}
		package.loaded["linear.api"] = mock_api

		previewer = require("linear.ui.telescope.previewer")
	end)

	describe("make_previewer()", function()
		it("returns a buffer previewer", function()
			local result = previewer.make_previewer()
			assert.is_not_nil(result)
			assert.equal("Issue Preview", result.title)
			assert.is_function(result.define_preview)
		end)

		it("has define_preview function", function()
			local result = previewer.make_previewer()
			assert.is_function(result.define_preview)
		end)
	end)

	describe("clear_cache()", function()
		it("is a function", function()
			assert.is_function(previewer.clear_cache)
		end)

		it("can be called without error", function()
			assert.has_no.errors(function()
				previewer.clear_cache()
			end)
		end)
	end)

	describe("preview rendering", function()
		local mock_bufnr
		local buffer_lines
		local buffer_options

		before_each(function()
			mock_bufnr = 1
			buffer_lines = {}
			buffer_options = {}

			-- Mock vim.api functions
			vim.api.nvim_buf_set_lines = function(bufnr, start, stop, strict, lines)
				if bufnr == mock_bufnr then
					buffer_lines = lines
				end
			end

			vim.api.nvim_buf_set_option = function(bufnr, name, value)
				if bufnr == mock_bufnr then
					buffer_options[name] = value
				end
			end

			vim.api.nvim_buf_is_valid = function(bufnr)
				return bufnr == mock_bufnr
			end
		end)

		it("shows 'No issue data' when entry is nil", function()
			local p = previewer.make_previewer()
			local mock_self = { state = { bufnr = mock_bufnr } }

			p.define_preview(mock_self, nil, nil)

			assert.equal(1, #buffer_lines)
			assert.equal("No issue data", buffer_lines[1])
		end)

		it("shows 'No issue data' when entry._data is nil", function()
			local p = previewer.make_previewer()
			local mock_self = { state = { bufnr = mock_bufnr } }

			p.define_preview(mock_self, { value = "123" }, nil)

			assert.equal(1, #buffer_lines)
			assert.equal("No issue data", buffer_lines[1])
		end)

		it("renders issue title", function()
			local p = previewer.make_previewer()
			local mock_self = { state = { bufnr = mock_bufnr } }
			local entry = {
				_data = {
					id = "issue-1",
					identifier = "PROJ-123",
					title = "Test Issue",
					priority = 2,
					createdAt = "2025-01-01T00:00:00Z",
					updatedAt = "2025-01-02T00:00:00Z",
				},
			}

			p.define_preview(mock_self, entry, nil)

			assert.is_true(#buffer_lines > 0)
			assert.equal("# PROJ-123: Test Issue", buffer_lines[1])
		end)

		it("renders issue status", function()
			local p = previewer.make_previewer()
			local mock_self = { state = { bufnr = mock_bufnr } }
			local entry = {
				_data = {
					id = "issue-1",
					identifier = "PROJ-123",
					title = "Test Issue",
					state = { name = "In Progress" },
					priority = 2,
					createdAt = "2025-01-01T00:00:00Z",
					updatedAt = "2025-01-02T00:00:00Z",
				},
			}

			p.define_preview(mock_self, entry, nil)

			local has_status = false
			for _, line in ipairs(buffer_lines) do
				if line:match("Status.*In Progress") then
					has_status = true
					break
				end
			end
			assert.is_true(has_status)
		end)

		it("renders issue description", function()
			local p = previewer.make_previewer()
			local mock_self = { state = { bufnr = mock_bufnr } }
			local entry = {
				_data = {
					id = "issue-1",
					identifier = "PROJ-123",
					title = "Test Issue",
					description = "This is the description",
					priority = 2,
					createdAt = "2025-01-01T00:00:00Z",
					updatedAt = "2025-01-02T00:00:00Z",
				},
			}

			p.define_preview(mock_self, entry, nil)

			local has_description = false
			for _, line in ipairs(buffer_lines) do
				if line == "This is the description" then
					has_description = true
					break
				end
			end
			assert.is_true(has_description)
		end)

		it("sets filetype to markdown", function()
			local p = previewer.make_previewer()
			local mock_self = { state = { bufnr = mock_bufnr } }
			local entry = {
				_data = {
					id = "issue-1",
					identifier = "PROJ-123",
					title = "Test Issue",
					priority = 2,
					createdAt = "2025-01-01T00:00:00Z",
					updatedAt = "2025-01-02T00:00:00Z",
				},
			}

			p.define_preview(mock_self, entry, nil)

			assert.equal("markdown", buffer_options.filetype)
		end)

		it("fetches full issue details when not cached", function()
			local fetch_called = false
			local fetched_id = nil

			mock_api.get_issue_full = function(id, _callback)
				fetch_called = true
				fetched_id = id
			end

			local p = previewer.make_previewer()
			local mock_self = { state = { bufnr = mock_bufnr } }
			local entry = {
				_data = {
					id = "issue-1",
					identifier = "PROJ-123",
					title = "Test Issue",
					priority = 2,
					createdAt = "2025-01-01T00:00:00Z",
					updatedAt = "2025-01-02T00:00:00Z",
				},
			}

			p.define_preview(mock_self, entry, nil)

			assert.is_true(fetch_called)
			assert.equal("issue-1", fetched_id)
		end)

		it("does not fetch when preview_comment_limit is 0", function()
			mock_config.get = function()
				return {
					ui = {
						telescope = {
							preview_comment_limit = 0,
						},
					},
				}
			end

			local fetch_called = false
			mock_api.get_issue_full = function(_id, _callback)
				fetch_called = true
			end

			local p = previewer.make_previewer()
			local mock_self = { state = { bufnr = mock_bufnr } }
			local entry = {
				_data = {
					id = "issue-1",
					identifier = "PROJ-123",
					title = "Test Issue",
					priority = 2,
					createdAt = "2025-01-01T00:00:00Z",
					updatedAt = "2025-01-02T00:00:00Z",
				},
			}

			p.define_preview(mock_self, entry, nil)

			assert.is_false(fetch_called)
		end)
	end)
end)
