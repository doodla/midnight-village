# Root Justfile for Midnight Village Monorepo
# Run `just` or `just --list` to see available commands

# Use bash with strict error handling
set shell := ["bash", "-uc"]

# Backend justfile delegation helper
backend_just := "just --justfile backend/justfile --working-directory backend"

# Default recipe: show help
default:
    @just --list

# --- Setup ---

# Install backend dependencies
install:
    {{backend_just}} install

# --- Development ---

# Run backend development server
dev:
    {{backend_just}} dev

# Run backend on specific port
serve port="8000":
    {{backend_just}} serve {{port}}

# Run Django management command
manage *args:
    {{backend_just}} manage {{args}}

# --- Database ---

# Run backend migrations
migrate:
    {{backend_just}} migrate

# Create backend migrations
makemigrations *args:
    {{backend_just}} makemigrations {{args}}

# --- Testing ---

# Run backend tests
test *args:
    {{backend_just}} test {{args}}

# Run backend tests with coverage
test-cov:
    {{backend_just}} test-cov

# Run unit tests only
test-unit:
    {{backend_just}} test-unit

# Run integration tests only
test-integration:
    {{backend_just}} test-integration

# Run contract tests only
test-contract:
    {{backend_just}} test-contract

# --- Code Quality ---

# Run backend linting
lint:
    {{backend_just}} lint

# Run backend linting with auto-fix
lint-fix:
    {{backend_just}} lint-fix

# Format backend code
format:
    {{backend_just}} format

# Check backend formatting
format-check:
    {{backend_just}} format-check

# Run backend type checking
typecheck:
    {{backend_just}} typecheck

# Run all backend quality checks
check:
    {{backend_just}} check

# Fix all auto-fixable issues
fix:
    {{backend_just}} fix

# --- Utilities ---

# Show backend dependencies tree
deps:
    {{backend_just}} deps

# Shell into Django environment
shell:
    {{backend_just}} shell

# Clean up cache files
clean:
    {{backend_just}} clean
