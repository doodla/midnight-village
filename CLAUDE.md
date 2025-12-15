# midnight-village Development Guidelines

## Technologies

- Python 3.12 + Django 5.x, Django REST Framework, python-dotenv

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

Python 3.12: Follow standard conventions
