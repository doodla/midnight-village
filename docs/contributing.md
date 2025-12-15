# Contributing Guidelines

This document describes how to contribute to the Midnight Village backend.

## Development Setup

1. **Prerequisites**:
   - Python 3.12+
   - PostgreSQL 14+
   - [uv](https://docs.astral.sh/uv/) package manager
   - [just](https://just.systems/) command runner

2. **Clone and install**:
   ```bash
   git clone <repo-url>
   cd midnight-village
   just install
   ```

3. **Configure environment**:
   ```bash
   cp backend/.env.example backend/.env
   # Edit .env with your database credentials
   ```

4. **Run migrations**:
   ```bash
   just migrate
   ```

5. **Start the server**:
   ```bash
   just dev
   ```

## Code Quality

### Before Committing

Run all quality checks using justfile commands:

```bash
# Run all checks (lint, format check, typecheck)
just check

# Fix auto-fixable issues (lint + format)
just fix

# Run tests
just test
```

Or use the pre-commit hooks (recommended):

```bash
# Install hooks (one time)
# Run from repository root (midnight-village/), NOT from backend/
cd midnight-village
uv run --directory backend pre-commit install

# Hooks run automatically on every git commit
# To run manually from repo root:
uv run --directory backend pre-commit run --all-files
```

**Important**: Pre-commit config lives at the monorepo root (`/.pre-commit-config.yaml`), not inside `backend/`. The hooks are scoped to only run on `backend/` files using the `files: ^backend/` pattern. Always run pre-commit commands from the repository root.

### Code Style

- **Line length**: 88 characters (Ruff default)
- **Quotes**: Double quotes for strings
- **Imports**: Sorted by isort (via Ruff)
- **Type hints**: Required for function signatures

### Testing

Write tests for all new functionality:

```bash
# Run all tests
just test

# Run with coverage
just test-cov

# Run specific test file
just test tests/integration/core/test_models.py

# Run tests by marker
just test-unit
just test-integration
just test-contract
```

Test organization:
- `tests/unit/` - Fast, isolated tests
- `tests/integration/` - Multi-component tests
- `tests/contract/` - API contract tests

## Git Workflow

### Branch Naming

```
feature/{id}-short-description
fix/{id}-short-description
docs/{description}
```

### Commit Messages

Use descriptive commit messages:

```
feat: add game creation endpoint

- Add GameSerializer for validation
- Add CreateGameView with POST handler
- Add URL pattern at /api/games/
- Add integration tests
```

Prefixes:
- `feat:` - New feature
- `fix:` - Bug fix
- `docs:` - Documentation
- `refactor:` - Code restructuring
- `test:` - Test additions/changes
- `chore:` - Build/tooling changes

### Pull Requests

1. Create a feature branch from `main`
2. Make changes and commit
3. Push and create a pull request
4. Ensure all checks pass
5. Request review

## Adding New Features

### New Django App

1. Create the app structure:
   ```bash
   just manage startapp myapp apps/myapp
   ```

2. Update `apps/myapp/apps.py` with correct name:
   ```python
   name = "apps.myapp"
   ```

3. Add to `INSTALLED_APPS` in `config/settings/base.py`

4. Create test directories:
   ```bash
   mkdir -p backend/tests/unit/myapp backend/tests/integration/myapp
   touch backend/tests/unit/myapp/__init__.py backend/tests/integration/myapp/__init__.py
   ```

### New API Endpoint

1. Create view in `apps/{app}/views.py`
2. Add URL pattern in `apps/{app}/urls.py`
3. Wire into `config/urls.py`
4. Write integration tests in `tests/integration/{app}/`
5. Update API documentation if needed

### New Model

1. Add model to `apps/{app}/models.py`
2. Create and apply migrations:
   ```bash
   just makemigrations
   just migrate
   ```
3. Register in admin (`apps/{app}/admin.py`)
4. Write integration tests in `tests/integration/{app}/` (model tests use the database)

## Troubleshooting

### Port Already in Use

```bash
# Find and kill process using port 8000
lsof -ti:8000 | xargs kill -9

# Or run on a different port (from backend directory)
cd backend && just serve 8001
```

### PostgreSQL Connection Failed

```bash
# Check PostgreSQL is running
pg_isready

# Create database if missing
createdb midnight_village_dev

# Verify connection
psql -U postgres -d midnight_village_dev -c "SELECT 1"

# Check your .env has correct credentials:
# DB_NAME=midnight_village_dev
# DB_USER=postgres
# DB_PASSWORD=your_password
# DB_HOST=localhost
# DB_PORT=5432
```

### Database Issues

```bash
# Reset database (development only)
dropdb midnight_village_dev
createdb midnight_village_dev
just migrate
```

### Migration Conflicts

```bash
# Show migration status
just manage showmigrations

# Merge migrations if needed
just makemigrations --merge
```

### Pre-commit Hook Failures

```bash
# Update hooks to latest versions
uv run --directory backend pre-commit autoupdate

# Clear cache and retry
uv run --directory backend pre-commit clean
uv run --directory backend pre-commit run --all-files

# Skip hooks temporarily (not recommended)
git commit --no-verify -m "message"
```

### Dependency Issues

```bash
# Reinstall all dependencies (from backend directory)
cd backend
rm -rf .venv uv.lock
just install
```

### Environment Variable Issues

```bash
# Verify .env file exists
ls -la .env

# Check required variables are set
cat .env | grep -E "^(SECRET_KEY|DB_)"

# Common issues:
# - Missing .env file: cp .env.example .env
# - Spaces around '=': Use DB_NAME=value not DB_NAME = value
# - Quotes: Usually not needed, but use if value has spaces
```
