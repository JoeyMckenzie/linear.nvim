# Linear.nvim development tasks

# Display available commands
help:
    @echo "Linear.nvim Development Commands"
    @echo ""
    @echo "  just test          Run all tests with busted"
    @echo "  just test-watch    Run tests in watch mode"
    @echo "  just lint          Run luacheck linter"
    @echo "  just type-check    Check types with lua-language-server"
    @echo "  just format        Format code with StyLua"
    @echo "  just clean         Clean build artifacts"

# Run all tests with busted
test:
    @echo "Running all tests..."
    @busted tests/unit/*_spec.lua

# Run tests in watch mode
test-watch:
    @echo "Running tests in watch mode..."
    @while true; do \
        clear; \
        busted tests/unit/*_spec.lua; \
        echo "Waiting for changes... (Press Ctrl+C to stop)"; \
        fswatch -r lua tests 2>/dev/null | head -1 || sleep 2; \
    done

# Run luacheck linter
lint:
    @echo "Running luacheck..."
    @luacheck . --config .luacheckrc

# Check types with lua-language-server
type-check:
    @echo "Checking types with lua-language-server..."
    @lua-language-server --check .

# Format code with StyLua
format:
    @echo "Formatting with StyLua..."
    @stylua --check lua plugin tests 2>/dev/null || stylua lua plugin tests

# Clean up build artifacts
clean:
    @echo "Cleaning up..."
    @find . -name "*.swp" -delete
    @find . -name "*.swo" -delete
    @find . -name ".DS_Store" -delete
