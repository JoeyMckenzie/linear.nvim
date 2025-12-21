# linear.nvim

A Neovim plugin for integrating with Linear issue tracking directly from your editor.

## Phase 1: Foundation & Authentication ✓

The initial implementation includes:
- Plugin structure with modular architecture
- Configuration system (supports env vars, config files, and setup options)
- Linear GraphQL API client with authentication
- Basic command infrastructure

### Setup

1. **Add linear.nvim to your plugin manager**

   Using `packer.nvim`:
   ```lua
   use({
     'joeymckenzie/linear.nvim',
     requires = {
       'nvim-lua/plenary.nvim',
       'nvim-telescope/telescope.nvim', -- for Phase 2
     },
   })
   ```

2. **Configure with your Linear API key**

   Option 1: Environment variable (recommended)
   ```bash
   export LINEAR_API_KEY="your-api-key-here"
   ```

   Option 2: Config file at `~/.config/linear/api_key`
   ```
   lin_api_xxxxxxxxxxxxxxxxxxxxx
   ```

   Option 3: In your Neovim config
   ```lua
   require('linear').setup({
     api_key = 'your-api-key-here'
   })
   ```

3. **Test authentication**

   Once Neovim is open with the plugin loaded, run:
   ```
   :LinearTestAuth
   ```

   You should see a notification confirming your authentication is working.

## API

The plugin exposes the following modules:

### `linear.config`
- `get()` - Get current configuration
- `get_api_key()` - Get and validate API key
- `setup(opts)` - Initialize configuration

### `linear.api`
GraphQL client with convenience wrappers:
- `setup(api_key)` - Initialize API client
- `query(query_str, variables, callback)` - Execute GraphQL query
- `get_viewer(callback)` - Get current user info
- `get_issues(filters, callback)` - List issues
- `get_issue(id, callback)` - Get single issue
- `create_issue(data, callback)` - Create issue
- `update_issue(id, updates, callback)` - Update issue
- `create_comment(issue_id, body, callback)` - Add comment
- `get_teams(callback)` - List teams
- `get_states(callback)` - List issue states

### `linear.utils`
Helper functions:
- `format_issue(issue)` - Format issue for display
- `format_issue_detail(issue)` - Format detailed issue view
- `priority_label(priority)` - Convert priority number to label
- `format_date(iso_date)` - Format ISO dates
- `notify(msg, level)` - Show notifications
- `is_empty(s)` - Check if string is empty

### `linear.commands`
- `test_auth()` - Test API authentication
- `setup_commands()` - Register available commands

## Next Steps

Phase 2 will add:
- Telescope picker for issue listing and searching
- Filtering by status, assignee, team, and project
- Preview pane with issue descriptions
- Commands: `:LinearIssues`, `:LinearIssuesAll`, `:LinearIssuesTeam`

## Documentation

For detailed API documentation, see Linear's GraphQL docs:
https://developers.linear.app/docs/graphql/working-with-the-graphql-api

## Resources

- [Linear GraphQL API](https://developers.linear.app/docs/graphql/working-with-the-graphql-api)
- [Telescope.nvim](https://github.com/nvim-telescope/telescope.nvim)
- [Plenary.nvim](https://github.com/nvim-lua/plenary.nvim)
