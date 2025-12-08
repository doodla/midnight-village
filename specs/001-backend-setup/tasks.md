# Tasks: Backend Project Setup

**Input**: Design documents from `/specs/001-backend-setup/`
**Prerequisites**: plan.md, spec.md, research.md, data-model.md, contracts/

**Tests**: Not explicitly requested - test tasks omitted per spec.

**Organization**: Tasks grouped by user story for independent implementation.

## Format: `[ID] [P?] [Story] Description`

- **[P]**: Can run in parallel (different files, no dependencies)
- **[Story]**: Which user story this task belongs to (US1, US2, US3, US4)
- Include exact file paths in descriptions

## Path Conventions

Per plan.md, this is a web app with `backend/` structure:
- Backend code: `backend/`
- Django config: `backend/config/`
- Django apps: `backend/apps/`
- Tests: `backend/tests/`

---

## Phase 1: Setup (Shared Infrastructure)

**Purpose**: Create backend directory structure and initialize uv project

- [x] T001 Create backend directory structure per plan.md in backend/
- [x] T002 Initialize uv project with pyproject.toml in backend/pyproject.toml
- [x] T003 Create .python-version file with Python 3.12 in backend/.python-version
- [x] T004 Create .env.example template in backend/.env.example
- [x] T005 Create .gitignore for Python/Django in backend/.gitignore

---

## Phase 2: Foundational (Blocking Prerequisites)

**Purpose**: Django project configuration that MUST be complete before user stories

**CRITICAL**: No user story work can begin until this phase is complete

- [x] T006 Create Django config package structure in backend/config/__init__.py
- [x] T007 [P] Create base settings in backend/config/settings/base.py
- [x] T008 [P] Create development settings in backend/config/settings/development.py
- [x] T009 [P] Create staging settings in backend/config/settings/staging.py
- [x] T010 [P] Create production settings in backend/config/settings/production.py
- [x] T011 Create settings __init__.py in backend/config/settings/__init__.py
- [x] T012 Create root URL configuration in backend/config/urls.py
- [x] T013 [P] Create WSGI entry point in backend/config/wsgi.py
- [x] T014 [P] Create ASGI entry point in backend/config/asgi.py
- [x] T015 Create manage.py script in backend/manage.py
- [x] T016 Create apps package directory in backend/apps/__init__.py
- [x] T017 Create core app via uv run python manage.py startapp core apps/core
- [x] T018 Create custom User model in backend/apps/core/models.py
- [x] T019 Create core app config in backend/apps/core/apps.py
- [x] T020 Register User in admin in backend/apps/core/admin.py
- [x] T021 Run initial migrations with uv run python manage.py makemigrations core
- [x] T022 Run migrate with uv run python manage.py migrate

**Checkpoint**: Django project runs - `uv run python manage.py runserver` works

---

## Phase 3: User Story 1 - Developer Initializes Backend Project (Priority: P1)

**Goal**: Complete project scaffold with all configuration files ready for development

**Independent Test**: Run `uv sync && uv run python manage.py runserver` and verify server starts without errors

### Implementation for User Story 1

- [x] T023 [US1] Create health check view in backend/apps/core/views.py
- [x] T024 [US1] Create error handling utilities in backend/apps/core/exceptions.py
- [x] T025 [US1] Create core app URL patterns in backend/apps/core/urls.py
- [x] T026 [US1] Wire core URLs into root URLconf in backend/config/urls.py
- [x] T027 [US1] Configure logging in backend/config/settings/base.py
- [x] T028 [US1] Configure DRF settings in backend/config/settings/base.py
- [x] T029 [US1] Create test directory structure in backend/tests/
- [x] T030 [P] [US1] Create conftest.py with shared fixtures in backend/tests/conftest.py
- [x] T031 [P] [US1] Create unit test directory in backend/tests/unit/core/
- [x] T032 [P] [US1] Create integration test directory in backend/tests/integration/core/
- [x] T033 [P] [US1] Create contract test directory in backend/tests/contract/api/
- [x] T034 [US1] Add example unit test in backend/tests/unit/core/test_models.py
- [x] T035 [US1] Add example integration test in backend/tests/integration/core/test_health.py
- [x] T036 [US1] Run uv sync to generate lockfile

**Checkpoint**: User Story 1 complete - developer can initialize project and run server

---

## Phase 4: User Story 2 - Developer Understands Project Patterns (Priority: P1)

**Goal**: Documentation explaining Django patterns and conventions for consistent development

**Independent Test**: New developer can read docs and understand how to add an endpoint

### Implementation for User Story 2

- [ ] T037 [P] [US2] Create project structure documentation in backend/docs/architecture.md
- [ ] T038 [P] [US2] Create API patterns documentation in backend/docs/api-patterns.md
- [ ] T039 [P] [US2] Create contribution guidelines in backend/docs/contributing.md
- [ ] T040 [US2] Create backend README with quickstart in backend/README.md

**Checkpoint**: User Story 2 complete - documentation available for developers

---

## Phase 5: User Story 3 - Developer Runs Quality Checks (Priority: P2)

**Goal**: Pre-configured linting, formatting, and type checking tools

**Independent Test**: Introduce intentional violations and verify tools detect them

### Implementation for User Story 3

- [ ] T041 [P] [US3] Create Ruff configuration in backend/ruff.toml
- [ ] T042 [P] [US3] Add Pyrefly configuration to backend/pyproject.toml
- [ ] T043 [P] [US3] Add pytest configuration to backend/pyproject.toml
- [ ] T044 [P] [US3] Add coverage configuration to backend/pyproject.toml
- [ ] T045 [US3] Create pre-commit configuration in backend/.pre-commit-config.yaml
- [ ] T046 [US3] Install pre-commit hooks with uv run pre-commit install
- [ ] T047 [US3] Run pre-commit on all files to validate setup

**Checkpoint**: User Story 3 complete - quality tools catch violations

---

## Phase 6: User Story 4 - Developer Integrates with Monorepo Tooling (Priority: P2)

**Goal**: Justfile integration for monorepo-wide commands

**Independent Test**: Run `just test` from root and backend, verify both work

### Implementation for User Story 4

- [ ] T048 [P] [US4] Create backend justfile in backend/justfile
- [ ] T049 [US4] Create root justfile delegating to backend in justfile
- [ ] T050 [US4] Verify just commands work from both root and backend

**Checkpoint**: User Story 4 complete - monorepo integration works

---

## Phase 7: Polish & Cross-Cutting Concerns

**Purpose**: Final validation and cleanup

- [ ] T051 Run all quality checks with just check
- [ ] T052 Validate quickstart.md instructions work end-to-end
- [ ] T053 Verify development server auto-reload within 2 seconds

---

## Dependencies & Execution Order

### Phase Dependencies

- **Setup (Phase 1)**: No dependencies - start immediately
- **Foundational (Phase 2)**: Depends on Setup completion - BLOCKS all user stories
- **User Story 1 (Phase 3)**: Depends on Foundational (Phase 2)
- **User Story 2 (Phase 4)**: Depends on Foundational (Phase 2) - can parallel with US1
- **User Story 3 (Phase 5)**: Depends on Foundational (Phase 2) - can parallel with US1/US2
- **User Story 4 (Phase 6)**: Depends on Foundational (Phase 2) - can parallel with others
- **Polish (Phase 7)**: Depends on all user stories complete

### User Story Dependencies

- **User Story 1 (P1)**: Core project - no dependencies on other stories
- **User Story 2 (P1)**: Documentation - can parallel with US1
- **User Story 3 (P2)**: Quality tools - can parallel with US1/US2
- **User Story 4 (P2)**: Monorepo integration - can parallel with others

### Within Each User Story

- T006-T022 (Foundational) must complete before any user story
- Models before views (T018 before T023)
- Views before URL wiring (T023 before T025, T026)
- Test structure before test files

### Parallel Opportunities

Setup phase (T001-T005): All sequential (directory creation)

Foundational phase parallel groups:
- Settings files: T007, T008, T009, T010 (all [P])
- Entry points: T013, T014 (all [P])

User Story 1 parallel groups:
- Test directories: T030, T031, T032, T033 (all [P])

User Story 2:
- All docs: T037, T038, T039 (all [P])

User Story 3:
- Config files: T041, T042, T043, T044 (all [P])

---

## Parallel Example: Foundational Phase

```bash
# After T006 completes, launch settings in parallel:
Task: "Create base settings in backend/config/settings/base.py"
Task: "Create development settings in backend/config/settings/development.py"
Task: "Create staging settings in backend/config/settings/staging.py"
Task: "Create production settings in backend/config/settings/production.py"

# Entry points in parallel:
Task: "Create WSGI entry point in backend/config/wsgi.py"
Task: "Create ASGI entry point in backend/config/asgi.py"
```

## Parallel Example: User Story 1

```bash
# Test directories can be created in parallel:
Task: "Create conftest.py with shared fixtures in backend/tests/conftest.py"
Task: "Create unit test directory in backend/tests/unit/core/"
Task: "Create integration test directory in backend/tests/integration/core/"
Task: "Create contract test directory in backend/tests/contract/api/"
```

---

## Implementation Strategy

### MVP First (User Story 1 Only)

1. Complete Phase 1: Setup (T001-T005)
2. Complete Phase 2: Foundational (T006-T022)
3. Complete Phase 3: User Story 1 (T023-T036)
4. **STOP and VALIDATE**: Run server, run tests
5. Deploy/demo if ready - functional Django project!

### Incremental Delivery

1. Setup + Foundational → Django runs
2. User Story 1 → Tests pass, health endpoint works → MVP!
3. User Story 2 → Documentation complete
4. User Story 3 → Quality tooling configured
5. User Story 4 → Monorepo integration works
6. Polish → Full validation

### Recommended Order (Single Developer)

P1 stories first, then P2:
1. Setup → Foundational → US1 → US2 → US3 → US4 → Polish

---

## Notes

- [P] tasks = different files, no dependencies
- [Story] label maps task to specific user story
- No test tasks included (not explicitly requested in spec)
- Constitution requires test structure (unit/integration/contract) - created in US1
- Each story independently completable and testable
- Commit after each task or logical group
