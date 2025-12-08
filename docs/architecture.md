# Project Architecture

This document describes the backend project structure and architectural patterns.

## System Overview

```
┌─────────────────────────────────────────────────────────────┐
│                      Midnight Village                        │
├─────────────────────────────────────────────────────────────┤
│                                                              │
│  ┌──────────────┐      ┌──────────────┐      ┌───────────┐  │
│  │    Client    │ ──── │  Backend API │ ──── │ PostgreSQL│  │
│  │   (Future)   │ HTTP │   (Django)   │      │    DB     │  │
│  └──────────────┘      └──────────────┘      └───────────┘  │
│                              │                               │
│                              ▼                               │
│                     ┌────────────────┐                       │
│                     │   apps.core    │                       │
│                     ├────────────────┤                       │
│                     │ • User Model   │                       │
│                     │ • Health Check │                       │
│                     │ • Exceptions   │                       │
│                     └────────────────┘                       │
│                                                              │
└─────────────────────────────────────────────────────────────┘
```

## Directory Structure

```
backend/
├── config/                  # Django project configuration
│   ├── __init__.py
│   ├── settings/            # Environment-specific settings
│   │   ├── __init__.py
│   │   ├── base.py          # Common settings
│   │   ├── development.py   # Local development
│   │   ├── staging.py       # Staging environment
│   │   ├── production.py    # Production environment
│   │   └── test.py          # Test settings
│   ├── urls.py              # Root URL configuration
│   ├── wsgi.py              # WSGI entry point
│   └── asgi.py              # ASGI entry point
│
├── apps/                    # Django applications
│   └── core/                # Core app (User model, health check)
│       ├── __init__.py
│       ├── admin.py         # Admin configuration
│       ├── apps.py          # App configuration
│       ├── exceptions.py    # Custom exception handlers
│       ├── models.py        # Custom User model
│       ├── urls.py          # App URL patterns
│       ├── views.py         # Views (health check)
│       └── migrations/      # Database migrations
│
├── tests/                   # Test suite
│   ├── conftest.py          # Shared pytest fixtures
│   ├── unit/                # Fast, isolated unit tests
│   │   └── core/
│   ├── integration/         # Multi-component tests
│   │   └── core/
│   └── contract/            # API contract tests
│       └── api/
│
├── manage.py                # Django management script
├── pyproject.toml           # Project configuration and dependencies
└── uv.lock                  # Lockfile for deterministic builds

# Monorepo root
docs/                        # Developer documentation
├── architecture.md          # This file
├── api-patterns.md          # API conventions
└── contributing.md          # Development workflow
.pre-commit-config.yaml      # Pre-commit hooks
```

## Django Apps

### Core App (`apps.core`)

The core app provides foundational functionality:

- **Custom User Model**: Extends `AbstractUser` for future extensibility
- **Health Check Endpoint**: `GET /api/health/` for monitoring
- **Exception Handling**: Standardized error response format

## Settings Architecture

We use a split settings pattern with environment-specific modules:

| Module | Purpose |
|--------|---------|
| `base.py` | Shared settings (apps, middleware, templates) |
| `development.py` | Debug mode, local database |
| `staging.py` | Near-production settings for testing |
| `production.py` | Security hardening, production database |
| `test.py` | Fast test execution (SQLite, minimal logging) |

### Selecting Settings

```bash
# Development (default)
export DJANGO_SETTINGS_MODULE=config.settings.development

# Production
export DJANGO_SETTINGS_MODULE=config.settings.production

# Testing (set in pyproject.toml)
DJANGO_SETTINGS_MODULE=config.settings.test
```

## Test Organization

Tests follow a three-tier structure per the project constitution:

### Unit Tests (`tests/unit/`)

- Test individual functions and methods in isolation
- Fast execution, no database or external services
- Use mocking for dependencies

### Integration Tests (`tests/integration/`)

- Test multiple components working together
- May use database with fixtures
- Test actual Django request/response cycle

### Contract Tests (`tests/contract/`)

- Verify API contracts match specification
- Test request/response formats
- Ensure backwards compatibility

## Adding New Apps

1. Create the app:
   ```bash
   cd backend
   uv run python manage.py startapp myapp apps/myapp
   ```

2. Update `apps/myapp/apps.py`:
   ```python
   class MyappConfig(AppConfig):
       default_auto_field = "django.db.models.BigAutoField"
       name = "apps.myapp"  # Include 'apps.' prefix
   ```

3. Add to `INSTALLED_APPS` in `config/settings/base.py`:
   ```python
   INSTALLED_APPS = [
       # ...
       "apps.myapp",
   ]
   ```

4. Create test directories:
   ```bash
   mkdir -p tests/unit/myapp tests/integration/myapp
   touch tests/unit/myapp/__init__.py tests/integration/myapp/__init__.py
   ```
