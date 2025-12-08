# Midnight Village

A multiplayer social deduction game built with Django.

## Repository Structure

```
midnight-village/
├── backend/         # Django API server
├── docs/            # Developer documentation
└── specs/           # Feature specifications
```

## Quick Links

- [Backend Quickstart](backend/README.md) - Get the API running in 5 minutes
- [Architecture](docs/architecture.md) - System design and patterns
- [API Patterns](docs/api-patterns.md) - API conventions
- [Contributing](docs/contributing.md) - Development workflow

## First Time Setup

### Prerequisites

- Python 3.12+
- PostgreSQL 14+
- [uv](https://docs.astral.sh/uv/) package manager

### Backend Setup

```bash
# Clone the repository
git clone <repo-url>
cd midnight-village

# Navigate to backend and install dependencies
cd backend
uv sync

# Configure environment
cp .env.example .env
# Edit .env with your database credentials

# Run migrations and start server
uv run python manage.py migrate
uv run python manage.py runserver
```

The API will be available at http://localhost:8000

### Verify Installation

```bash
# Health check
curl http://localhost:8000/api/health/

# Run tests
uv run pytest
```

## Development

### Quality Checks

Pre-commit hooks run automatically on commit. To run manually:

```bash
# From repository root
uv run --directory backend pre-commit run --all-files
```

### Running Tests

```bash
cd backend
uv run pytest              # All tests
uv run pytest -m unit      # Unit tests only
uv run pytest -m integration  # Integration tests only
```

## Project Status

- [x] Backend project scaffold
- [x] Custom User model
- [x] Health check endpoint
- [x] Quality tooling (Ruff, Pyrefly, pre-commit)
- [ ] Game logic implementation
- [ ] Frontend client

## License

Proprietary - All rights reserved.
