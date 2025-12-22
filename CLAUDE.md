# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

linear.nvim is a Neovim plugin for integrating with Linear issue tracking. It uses Lua 5.1, the Neovim API, and plenary.nvim for HTTP/async operations. Phase 1 (Foundation & Authentication) is complete; Phase 2 (Telescope Integration) is in progress.

## Development Commands

All tasks use `just` (command runner):

```bash
just test          # Run unit tests with busted
just test-watch    # Run tests in watch mode (re-runs on file changes)
just lint          # Run luacheck linter
just type-check    # Check types with lua-language-server
just format        # Format code with StyLua
just clean         # Clean swap files and .DS_Store
```

Required tools: busted, luacheck, lua-language-server, stylua, fswatch (for watch mode)

## Architecture

```
lua/linear/
├── init.lua           # Plugin entry point, orchestrates setup
├── config.lua         # Configuration management (env vars, config files, setup opts)
├── api.lua            # GraphQL client for Linear API (uses plenary.curl)
├── commands.lua       # User command registration
├── utils.lua          # Formatting, notifications, helpers
└── ui/
    └── telescope/     # Telescope integration (pickers, finders, actions, previewer)

plugin/linear.lua      # Auto-load entry point
tests/unit/            # Unit tests (*_spec.lua files)
```

**Key patterns:**
- All API operations are async via callbacks
- Config sources (priority order): setup options > `LINEAR_API_KEY` env var > `~/.config/linear/api_key`
- GraphQL queries go through `api.query()` with variables and callback

## Testing

Tests use busted with BDD-style `describe`/`it` syntax. Tests mock the `vim` API to run outside Neovim.

```bash
just test                           # Run all tests
busted tests/unit/config_spec.lua   # Run single test file
```

Test files reset `package.loaded` for module isolation between tests.

## Code Quality

- Line length: 120 characters max
- Cyclomatic complexity: 10 (core), 50 (tests/UI)
- Type annotations via Lua doc comments (`---@param`, `---@return`)
- Strict unused variable detection enabled

## Dependencies

**Runtime:** plenary.nvim (required), telescope.nvim (Phase 2+)
**External API:** Linear GraphQL API at `https://api.linear.app/graphql`
