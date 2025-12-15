# Midnight Village Backend

Backend API server for the Midnight Village game, built with Django and Django REST Framework.

## Prerequisites

- Python 3.12+
- PostgreSQL 14+
- [uv](https://docs.astral.sh/uv/) package manager
- [just](https://just.systems/) command runner

## Quickstart

```bash
# Navigate to backend directory
cd backend

# Install dependencies
just install

# Copy environment template and configure
cp .env.example .env
# Edit .env with your database credentials

# Run migrations
just migrate

# Create superuser (optional)
just superuser

# Start development server
just dev
```

The server will be available at http://localhost:8000

## Common Commands

```bash
# Run development server
just dev

# Run on specific port
just serve 8001

# Run tests
just test

# Run tests with coverage
just test-cov

# Run all quality checks (lint, format, typecheck)
just check

# Fix auto-fixable issues
just fix

# Individual commands
just lint          # Lint code
just format        # Format code
just typecheck     # Type check
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
| `DB_NAME` | Database name | `midnight_village_dev` |
| `DB_USER` | Database user | empty (see note) |
| `DB_PASSWORD` | Database password | empty (see note) |
| `DB_HOST` | Database host | `localhost` |
| `DB_PORT` | Database port | `5432` |
| `ALLOWED_HOSTS` | Comma-separated host list | `localhost` |

**Note on database credentials**: On macOS with Homebrew PostgreSQL, leave `DB_USER` and `DB_PASSWORD` empty to use your system user. On Linux or Docker, set them to `postgres` or your configured credentials.

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
just test

# Run by marker
just test-unit         # Unit tests only
just test-integration  # Integration tests only
just test-contract     # Contract tests only

# Run with verbose output
just test -v

# Run specific test file
just test tests/integration/core/test_models.py
```

## License

Proprietary - All rights reserved.
