# midnight-village Development Guidelines

Auto-generated from all feature plans. Last updated: 2025-12-07

## Active Technologies

- Python 3.12 (per spec clarification) + Django 5.x, Django REST Framework, python-dotenv (001-backend-setup)

## Project Structure

```text
backend/
frontend/
tests/
```

## Commands

```bash
# From repository root (delegates to backend)
just test          # Run tests
just check         # Run quality checks (lint, format, typecheck)
just dev           # Run development server

# Or from backend/ directory
cd backend
just test          # Run tests
just lint          # Lint with Ruff
just format        # Format with Ruff
just typecheck     # Type check with Pyrefly
```

## Code Style

Python 3.12 (per spec clarification): Follow standard conventions

## Recent Changes

- 001-backend-setup: Added Python 3.12 (per spec clarification) + Django 5.x, Django REST Framework, python-dotenv

<!-- MANUAL ADDITIONS START -->
- When getting a code review, if there are doc file changes, also request a review from docs-architect
<!-- MANUAL ADDITIONS END -->