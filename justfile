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

# Re-record contract_samples/ from the real server (see backend/CLAUDE.md)
samples:
    {{backend_just}} samples

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

# Boot the harness backend, then run the end-to-end harness (API + UI runners)
# against it and tear it down (needs Postgres; see docs/dev/debug-harness/)
test-harness:
    {{frontend_just}} test-harness

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

# --- Frontend ---

# Frontend justfile delegation helper
frontend_just := "just --justfile frontend/justfile --working-directory frontend"

# Run Flutter app (web)
flutter-run:
    {{frontend_just}} run

# Run Flutter code generation
flutter-build-runner:
    {{frontend_just}} gen

# Run Flutter code generation (watch mode)
flutter-watch:
    {{frontend_just}} watch

# Run Flutter tests
flutter-test:
    {{frontend_just}} test

# Analyze Flutter code
flutter-analyze:
    {{frontend_just}} analyze

# Render every app screen to PNG next to its mock (see frontend/CLAUDE.md)
screens *args:
    {{frontend_just}} screens {{args}}

# Run Flutter integration tests on Chrome
# Uses flutter drive because flutter test does not support web devices
flutter-test-integration:
    {{frontend_just}} test-integration

# Run Flutter integration tests in headless mode (CI)
flutter-test-integration-ci:
    {{frontend_just}} test-integration-ci
