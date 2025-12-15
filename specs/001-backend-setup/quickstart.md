# Quickstart: Backend Development

## Prerequisites

- Python 3.12+
- PostgreSQL 14+
- [uv](https://docs.astral.sh/uv/) package manager

## Setup

```bash
# Navigate to backend
cd backend

# Install dependencies (all groups: dev, lint)
just install

# Copy environment template
cp .env.example .env
# Edit .env with your database credentials (see note below)

# Run migrations
just migrate

# Create superuser (optional)
just superuser

# Start development server
just dev
```

## Common Commands

```bash
# Run tests
just test

# Run tests with coverage
just test-cov

# Lint code
just lint

# Format code
just format

# Type check
just typecheck

# Run all quality checks
just check
```

## Project Structure

```
backend/
├── config/              # Django project configuration
│   └── settings/        # Environment-specific settings
├── apps/                # Django applications
│   └── core/            # Core app (User model, health check)
└── tests/               # Test suite
    ├── unit/
    ├── integration/
    └── contract/
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
