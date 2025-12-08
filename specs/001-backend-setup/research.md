# Research: Backend Project Setup

**Feature Branch**: `001-backend-setup`
**Date**: 2025-12-07

This document consolidates research findings for the backend setup decisions.

---

## 1. Django 5.x with uv Package Manager

### Decision
Use **Django 5.2 LTS** with **uv** as the package manager.

### Rationale
- Django 5.2 is the LTS release (April 2025, supported until April 2028)
- uv is 10-100x faster than pip, written in Rust
- uv provides deterministic builds via `uv.lock`
- `uv run` automatically syncs environment before commands

### Alternatives Considered
- **pip + pip-tools**: Traditional but slower, less integrated
- **Poetry**: Feature-rich but slower than uv, different lockfile format
- **PDM**: Good PEP compliance but less ecosystem adoption than uv

### Configuration

**pyproject.toml structure:**
```toml
[project]
name = "midnight-village-backend"
version = "0.1.0"
description = "Backend for Midnight Village game"
readme = "README.md"
requires-python = ">=3.12"
dependencies = [
    "django>=5.2",
    "djangorestframework>=3.15.2",
    "psycopg>=3.1.8",
    "psycopg-pool>=3.2.0",
    "python-dotenv>=1.0.0",
    "gunicorn>=23.0.0",
]

[dependency-groups]
dev = [
    "pytest>=8.0.0",
    "pytest-django>=4.8.0",
    "pytest-cov>=4.1.0",
    "model-bakery>=1.18.0",
    "pyrefly>=0.44.0",
]
lint = [
    "ruff>=0.8.0",
    "pre-commit>=3.7.0",
    "django-types>=0.19.0",
]

[build-system]
requires = ["hatchling"]
build-backend = "hatchling.build"
```

### Key Commands
```bash
uv sync                  # Install dependencies from lockfile
uv sync --frozen         # Production: use lockfile as-is
uv run python manage.py  # Run with auto-synced environment
uv add <package>         # Add dependency
uv add --dev <package>   # Add dev dependency
```

### Gotchas
- Use **psycopg3** (installed as `psycopg`) not psycopg2
- Always commit `uv.lock` to version control
- Use `uv sync --frozen --no-dev` for production Docker builds

---

## 2. Ruff Configuration for Django

### Decision
Use **Ruff** for both linting and formatting, replacing Black, isort, and Flake8.

### Rationale
- 10-100x faster than alternatives
- Single tool replaces multiple linters/formatters
- Native Django rule set (DJ prefix)
- Active development, strong community

### Alternatives Considered
- **Black + isort + Flake8**: Traditional but requires multiple tools
- **Pylint**: Comprehensive but slow, verbose configuration

### Configuration

**ruff.toml:**
```toml
line-length = 88
indent-width = 4
target-version = "py312"

exclude = [
    ".git",
    ".venv",
    ".ruff_cache",
    "__pycache__",
    "migrations",
    "staticfiles",
]

[lint]
select = [
    "E4", "E7", "E9",  # pycodestyle errors
    "F",               # Pyflakes
    "I",               # isort
    "N",               # pep8-naming
    "UP",              # pyupgrade
    "B",               # flake8-bugbear
    "A",               # flake8-builtins
    "DJ",              # flake8-django
    "S",               # flake8-bandit (security)
    "C4",              # flake8-comprehensions
    "T20",             # flake8-print
    "RUF",             # Ruff-specific
]

ignore = [
    "E501",  # Line too long (handled by formatter)
    "A003",  # Class attribute shadows builtin (Django uses 'id')
]

[lint.per-file-ignores]
"__init__.py" = ["F401"]
"**/migrations/*.py" = ["E501", "DJ"]
"**/settings/*.py" = ["F401", "F403"]
"**/tests/*.py" = ["S101"]

[lint.isort]
known-first-party = ["apps", "config"]
section-order = ["future", "standard-library", "django", "third-party", "first-party", "local-folder"]

[lint.isort.sections]
django = ["django"]

[format]
quote-style = "double"
indent-style = "space"
```

### Django-Specific Rules (DJ)
- **DJ001**: Avoid nullable CharField/TextField
- **DJ006**: Don't use `exclude` with ModelForm
- **DJ008**: Model must define `__str__`
- **DJ012**: Model field ordering

---

## 3. Pyrefly Type Checking

### Decision
Use **Pyrefly** (Meta's new type checker) with **django-types** stubs.

### Rationale
- Real tool from Meta, released May 2025, Beta since November 2025
- 14x faster than mypy/pyright
- Experimental Django support built-in (no plugin required)
- Aligns with "2025 best practices" goal in spec

### Alternatives Considered
- **mypy + django-stubs**: More mature but slower, requires plugin
- **pyright**: Fast but less Django-specific support
- **pytype**: Google's checker but less ecosystem adoption

### Configuration

**pyproject.toml:**
```toml
[tool.pyrefly]
python-version = "3.12"
search-path = ["."]
untyped-def-behavior = "check"

[tool.pyrefly.errors]
bad-assignment = true
bad-return = true
missing-type-annotation = true
```

### Dependencies
```bash
uv add --dev pyrefly django-types
```

### Notes
- Pyrefly prefers `django-types` over `django-stubs`
- Django support is experimental but functional for common patterns
- No plugin required - Django support is built-in

---

## 4. Django Split Settings Pattern

### Decision
Use **settings package** with base.py + environment-specific overrides.

### Rationale
- Clean separation of concerns
- Environment-specific security settings
- Easy to manage secrets per environment
- Standard Django community pattern

### Alternatives Considered
- **django-configurations**: Class-based, more complex
- **django-environ**: Good but adds dependency, python-dotenv simpler
- **Single settings.py with conditionals**: Becomes unwieldy

### Structure
```
config/
├── __init__.py
├── settings/
│   ├── __init__.py
│   ├── base.py          # Shared settings
│   ├── development.py   # Local dev
│   ├── staging.py       # Staging
│   └── production.py    # Production
├── urls.py
├── wsgi.py
└── asgi.py
```

### Base Settings (base.py)
Contains environment-agnostic settings:
- INSTALLED_APPS
- MIDDLEWARE
- TEMPLATES
- ROOT_URLCONF
- AUTH_PASSWORD_VALIDATORS
- LANGUAGE_CODE, TIME_ZONE
- STATIC_URL, STATIC_ROOT

### Environment-Specific (development.py example)
```python
from .base import *
import os
from dotenv import load_dotenv

load_dotenv()

SECRET_KEY = os.environ.get("SECRET_KEY", "dev-secret-key-change-in-production")
DEBUG = True
ALLOWED_HOSTS = ["localhost", "127.0.0.1"]

DATABASES = {
    "default": {
        "ENGINE": "django.db.backends.postgresql",
        "NAME": os.environ.get("DB_NAME", "midnight_village_dev"),
        "USER": os.environ.get("DB_USER", "postgres"),
        "PASSWORD": os.environ.get("DB_PASSWORD", "postgres"),
        "HOST": os.environ.get("DB_HOST", "localhost"),
        "PORT": os.environ.get("DB_PORT", "5432"),
    }
}
```

### Selection
```bash
export DJANGO_SETTINGS_MODULE=config.settings.development
```

---

## 5. Custom User Model

### Decision
Create custom User model extending **AbstractUser** in a `core` app from project start.

### Rationale
- Changing AUTH_USER_MODEL after migrations is extremely difficult
- AbstractUser provides all built-in fields and methods
- Future flexibility for game-specific fields
- Django official recommendation

### Alternatives Considered
- **AbstractBaseUser**: More control but more boilerplate
- **Default User**: Cannot be changed later without pain

### Model Definition
```python
# apps/core/models.py
from django.contrib.auth.models import AbstractUser
from django.db import models

class User(AbstractUser):
    """Custom User model for Midnight Village."""

    email = models.EmailField(unique=True)
    display_name = models.CharField(max_length=50, blank=True)
    created_at = models.DateTimeField(auto_now_add=True)
    updated_at = models.DateTimeField(auto_now=True)

    class Meta:
        db_table = "users"

    def __str__(self):
        return self.username
```

### Settings
```python
AUTH_USER_MODEL = "core.User"
```

### Critical Timing
1. Create core app with User model
2. Add to INSTALLED_APPS
3. Set AUTH_USER_MODEL
4. THEN run first migration

### Code References
- In models: Use `settings.AUTH_USER_MODEL` for ForeignKey
- In code: Use `get_user_model()` for direct access
- Never import default User from `django.contrib.auth.models`

---

## 6. pytest-django Setup

### Decision
Use **pytest + pytest-django** with **model_bakery** for test factories.

### Rationale
- pytest is more Pythonic than unittest
- pytest-django provides excellent Django integration
- model_bakery is simpler than Factory Boy for most cases
- Aligns with constitution test organization requirements

### Alternatives Considered
- **unittest**: Django default but verbose
- **Factory Boy**: More control but more boilerplate

### Configuration

**pyproject.toml:**
```toml
[tool.pytest.ini_options]
DJANGO_SETTINGS_MODULE = "config.settings.test"
python_files = ["test_*.py", "*_test.py"]
addopts = [
    "-v",
    "--strict-markers",
    "--nomigrations",
    "--reuse-db",
    "--cov=apps",
    "--cov-report=term-missing:skip-covered",
    "--cov-report=html",
    "--cov-report=xml",
    "--no-cov-on-fail",
]
testpaths = ["tests"]
markers = [
    "unit: Unit tests (fast, isolated)",
    "integration: Integration tests (slower, multiple components)",
    "contract: Contract tests (API/service boundaries)",
]

[tool.coverage.run]
source = ["apps"]
omit = [
    "*/migrations/*",
    "*/tests/*",
    "*/__init__.py",
]
branch = true

[tool.coverage.report]
precision = 2
show_missing = true
exclude_lines = [
    "pragma: no cover",
    "def __repr__",
    "raise NotImplementedError",
    "if TYPE_CHECKING:",
]
```

### Key Fixtures
- `@pytest.mark.django_db` - Enable database access
- `db` fixture - For fixtures needing database
- `client` fixture - Django test client
- `admin_client` fixture - Pre-authenticated admin

### Test Organization (per constitution)
```
tests/
├── conftest.py          # Shared fixtures
├── unit/                # Fast, isolated tests
│   └── core/
├── integration/         # Multi-component tests
│   └── core/
└── contract/            # API contract tests
    └── api/
```

### Running Tests
```bash
pytest                   # All tests
pytest -m unit           # Unit tests only
pytest -m integration    # Integration tests only
pytest --cov=apps        # With coverage
```

---

## Pre-commit Configuration

### Decision
Use **pre-commit** with Ruff and django-upgrade hooks.

### Configuration

**.pre-commit-config.yaml:**
```yaml
repos:
  - repo: https://github.com/adamchainz/django-upgrade
    rev: "1.21.0"
    hooks:
      - id: django-upgrade
        args: [--target-version, "5.2"]

  - repo: https://github.com/astral-sh/ruff-pre-commit
    rev: v0.8.4
    hooks:
      - id: ruff
        args: [--fix, --exit-non-zero-on-fix]
      - id: ruff-format
```

### Installation
```bash
uv add --dev pre-commit
pre-commit install
pre-commit run --all-files  # Initial run
```

---

## Summary of Technology Choices

| Category | Choice | Version |
|----------|--------|---------|
| Python | Python | 3.12 |
| Framework | Django | 5.2 LTS |
| API Framework | Django REST Framework | 3.15.2+ |
| Database | PostgreSQL + psycopg3 | 14+ |
| Package Manager | uv | latest |
| Linting/Formatting | Ruff | 0.8+ |
| Type Checking | Pyrefly | 0.44+ |
| Testing | pytest + pytest-django | 8.0+ |
| Test Factories | model_bakery | 1.18+ |
| Pre-commit | pre-commit | 3.7+ |
| Env Variables | python-dotenv | 1.0+ |
