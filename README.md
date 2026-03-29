# Midnight Village

A multiplayer social deduction game platform. Players sit together in person and use their phones for secret role actions and voting.

**First game:** One Night Ultimate Werewolf (ONUW) — a single-night variant where roles may swap during the night, then players discuss and vote to find the werewolf.

## Repository Structure

```
midnight-village/
├── backend/         # Django API server (Python, DRF, Channels)
├── frontend/        # Flutter client (web, iOS, Android)
└── docs/            # Developer documentation
```

## Quick Links

- [Backend Quickstart](backend/README.md) — Get the API running
- [Frontend Quickstart](frontend/README.md) — Get the Flutter app running

## First Time Setup

### Prerequisites

- Python 3.12+
- PostgreSQL 14+
- [uv](https://docs.astral.sh/uv/) package manager
- [just](https://just.systems/) command runner
- [Flutter](https://flutter.dev/) SDK (for frontend)

### Backend Setup

```bash
git clone <repo-url>
cd midnight-village

just install        # Install dependencies
cp backend/.env.example backend/.env
# Edit .env with your database credentials

just migrate        # Run migrations
just dev            # Start server at http://localhost:8000
```

### Verify Installation

```bash
curl http://localhost:8000/api/health/
just test
```

## Development

### Quality Checks

Pre-commit hooks run automatically on commit. To run manually:

```bash
just check          # Lint + format check + typecheck
just fix            # Auto-fix lint + format
```

### Running Tests

```bash
just test           # All tests
just test-unit      # Unit tests only
just test-cov       # Tests with coverage report
```

## License

Proprietary — All rights reserved.
