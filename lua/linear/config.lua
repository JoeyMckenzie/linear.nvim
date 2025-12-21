local M = {}

-- Default configuration
local defaults = {
	api_key = nil,
	default_filters = {
		assignee = "me",
		states = { "in_progress", "todo" },
	},
	ui = {
		telescope = {
			theme = "dropdown",
			previewer = true,
		},
		details = {
			window_type = "float",
			width = 0.8,
			height = 0.8,
		},
	},
	keymaps = {
		list_issues = "<leader>li",
		create_issue = "<leader>lc",
		close = "q",
		update_status = "s",
		add_comment = "c",
	},
}

local config = vim.deepcopy(defaults)

-- Get API key from various sources
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

-- Setup function to configure the plugin
M.setup = function(opts)
	opts = opts or {}
	config = vim.tbl_deep_extend("force", config, opts)
	return config
end

-- Get current configuration
M.get = function()
	return config
end

-- Get API key with validation
M.get_api_key = function()
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
