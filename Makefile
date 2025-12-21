.PHONY: help test test-watch lint type-check format clean

help:
	@echo "Linear.nvim Development Commands"
	@echo ""
	@echo "  make test          Run all tests with busted"
	@echo "  make test-watch    Run tests in watch mode"
	@echo "  make lint          Run luacheck linter"
	@echo "  make type-check    Check types with lua-language-server"
	@echo "  make format        Format code with StyLua"
	@echo "  make clean         Clean build artifacts"

test:
	@echo "Running all tests..."
	@busted tests/unit/*_spec.lua

test-watch:
	@echo "Running tests in watch mode..."
	@while true; do \
		clear; \
		busted; \
		echo "Waiting for changes... (Press Ctrl+C to stop)"; \
		fswatch -r lua tests 2>/dev/null | head -1 || sleep 2; \
	done

lint:
	@echo "Running luacheck..."
	@luacheck . --config .luacheckrc

type-check:
	@echo "Checking types with lua-language-server..."
	@lua-language-server --check .

format:
	@echo "Formatting with StyLua..."
	@stylua --check lua plugin tests 2>/dev/null || stylua lua plugin tests

clean:
	@echo "Cleaning up..."
	@find . -name "*.swp" -delete
	@find . -name "*.swo" -delete
	@find . -name ".DS_Store" -delete

.DEFAULT_GOAL := help
