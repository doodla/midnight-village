# Root Justfile for Midnight Village Monorepo
# Run `just` or `just --list` to see available commands

# Use bash with strict error handling
set shell := ["bash", "-uc"]

# Backend justfile delegation helper
backend_just := "just --justfile backend/justfile --working-directory backend"

# Default recipe: show help
default:
    @just --list

# --- Setup ---

# Install backend dependencies
install:
    {{backend_just}} install

# --- Development ---

# Run backend development server
dev:
    {{backend_just}} dev

# Run backend on specific port
serve port="8000":
    {{backend_just}} serve {{port}}

# Run Django management command
manage *args:
    {{backend_just}} manage {{args}}

# --- Database ---

# Run backend migrations
migrate:
    {{backend_just}} migrate

# Create backend migrations
makemigrations *args:
    {{backend_just}} makemigrations {{args}}

# --- Testing ---

# Run backend tests, then the .claude/ guardrail tests
test *args:
    {{backend_just}} test {{args}}
    just test-guardrails

# Run the .claude/ hook tests: guardrails (python3 >= 3.11), the workflows' recipes and the commit gate's routing
test-guardrails:
    python3 -m unittest discover -s .claude/guardrails/tests
    .claude/hooks/test_gate_routing.sh

# When the change has a migration: the previous build's own tests on a database built by
# this change's migrations (the live server migrates while the previous build serves).
# Does nothing without a migration. GitHub runs it in "Backend Checks".
previous-build-check *args:
    @tool/previous_build_check.sh {{args}}

# A pull request that edits a guard test says so, and why, in its description
# (tool/guard_edits.py). Locally it only reminds; on GitHub (PR_BODY set) it fails.
guard-edits *args:
    @tool/guard_edits.py {{args}}

# Give the disk back: a worktree gone quiet (no source change for hours, no process in it)
# loses its build output; one whose branch is merged (its remote is gone) is removed when
# nothing in it is uncommitted. `just tidy --dry-run` says what it would do (tool/tidy.py).
tidy *args:
    @tool/tidy.py --worktrees {{args}}

# Every word a player reads on one page, made from the code: frontend/build/copy.md
# (not committed; the code is the one home of the words). GitHub attaches it to each run.
copy-page *args:
    @tool/copy_page.py {{args}}

# While building: the fast checks and only the tests this change can reach
# (tool/piece_check.py; `just piece-check --list` prints the plan). GitHub runs everything.
piece-check *args:
    @tool/piece_check.py {{args}}

# LAST, before a piece is handed over, and the only way to hand one over: refuses work
# that is not committed and pushed, runs the checks the change reaches, draws every
# screen state it reaches beside main, and writes the hand-over file (tool/handover.py).
# `just handover <file> --plan` says what it would run and what that costs.
handover *args:
    @tool/handover.py {{args}}

# FIRST, before starting on a screen: its spec section and the owner's words about it
# (word for word), its states, files, tests, and who else is in them (tool/brief.py).
# Usage: just brief 09   |   just brief end-board
brief *args:
    @tool/brief.py {{args}}

# The whole local suite, on demand (minutes): what the commit gate skips (it only runs
# the fast checks) and GitHub runs on a pull request, except the browser, release-build
# and end-to-end jobs. Optionally only some of: backend frontend guardrails
gate-full *blocks:
    .claude/hooks/gate-full.sh {{blocks}}

# Re-record contract_samples/ from the real server (see backend/tests/README.md)
samples:
    {{backend_just}} samples

# Run backend tests with coverage
test-cov:
    {{backend_just}} test-cov

# Run unit tests only
test-unit:
    {{backend_just}} test-unit

# Run integration tests only
test-integration:
    {{backend_just}} test-integration

# Run contract tests only
test-contract:
    {{backend_just}} test-contract

# Boot the harness backend, then run the end-to-end harness (API + UI runners)
# against it and tear it down (needs Postgres; see docs/dev/debug-harness/)
test-harness:
    {{frontend_just}} test-harness

# --- Code Quality ---

# Run backend linting
lint:
    {{backend_just}} lint

# Run backend linting with auto-fix
lint-fix:
    {{backend_just}} lint-fix

# Format backend code
format:
    {{backend_just}} format

# Check backend formatting
format-check:
    {{backend_just}} format-check

# Run backend type checking
typecheck:
    {{backend_just}} typecheck

# Run all backend quality checks, check the instruction files' paths and recipes, and
# that no source file has grown past what can be read whole (tool/check_file_sizes.py)
check:
    {{backend_just}} check
    {{backend_just}} lint-tools
    tool/copy_page.py --check-spec
    tool/check_instruction_links.sh
    tool/check_file_sizes.py

# Fix all auto-fixable issues
fix:
    {{backend_just}} fix

# --- Utilities ---

# Show backend dependencies tree
deps:
    {{backend_just}} deps

# Shell into Django environment
shell:
    {{backend_just}} shell

# Clean up cache files
clean:
    {{backend_just}} clean

# --- Frontend ---

# Frontend justfile delegation helper
frontend_just := "just --justfile frontend/justfile --working-directory frontend"

# Run Flutter app (web)
flutter-run:
    {{frontend_just}} run

# Run Flutter code generation
flutter-build-runner:
    {{frontend_just}} gen

# Run Flutter code generation (watch mode)
flutter-watch:
    {{frontend_just}} watch

# Run Flutter tests
flutter-test:
    {{frontend_just}} test

# Analyze Flutter code
flutter-analyze:
    {{frontend_just}} analyze

# Render every app screen to PNG next to its mock (see frontend/test/README.md)
screens *args:
    {{frontend_just}} screens {{args}}

# The dusk and the dawn in motion: frames and a strip of each (frontend/test/README.md)
scene-frames *args:
    {{frontend_just}} scene-frames {{args}}

# The night board's pick and candle in motion: a frame per 17 ms (frontend/test/README.md)
night-frames *args:
    {{frontend_just}} night-frames {{args}}

# The cold-read pack of first-game journeys (see frontend/lib/design_system/README.md)
playtest-pack *args:
    {{frontend_just}} playtest-pack {{args}}

# Run Flutter integration tests on Chrome
# Uses flutter drive because flutter test does not support web devices
flutter-test-integration:
    {{frontend_just}} test-integration

# Run Flutter integration tests in headless mode (CI)
flutter-test-integration-ci:
    {{frontend_just}} test-integration-ci

# --- Every recipe from the root ---
#
# A recipe that lives in frontend/ or backend/ runs from here too, under the same name
# (guardrails/tests/test_recipes_everywhere.py holds this list complete). Run from inside
# frontend/ or backend/, a root recipe is found as well (`set fallback` there).

# (frontend) Analyze code; fails on any issue (errors, warnings and infos alike)
analyze *args:
    {{frontend_just}} analyze {{args}}

# (frontend) Usage: just app-icon [preview-dir]   (a folder: also each candidate's layers)
app-icon *args:
    {{frontend_just}} app-icon {{args}}

# (frontend) Needs API_ORIGIN and PUBLIC_ORIGIN in the environment: stops, saying so, without them.
build-android *args:
    {{frontend_just}} build-android {{args}}

# (frontend) Build for iOS (production)
build-ios *args:
    {{frontend_just}} build-ios {{args}}

# (frontend) Build for web (production)
build-web *args:
    {{frontend_just}} build-web {{args}}

# (frontend) PROVENANCE.md there). Deterministic. Run `just skin-art` after. Needs uv.
card-back-art *args:
    {{frontend_just}} card-back-art {{args}}

# (frontend) Usage: just card-frames [folder] [label]
card-frames *args:
    {{frontend_just}} card-frames {{args}}

# (frontend) A web build with no --dart-define must not contain the /debug toolbar
check-release *args:
    {{frontend_just}} check-release {{args}}

# (frontend) view this instead of opening screens one by one. Usage: just contact-sheet [folder] [out.png]
contact-sheet *args:
    {{frontend_just}} contact-sheet {{args}}

# (frontend) sizes) into <folder>. Usage: just count-pictures [folder] [width]
count-pictures *args:
    {{frontend_just}} count-pictures {{args}}

# (frontend) Usage: just end-night-frames [folder] [width]
end-night-frames *args:
    {{frontend_just}} end-night-frames {{args}}

# (frontend) into <folder>. Usage: just end-pictures [folder]
end-pictures *args:
    {{frontend_just}} end-pictures {{args}}

# (frontend) Usage: just end-reveal-frames [folder] [width]
end-reveal-frames *args:
    {{frontend_just}} end-reveal-frames {{args}}

# (frontend) Run golden tests and generate diff report if any fail
flutter-golden-check *args:
    {{frontend_just}} flutter-golden-check {{args}}

# (frontend) Generate visual diff report from golden test failures
flutter-golden-report *args:
    {{frontend_just}} flutter-golden-report {{args}}

# (frontend) Update the golden baselines in test/design_system/goldens/ (Linux only)
flutter-golden-update *args:
    {{frontend_just}} flutter-golden-update {{args}}

# (frontend) Run golden tests only (tagged 'golden'; Linux only, skipped on other OSes)
flutter-test-golden *args:
    {{frontend_just}} flutter-test-golden {{args}}

# (frontend) Run code generation
gen *args:
    {{frontend_just}} gen {{args}}

# (frontend) (about 50 s: GitHub runs it, and `just gate-full`; the commit gate does not)
gen-check *args:
    {{frontend_just}} gen-check {{args}}

# (frontend) Usage: just loading-clips [folder]
loading-clips *args:
    {{frontend_just}} loading-clips {{args}}

# (frontend) contact sheet. Usage: just look <state> [width] [height]   (default 412 915)
look *args:
    {{frontend_just}} look {{args}}

# (frontend) Usage: just paper-components [folder]
paper-components *args:
    {{frontend_just}} paper-components {{args}}

# (frontend) 390) into <folder>. Usage: just paper-dress [folder]
paper-dress *args:
    {{frontend_just}} paper-dress {{args}}

# (frontend) Usage: just paper-parts [folder]
paper-parts *args:
    {{frontend_just}} paper-parts {{args}}

# (frontend) test/design_system/asset_release_test.dart holds the bundle to this list.
record-assets *args:
    {{frontend_just}} record-assets {{args}}

# (frontend) Run app on Chrome
run *args:
    {{frontend_just}} run {{args}}

# (frontend) Run app on specific device
run-device *args:
    {{frontend_just}} run-device {{args}}

# (frontend) (resized). Deterministic. Needs uv.
skin-art *args:
    {{frontend_just}} skin-art {{args}}

# (frontend) <folder>. Usage: just story-pictures [folder]
story-pictures *args:
    {{frontend_just}} story-pictures {{args}}

# (frontend) the host's phone, into <folder>. Usage: just talk-pictures [folder]
talk-pictures *args:
    {{frontend_just}} talk-pictures {{args}}

# (frontend) Run integration tests in headless mode for CI
test-integration-ci *args:
    {{frontend_just}} test-integration-ci {{args}}

# (frontend) the second of three parts: GitHub runs the three side by side.
test-widgets *args:
    {{frontend_just}} test-widgets {{args}}

# (frontend) <folder>/<label>/vote. Usage: just vote-frames [folder] [label] [width]
vote-frames *args:
    {{frontend_just}} vote-frames {{args}}

# (frontend) the vote at several table sizes) into <folder>. Usage: just vote-pictures [folder] [width]
vote-pictures *args:
    {{frontend_just}} vote-pictures {{args}}

# (frontend) Run code generation (watch mode)
watch *args:
    {{frontend_just}} watch {{args}}

# (frontend) and a deploy runs the new build on its first open (tool/web_smoke/). About 2 minutes.
web-smoke *args:
    {{frontend_just}} web-smoke {{args}}

# (frontend) Installs what `web-smoke` needs where it looks first (CI: the "Web page smoke" job)
web-smoke-setup *args:
    {{frontend_just}} web-smoke-setup {{args}}

# (backend) Collect static files
collectstatic *args:
    {{backend_just}} collectstatic {{args}}

# (backend) Database shell
dbshell *args:
    {{backend_just}} dbshell {{args}}

# (backend) GET /api/health/ -> 200 before running tests against it.
harness-serve *args:
    {{backend_just}} harness-serve {{args}}

# (backend) (a bare except, `except: pass`, a blind `except Exception`). A tool that fails says so.
lint-tools *args:
    {{backend_just}} lint-tools {{args}}

# (backend) Fail if a model change has no migration
migrations-check *args:
    {{backend_just}} migrations-check {{args}}

# (backend) Create Django superuser
superuser *args:
    {{backend_just}} superuser {{args}}

# (backend) (`just piece-check` at the root uses it)
test-fast *args:
    {{backend_just}} test-fast {{args}}

# (backend) Run tests for specific marker (unit, integration, contract) - no coverage
test-marker *args:
    {{backend_just}} test-marker {{args}}

# (backend) The migration tests, against a database built by the real migrations (no coverage)
test-migrations *args:
    {{backend_just}} test-migrations {{args}}

# (frontend) Usage: just end-link-pictures [folder]
end-link-pictures *args:
    {{frontend_just}} end-link-pictures {{args}}
