# Midnight Village Backend

Backend API server for the Midnight Village game, built with Django and Django REST Framework.

## Prerequisites

- Python 3.12+
- PostgreSQL 14+
- [uv](https://docs.astral.sh/uv/) package manager

## Quickstart

```bash
# Navigate to backend directory
cd backend

# Install dependencies
uv sync

# Copy environment template and configure
cp .env.example .env
# Edit .env with your database credentials

# Run migrations
uv run python manage.py migrate

# Create superuser (optional)
uv run python manage.py createsuperuser

# Start development server
uv run python manage.py runserver
```

The server will be available at http://localhost:8000

## Common Commands

```bash
# Run development server
uv run python manage.py runserver

# Run tests
uv run pytest

# Run tests with coverage
uv run pytest --cov

# Format code
uv run ruff format .

# Lint code
uv run ruff check . --fix

# Type check
uv run pyrefly check .

# Run all quality checks (from repo root)
uv run --directory backend pre-commit run --all-files
```

## Project Structure

```
backend/
├── config/              # Django project configuration
│   └── settings/        # Environment-specific settings
├── apps/                # Django applications
│   └── core/            # Core app (User model, health check)
└── tests/               # Test suite
    ├── unit/            # Fast, isolated tests
    ├── integration/     # Multi-component tests
    └── contract/        # API contract tests
```

## Environment Variables

| Variable | Description | Default |
|----------|-------------|---------|
| `SECRET_KEY` | Django secret key | (required in production) |
| `DEBUG` | Debug mode | `False` |
| `DATABASE_URL` | PostgreSQL connection string | - |
| `DB_NAME` | Database name | `midnight_village_dev` |
| `DB_USER` | Database user | `postgres` |
| `DB_PASSWORD` | Database password | `postgres` |
| `DB_HOST` | Database host | `localhost` |
| `DB_PORT` | Database port | `5432` |
| `ALLOWED_HOSTS` | Comma-separated host list | `localhost` |

## API Endpoints

| Endpoint | Method | Description |
|----------|--------|-------------|
| `/api/health/` | GET | Health check (no auth) |
| `/admin/` | GET | Django admin interface |

## Documentation

- [Architecture](../docs/architecture.md) - Project structure and patterns
- [API Patterns](../docs/api-patterns.md) - API conventions and examples
- [Contributing](../docs/contributing.md) - Development workflow

## Testing

Tests are organized by type:

```bash
# Run all tests
uv run pytest

# Run only unit tests
uv run pytest -m unit

# Run only integration tests
uv run pytest -m integration

# Run with verbose output
uv run pytest -v

# Run specific test file
uv run pytest tests/unit/core/test_models.py
```

## License

Proprietary - All rights reserved.
