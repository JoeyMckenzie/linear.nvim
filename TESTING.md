# Linear.nvim Phase 1 Testing Guide

## Quick Start Test

### 1. Setup Environment
```bash
# Navigate to the plugin directory
cd /Users/jmckenzie/github.com/joeymckenzie/linear.nvim

# Export the API key (you should have already done this)
export LINEAR_API_KEY="lin_api_xxxxxxxxxxxxxxxxxxxxx"
```

### 2. Load the Plugin in Neovim

Add to your neovim config (e.g., `~/.config/nvim/init.lua` or `~/.config/nvim/init.vim`):

```lua
-- For init.lua
vim.opt.rtp:prepend('/Users/jmckenzie/github.com/joeymckenzie/linear.nvim')
```

Or for init.vim:
```vim
" For init.vim
set rtp+=/Users/jmckenzie/github.com/joeymckenzie/linear.nvim
```

Then start Neovim:
```bash
nvim
```

### 3. Run the Unit Tests

In Neovim, run:
```
:luafile test/phase1.lua
```

You should see:
```
========== LINEAR.NVIM PHASE 1 TESTS ==========

TEST: Config module loads without errors
  ✓ PASS

TEST: Config has correct default values
  ✓ PASS

TEST: API key can be loaded from environment
  ✓ PASS

[... more tests ...]

========== SUMMARY ==========
Passed: 10
Failed: 0
```

### 4. Test Authentication

Run the authentication test command:
```
:LinearTestAuth
```

Expected output (in a notification):
```
✓ Authentication successful! Logged in as: [Your Name]
```

If you see this, Phase 1 is working correctly!

## Detailed Test Coverage

### Unit Tests (test/phase1.lua)
- ✓ Config module loads and has all required functions
- ✓ Default configuration values are correct
- ✓ API key is loaded from LINEAR_API_KEY environment variable
- ✓ API module loads with all required functions
- ✓ API can be initialized with the key
- ✓ Utils module loads with all formatting functions
- ✓ Commands module loads correctly
- ✓ Utility functions format data correctly
- ✓ Issue formatting works for both list and detail views
- ✓ Plugin entry point is properly structured

### Integration Tests
- ✓ Verify the plugin initializes on Neovim startup
- ✓ Verify the `:LinearTestAuth` command exists and is callable
- ✓ Verify authentication succeeds with a valid API key
- ✓ Verify API returns user information correctly

## Troubleshooting

### "Could not load module"
**Problem:** Error like `attempt to call a nil value`

**Solution:** Ensure the plugin path is in vim.opt.rtp or you're using a plugin manager that includes the linear.nvim directory.

### "No API key found"
**Problem:** Notification says "Could not initialize - no API key found"

**Solution:**
```bash
# Make sure the environment variable is exported
export LINEAR_API_KEY="your-key-here"

# Or add it to your shell profile
echo 'export LINEAR_API_KEY="your-key-here"' >> ~/.bashrc
source ~/.bashrc
```

### "Authentication failed"
**Problem:** Running `:LinearTestAuth` shows an error

**Possible causes:**
1. Invalid API key - verify in https://linear.app/settings/api
2. Network issue - check your internet connection
3. Plenary.nvim not installed - install it via your plugin manager

**Solution:**
- Verify the key format starts with `lin_api_`
- Check that plenary.nvim is installed: `:call luaeval('require("plenary")')`

### "Plenary not found"
**Problem:** Error about plenary.curl

**Solution:** Install plenary.nvim:

Using packer.nvim:
```lua
use 'nvim-lua/plenary.nvim'
```

Using vim-plug:
```vim
Plug 'nvim-lua/plenary.nvim'
```

## Testing Checklist

Before moving to Phase 2, verify:

- [ ] Unit tests pass (`:luafile test/phase1.lua`)
- [ ] No errors on Neovim startup
- [ ] `:LinearTestAuth` shows success message
- [ ] API key is properly loaded (can see success notification)
- [ ] Plugin notification about "initialized successfully" appears
- [ ] No errors in Neovim error log (`:messages`)

## Manual Verification

You can also manually verify the modules by running Lua commands in Neovim:

```vim
:lua require('linear.config').get_api_key() and print('API key loaded!')
:lua require('linear.api')
:lua require('linear.utils')
:lua require('linear.commands')
```

If these commands execute without errors, the basic structure is working.

## Next Steps

Once Phase 1 is verified:
1. Run `:LinearTestAuth` to confirm authentication works
2. Proceed to Phase 2: Telescope integration for issue listing
3. Test issue queries with filters
4. Build out the Telescope picker interface
