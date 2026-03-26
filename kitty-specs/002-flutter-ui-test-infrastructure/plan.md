# Implementation Plan: Flutter UI Test Infrastructure

**Branch**: `002-flutter-ui-test-infrastructure` | **Date**: 2026-03-25 | **Spec**: [spec.md](spec.md)
**Input**: Feature specification from `/kitty-specs/002-flutter-ui-test-infrastructure/spec.md`

## Summary

Build production-grade UI testing infrastructure for the Midnight Village Flutter frontend: golden tests with deterministic rendering and visual diff tooling, integration tests with mock HTTP/WebSocket layers, and reusable test harnesses that reduce per-test setup to ≤5 lines. This is prerequisite infrastructure — no game screens are built here, but every future screen spec depends on it.

## Technical Context

**Language/Version**: Dart SDK ^3.10.4, Flutter stable
**Primary Dependencies**: `flutter_test` (golden + widget), `integration_test` (integration), `mocktail` 1.0.4 (mocking), `dio` 5.9 (HTTP mock layer)
**Storage**: N/A (test infrastructure only)
**Testing**: `flutter test` for unit/widget/golden, `flutter test integration_test/` for integration
**Target Platform**: Web (Chrome headless for CI), macOS (local dev), Linux (CI). iOS/Android integration tests are stretch goals.
**Project Type**: Frontend module within monorepo (`frontend/`)
**Performance Goals**: Golden test suite completes in <60s, integration test suite in <120s
**Constraints**: Deterministic rendering across macOS (dev) and Linux (CI). No third-party golden packages unless Flutter built-in proves insufficient.
**Scale/Scope**: ~12 existing widgets to write example golden tests for, 1 existing auth flow for integration test example

## Constitution Check

*GATE: Must pass before Phase 0 research. Re-check after Phase 1 design.*

| Gate | Status | Notes |
|------|--------|-------|
| Tests verify behavior, not implementation | PASS | Harnesses test rendering and interaction outcomes, not internal state |
| No hardcoded values — use design tokens | PASS | Golden tests use production `MidnightVillageTheme()` with deterministic font loading for visual accuracy; widget tests use `TestThemeTokens` for isolation |
| Riverpod patterns with code generation | PASS | Harnesses wrap `ProviderScope` with overrides, following existing `pumpWithTokens` pattern |
| 80% coverage target | PASS | Infrastructure itself is tested via example tests that exercise each layer |
| No over-engineering | PASS | Extends existing `pumpWithTokens` rather than replacing; uses Flutter built-in golden support |
| Platform-aware (web, iOS, Android) | PASS | Platform-specific golden baselines; integration tests target Chrome first |
| No game logic in widgets | N/A | This is test infrastructure, not game logic |
| TEST_FIRST directive | PASS | Test infrastructure is literally tests — the deliverable IS the test framework |

**Post-Phase 1 re-check**: See bottom of document.

## Project Structure

### Documentation (this feature)

```
kitty-specs/002-flutter-ui-test-infrastructure/
├── plan.md              # This file
├── research.md          # Phase 0: technology decisions
├── data-model.md        # Phase 1: key entity structures
├── quickstart.md        # Phase 1: developer guide
└── tasks.md             # Phase 2 output (NOT created by /spec-kitty.plan)
```

### Source Code (repository root)

```
frontend/
├── test/
│   ├── helpers/                          # NEW: shared test infrastructure
│   │   ├── golden_test_helper.dart       # Golden test config (size, fonts, comparator)
│   │   ├── pump_app.dart                 # Full-app pump with mock providers
│   │   ├── mock_http_client.dart         # Dio interceptor mock layer
│   │   ├── mock_websocket.dart           # Fake WebSocket channel
│   │   ├── test_harness.dart             # Game state harness builder
│   │   └── timer_control.dart            # Fake timer for countdown tests
│   ├── design_system/
│   │   ├── test_helpers/                 # EXISTING: pump_with_tokens.dart, test_theme.dart
│   │   ├── components/game/             # EXISTING: widget tests
│   │   └── goldens/                      # NEW: golden baseline images
│   │       ├── macos/                    # Platform-specific baselines
│   │       └── linux/
│   ├── core/                            # EXISTING: unit tests
│   ├── features/                        # EXISTING: feature tests
│   └── flutter_test_config.dart         # NEW: global test config (fonts, golden comparator)
├── integration_test/                     # NEW: integration test directory
│   ├── app_test.dart                    # Auth flow integration test
│   ├── helpers/
│   │   └── integration_test_helper.dart # Integration test utilities
│   └── screenshots/                     # Failure screenshots (gitignored)
├── tool/
│   └── golden_diff_report.dart          # NEW: visual diff comparison tool
└── justfile                              # MODIFIED: new test commands
```

**Structure Decision**: Extends existing test structure. New shared helpers go in `test/helpers/` (project-wide), while existing `test/design_system/test_helpers/` retains theme-specific helpers. Golden baselines go in `test/design_system/goldens/` alongside the components they test. Integration tests use Flutter's standard `integration_test/` directory.

## Complexity Tracking

No constitution violations requiring justification. The design extends existing patterns (`pumpWithTokens`) and uses Flutter built-in capabilities (`matchesGoldenFile`, `integration_test`).

## Engineering Alignment

### Decisions Made

1. **Golden test framework**: Flutter built-in `matchesGoldenFile` with custom `GoldenFileComparator` for platform-specific baselines. No third-party packages.

2. **Platform-specific baselines**: Separate `macos/` and `linux/` directories under `test/design_system/goldens/`. The custom comparator selects the correct directory based on `Platform.operatingSystem`.

3. **Deterministic rendering**: Global `flutter_test_config.dart` loads bundled fonts (PlayfairDisplay, Inter) via `FontLoader` before any test runs. Fixed screen size (390x844 — iPhone 14 logical size) set via `tester.view`.

4. **Mock HTTP layer**: Custom Dio `Interceptor` that matches request path/method and returns canned `Response` objects. Throws on unmocked endpoints (fail loud, per spec edge case).

5. **Mock WebSocket layer**: Fake `WebSocketChannel` backed by `StreamController` pairs. Tests inject events via `addServerEvent()`, capture client messages via `sentMessages` list.

6. **Test harnesses**: Builder pattern extending `WidgetTester`:
   - `pumpWithGolden(widget)` — deterministic size + fonts + golden comparison
   - `pumpAuthenticated(widget)` — auth providers pre-loaded
   - `pumpWithGameState(widget, phase:, players:)` — full game state
   - `pumpApp()` — full app with mock layers for integration-style widget tests

7. **Visual diff tooling**: Dart CLI tool at `tool/golden_diff_report.dart` that:
   - Reads golden test failure outputs
   - Generates pixel-diff overlay images (changed pixels highlighted in magenta)
   - Produces HTML comparison report with side-by-side + overlay views
   - Invoked via `just flutter-golden-report`

8. **Integration tests**: Flutter `integration_test` package targeting Chrome headless. Mock HTTP via the same Dio interceptor used in widget tests. One example test covers the auth flow.

9. **justfile additions**:
   - `flutter-test-golden` — run golden tests only
   - `flutter-test-integration` — run integration tests on Chrome
   - `flutter-golden-update` — regenerate all baselines
   - `flutter-golden-report` — generate visual diff report

10. **Extend, don't replace**: `pumpWithTokens` remains the foundation. New helpers compose on top of it rather than replacing it.

## Constitution Check — Post-Phase 1

| Gate | Status | Notes |
|------|--------|-------|
| No over-engineering | PASS | Builder pattern for harnesses adds minimal abstraction; each helper is a single function |
| Platform-aware | PASS | Platform-specific golden baselines handle macOS/Linux rendering differences |
| Tests verify behavior | PASS | Example tests verify visual output and interaction outcomes |
| Riverpod code-gen patterns | PASS | Harnesses use `overrideWithValue` on generated providers |
| No hidden information leaks | N/A | Test infrastructure doesn't handle game data |
| 80% coverage | PASS | Example tests demonstrate each layer; coverage of test helpers themselves via usage |
