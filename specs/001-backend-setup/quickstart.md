# Quickstart: Backend Development

## Prerequisites

- Python 3.12+
- PostgreSQL 14+
- [uv](https://docs.astral.sh/uv/) package manager

## Setup

```bash
# Navigate to backend
cd backend

# Install dependencies
uv sync

# Copy environment template
cp .env.example .env
# Edit .env with your database credentials

# Run migrations
uv run python manage.py migrate

# Create superuser (optional)
uv run python manage.py createsuperuser

# Start development server
uv run python manage.py runserver
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
| `DATABASE_URL` | PostgreSQL connection string | - |
| `ALLOWED_HOSTS` | Comma-separated host list | `localhost` |
