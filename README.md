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
- [Feature Specs](specs/) - Feature specifications and design documents

## First Time Setup

### Prerequisites

- Python 3.12+
- PostgreSQL 14+
- [uv](https://docs.astral.sh/uv/) package manager
- [just](https://just.systems/) command runner

### Backend Setup

```bash
# Clone the repository
git clone <repo-url>
cd midnight-village

# Install dependencies (from repo root)
just install

# Configure environment
cp backend/.env.example backend/.env
# Edit .env with your database credentials

# Run migrations and start server
just migrate
just dev
```

The API will be available at http://localhost:8000

### Verify Installation

```bash
# Health check
curl http://localhost:8000/api/health/

# Run tests
just test
```

## Development

### Quality Checks

Pre-commit hooks run automatically on commit. To run manually:

```bash
# Run all quality checks (lint, format check, typecheck)
just check

# Fix auto-fixable issues
just fix
```

### Running Tests

```bash
just test              # All tests
just test-unit         # Unit tests only
just test-integration  # Integration tests only
just test-cov          # Tests with coverage report
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
