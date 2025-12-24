# linear.nvim

A Neovim plugin for integrating with Linear issue tracking directly from your editor. Browse issues, update status, create branches, and track your current work context without leaving Neovim.

## Features

- **Telescope Integration**: Browse and search issues with Telescope pickers
- **Issue Preview**: View issue details, description, and comments in the preview pane
- **Quick Actions**: Open in browser, copy identifier/URL, update status, navigate to project board
- **Branch Creation**: Create git branches from issues with configurable naming conventions
- **Context Tracking**: Set and track your current working issue across sessions
- **Statusline Integration**: Show current issue in your statusline

## Requirements

- Neovim >= 0.9.0
- [plenary.nvim](https://github.com/nvim-lua/plenary.nvim)
- [telescope.nvim](https://github.com/nvim-telescope/telescope.nvim)
- Linear API key ([get one here](https://linear.app/settings/api))

## Installation

### lazy.nvim

```lua
{
  'joeymckenzie/linear.nvim',
  dependencies = {
    'nvim-lua/plenary.nvim',
    'nvim-telescope/telescope.nvim',
  },
  config = function()
    require('linear').setup({
      -- optional configuration
    })
  end,
}
```

### packer.nvim

```lua
use({
  'joeymckenzie/linear.nvim',
  requires = {
    'nvim-lua/plenary.nvim',
    'nvim-telescope/telescope.nvim',
  },
  config = function()
    require('linear').setup()
  end,
})
```

## Configuration

### API Key

Configure your Linear API key using one of these methods (in order of priority):

1. **Setup option** (not recommended for shared configs):
   ```lua
   require('linear').setup({
     api_key = 'lin_api_xxxxxxxxxxxxx'
   })
   ```

2. **Environment variable**:
   ```bash
   export LINEAR_API_KEY="lin_api_xxxxxxxxxxxxx"
   ```

3. **Config file** at `~/.config/linear/api_key`:
   ```
   lin_api_xxxxxxxxxxxxx
   ```

### Full Configuration

```lua
require('linear').setup({
  -- API key (prefer env var or config file instead)
  api_key = nil,

  -- Branch creation settings
  branch = {
    -- Scope options shown in picker when creating branches
    scopes = { "feature", "bugfix", "task", "chore" },
    -- Convert issue identifier to lowercase (PROJ-123 -> proj-123)
    lowercase_identifier = false,
  },

  -- Statusline settings
  statusline = {
    -- Show issue title in addition to identifier
    show_title = false,
    -- Max length for title (truncated with ...)
    title_max_length = 30,
  },

  -- UI settings
  ui = {
    -- Floating window dimensions for detail views
    details = {
      width = 0.8,
      height = 0.8,
    },
    -- Telescope picker settings
    telescope = {
      -- Number of comments to show in preview
      preview_comment_limit = 5,
    },
  },
})
```

## Commands

| Command | Description |
|---------|-------------|
| `:LinearTestAuth` | Test API authentication |
| `:LinearIssues` | Browse issues assigned to you |
| `:LinearIssuesAll` | Browse all issues |
| `:LinearIssuesTeam` | Browse team issues |
| `:LinearSetContext` | Set current issue context |
| `:LinearContext` | Show current issue context |
| `:LinearClearContext` | Clear current issue context |
| `:LinearBranch` | Create branch from current context |

## Telescope Picker

Open with `:LinearIssues`, `:LinearIssuesAll`, or `:LinearIssuesTeam`.

### Keybindings

| Key | Mode | Action |
|-----|------|--------|
| `<CR>` | i/n | Set issue as current context |
| `<C-o>` | i/n | Open issue in browser |
| `<C-y>` | i/n | Copy issue identifier to clipboard |
| `<C-u>` | i/n | Copy issue URL to clipboard |
| `<C-d>` | i/n | Show detailed issue view |
| `<C-s>` | i/n | Change issue status |
| `<C-b>` | i/n | Navigate to project board |
| `<C-g>` | i/n | Create git branch for issue |

## Branch Creation

Create git branches from Linear issues with `:LinearBranch` or `<C-g>` in the Telescope picker.

The flow:
1. Select a branch scope (feature, bugfix, task, chore)
2. Optionally include the issue title in the branch name
3. Branch is created and checked out
4. Issue context is automatically set

Branch format: `{scope}/{identifier}[-{slugified-title}]`

Examples:
- `feature/PROJ-123`
- `bugfix/PROJ-456-fix-login-validation`

## Statusline Integration

Display current issue context in your statusline:

```lua
-- lualine.nvim example
require('lualine').setup({
  sections = {
    lualine_x = {
      {
        function()
          return require('linear.statusline').get()
        end,
        cond = function()
          return require('linear.statusline').get() ~= nil
        end,
      },
    },
  },
})
```

Configure what to show:

```lua
require('linear').setup({
  statusline = {
    show_title = true,        -- Show "PROJ-123: Issue title"
    title_max_length = 20,    -- Truncate long titles
  },
})
```

## Lua API

### linear.api

```lua
local api = require('linear.api')

-- Execute GraphQL query
api.query(query_str, variables, callback)

-- Convenience methods (all async with callbacks)
api.get_viewer(callback)                    -- Get current user
api.get_issues(filters, callback)           -- List issues
api.get_issue(id, callback)                 -- Get single issue
api.get_issue_full(id, callback)            -- Get issue with comments
api.create_issue(data, callback)            -- Create issue
api.update_issue(id, updates, callback)     -- Update issue
api.create_comment(issue_id, body, callback) -- Add comment
api.get_teams(callback)                     -- List teams
api.get_states(callback)                    -- List workflow states
```

### linear.context

```lua
local context = require('linear.context')

context.set(issue)    -- Set current issue context
context.get()         -- Get current issue data
context.clear()       -- Clear context
context.resolve(callback) -- Resolve context from git branch
```

### linear.branch

```lua
local branch = require('linear.branch')

branch.slugify(str)                              -- Convert to branch-safe slug
branch.generate_branch_name(issue, scope, include_title)
branch.create_branch_for_issue(issue, callback)  -- Interactive flow
branch.create_branch_from_context()              -- Use current context
```

### linear.statusline

```lua
local statusline = require('linear.statusline')

statusline.get()          -- Get formatted statusline string
statusline.clear_cache()  -- Clear cached statusline
```

## Resources

- [Linear GraphQL API Documentation](https://developers.linear.app/docs/graphql/working-with-the-graphql-api)
- [Telescope.nvim](https://github.com/nvim-telescope/telescope.nvim)
- [Plenary.nvim](https://github.com/nvim-lua/plenary.nvim)

## License

MIT
