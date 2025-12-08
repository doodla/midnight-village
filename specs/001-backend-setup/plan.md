# Implementation Plan: Backend Project Setup

**Branch**: `001-backend-setup` | **Date**: 2025-12-07 | **Spec**: [spec.md](./spec.md)
**Input**: Feature specification from `/specs/001-backend-setup/spec.md`

**Note**: This template is filled in by the `/speckit.plan` command. See `.specify/templates/commands/plan.md` for the execution workflow.

## Summary

Initialize a production-ready Django backend project within the monorepo using 2025 best practices. The setup includes a complete project scaffold with Django REST Framework, custom User model in a core app, environment-based settings, pytest testing, Ruff linting/formatting, Pyrefly type checking, pre-commit hooks, and Justfile task orchestration. The project will serve as the foundation for the Midnight Village game backend.

## Technical Context

**Language/Version**: Python 3.12 (per spec clarification)
**Primary Dependencies**: Django 5.x, Django REST Framework, python-dotenv
**Storage**: PostgreSQL (all environments)
**Testing**: pytest + pytest-django (per spec FR-005)
**Target Platform**: Linux server (production), macOS/Linux (development)
**Project Type**: web (backend component of larger system)
**Performance Goals**: API <100ms p95, WebSocket <50ms p95 (per constitution VIII)
**Constraints**: Development server auto-reload <2s (per SC-007)
**Scale/Scope**: 100 concurrent games / 800 players per instance (per constitution VIII)

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Principle | Gate | Status | Notes |
|-----------|------|--------|-------|
| I. Test-First Development | pytest configured with unit/integration/contract dirs | PASS | FR-005 requires pytest-django with fixtures |
| I. Quality Gates | 80% coverage configured, CI integration ready | PASS | Initial scaffold will have example tests |
| II. Simplicity & YAGNI | No over-engineering in scaffold | PASS | Only creating required structure per spec |
| III. Type Safety | Pyrefly configured with strict mode | PASS | FR-007 requires Pyrefly type checking |
| VIII. Performance Budgets | Benchmarks deferred to implementation | N/A | Scaffold phase, no runtime code yet |

**Technology Stack Compliance**:
- Backend: Django (Python 3.12+) - COMPLIANT with constitution
- Database: PostgreSQL - COMPLIANT with constitution
- Testing: pytest - COMPLIANT with constitution

**Pre-Phase 0 Gate**: PASS - All applicable principles satisfied by spec requirements

**Post-Phase 1 Gate**: PASS - Design adheres to all constitutional principles:
- Minimal custom User model (`class User(AbstractUser): pass`) follows YAGNI
- Test structure matches constitution requirements (unit/integration/contract)
- Single health check endpoint - no scope creep

## Project Structure

### Documentation (this feature)

```text
specs/001-backend-setup/
├── plan.md              # This file (/speckit.plan command output)
├── research.md          # Phase 0 output (/speckit.plan command)
├── data-model.md        # Phase 1 output (/speckit.plan command)
├── quickstart.md        # Phase 1 output (/speckit.plan command)
├── contracts/           # Phase 1 output (/speckit.plan command)
└── tasks.md             # Phase 2 output (/speckit.tasks command - NOT created by /speckit.plan)
```

### Source Code (repository root)

```text
backend/
├── pyproject.toml           # Project metadata, dependencies (uv)
├── uv.lock                  # Lockfile for deterministic deps
├── .python-version          # Python 3.12
├── .env.example             # Environment template
├── justfile                 # Backend-specific tasks
├── pytest.ini               # pytest configuration
├── ruff.toml                # Ruff linting/formatting config
├── pyproject.toml           # Also contains pyrefly config
├── .pre-commit-config.yaml  # Pre-commit hooks
│
├── config/                  # Django project configuration
│   ├── __init__.py
│   ├── settings/
│   │   ├── __init__.py
│   │   ├── base.py          # Common settings
│   │   ├── development.py   # Dev-specific
│   │   ├── staging.py       # Staging-specific
│   │   └── production.py    # Production-specific
│   ├── urls.py              # Root URL configuration
│   ├── wsgi.py              # WSGI entry point
│   └── asgi.py              # ASGI entry point (for future Channels)
│
├── apps/                    # Django applications
│   └── core/                # Core app (custom User, health check)
│       ├── __init__.py
│       ├── admin.py
│       ├── apps.py
│       ├── models.py        # Custom User model
│       ├── views.py         # Health check endpoint
│       ├── urls.py
│       ├── serializers.py
│       └── migrations/
│
├── tests/                   # Test suite (mirrors constitution structure)
│   ├── conftest.py          # Shared fixtures
│   ├── unit/
│   │   └── core/
│   ├── integration/
│   │   └── core/
│   └── contract/
│       └── api/
│
└── manage.py                # Django management script

# Root level
justfile                     # Root justfile (delegates to backend/)
```

**Structure Decision**: Web application structure with `backend/` directory. Django project uses `config/` for settings (cleaner than default project-named folder) and `apps/` for Django applications. Test structure follows constitution requirement for unit/integration/contract separation.

## Complexity Tracking

> **Fill ONLY if Constitution Check has violations that must be justified**

No violations - design follows all constitutional principles.
