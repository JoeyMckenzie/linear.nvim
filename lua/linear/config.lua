---@class linear.FilterConfig
---@field assignee string
---@field states string[]

---@class linear.TelescopeConfig
---@field theme string
---@field previewer boolean
---@field width number
---@field height number
---@field layout string
---@field preview_comment_limit number

---@class linear.DetailsConfig
---@field window_type string
---@field width number
---@field height number

---@class linear.StatuslineConfig
---@field show_title boolean
---@field title_max_length number

---@class linear.BranchConfig
---@field scopes string[]
---@field lowercase_identifier boolean

---@class linear.UIConfig
---@field telescope linear.TelescopeConfig
---@field details linear.DetailsConfig
---@field statusline linear.StatuslineConfig

---@class linear.KeymapsConfig
---@field list_issues string
---@field create_issue string
---@field close string
---@field update_status string
---@field add_comment string

---@class linear.Config
---@field api_key? string
---@field default_filters linear.FilterConfig
---@field ui linear.UIConfig
---@field keymaps linear.KeymapsConfig
---@field branch linear.BranchConfig

---@class linear.InternalConfig : linear.Config
---@field api_key? string

local M = {}

---@type linear.InternalConfig
local defaults = {
	api_key = nil,
	default_filters = {
		assignee = "me",
		states = { "in_progress", "todo" },
	},
	ui = {
		telescope = {
			theme = "", -- empty to use custom layout, or "dropdown", "ivy", "cursor"
			previewer = true,
			layout = "horizontal", -- "horizontal" (side-by-side) or "vertical"
			width = 0.8,
			height = 0.8,
			preview_comment_limit = 5, -- Number of comments to show in preview (0 to disable)
		},
		details = {
			window_type = "float",
			width = 0.8,
			height = 0.8,
		},
		statusline = {
			show_title = false, -- Set to true to show issue title
			title_max_length = 30, -- Truncate title to this length
		},
	},
	keymaps = {
		list_issues = "<leader>li",
		create_issue = "<leader>lc",
		close = "q",
		update_status = "s",
		add_comment = "c",
	},
	branch = {
		scopes = { "feature", "bugfix", "task", "chore" },
		lowercase_identifier = false,
	},
}

---@type linear.InternalConfig
local config = vim.deepcopy(defaults)

---Get API key from various sources
---@return string?
local function get_api_key()
	-- 1. Check if explicitly set in config
	if config.api_key then
		return config.api_key
	end

	-- 2. Check environment variable
	local env_key = os.getenv("LINEAR_API_KEY")
	if env_key then
		return env_key
	end

	-- 3. Check config file at ~/.config/linear/api_key
	local home = os.getenv("HOME")
	if not home then
		return nil
	end

	local config_file = home .. "/.config/linear/api_key"
	local f = io.open(config_file, "r")
	if f then
		local key = f:read("*a")
		f:close()
		-- Trim whitespace
		key = key:gsub("^%s+", ""):gsub("%s+$", "")
		if key ~= "" then
			return key
		end
	end

	return nil
end

---Setup function to configure the plugin
---@param opts? linear.Config
---@return linear.InternalConfig
function M.setup(opts)
	opts = opts or {}
	config = vim.tbl_deep_extend("force", config, opts) --[[@as linear.InternalConfig]]
	return config
end

---Get current configuration
---@return linear.InternalConfig
function M.get()
	return config
end

---Get API key with validation
---@return string?
function M.get_api_key()
	local key = get_api_key()
	if not key then
		vim.notify(
			"Linear.nvim: No API key found. Set LINEAR_API_KEY env var or configure api_key in setup()",
			vim.log.levels.ERROR
		)
		return nil
	end
	return key
end

return M
