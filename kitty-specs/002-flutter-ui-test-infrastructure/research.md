# Research: Flutter UI Test Infrastructure

**Feature**: 002-flutter-ui-test-infrastructure
**Date**: 2026-03-25
**Status**: Complete

## R1: Golden Test Framework — Built-in vs Third-Party

**Decision**: Use Flutter's built-in `matchesGoldenFile` with a custom `GoldenFileComparator`.

**Rationale**: The spec explicitly assumes built-in support is sufficient (Assumption 1). Flutter's `matchesGoldenFile` is mature, well-documented, and requires no additional dependencies. A custom `GoldenFileComparator` provides the platform-specific baseline selection that's the only missing piece.

**Alternatives considered**:
- `golden_toolkit` package: Adds multi-device testing and custom pump behaviors. Rejected because it's an extra dependency and our `pumpWithTokens` extension already handles the custom pump. The multi-device feature isn't needed for v1.
- `alchemist` package: Provides themed golden test generation with CI support. Rejected as over-engineering — we already have `TestThemeTokens` and `MidnightVillageTheme` for theme testing.

## R2: Platform-Specific Golden Baselines

**Decision**: Separate directories per platform (`test/design_system/goldens/macos/`, `test/design_system/goldens/linux/`) selected automatically by a custom `GoldenFileComparator` based on `Platform.operatingSystem`.

**Rationale**: Font rendering differs between macOS (CoreText) and Linux (FreeType/Fontconfig). The spec calls this out as an edge case (Edge Case 1) and FR-003 requires platform-specific directories. A custom comparator is the standard Flutter approach for this.

**Alternatives considered**:
- Single baseline with tolerance threshold: Rejected because even small font rendering differences cascade into many pixel changes, making meaningful tolerance impossible without masking real regressions.
- CI-only baselines (always regenerate locally): Rejected because developers need local golden tests to catch regressions before pushing.

## R3: Deterministic Font Rendering

**Decision**: Load bundled fonts (PlayfairDisplay, Inter) via `FontLoader` in a global `flutter_test_config.dart` file. Use `ahem` font as fallback for any text not explicitly styled.

**Rationale**: Flutter tests use the `Ahem` font by default, which renders all characters as squares. Loading the project's actual fonts in test config ensures golden images match the real app. The `flutter_test_config.dart` file is Flutter's standard mechanism for global test setup — it runs before every test file.

**Alternatives considered**:
- Per-test font loading: Rejected because it's boilerplate that every test would need to repeat, and forgetting it produces incorrect golden images silently.
- System font dependency: Rejected because system fonts vary across machines and CI environments.

## R4: Mock HTTP Layer Design

**Decision**: Custom Dio `Interceptor` class (`MockHttpInterceptor`) that matches requests by method+path and returns canned responses. Unmocked requests throw `UnmockedRequestException`.

**Rationale**: The project already uses Dio for HTTP. An interceptor-based mock slots into the existing `ApiClient` architecture without changes to production code. The fail-loud behavior on unmocked endpoints is explicitly required by the spec (Edge Case 2).

**Alternatives considered**:
- `http_mock_adapter` package: Provides fluent API for Dio mocking. Considered viable but adds a dependency for something achievable in ~50 lines of custom code. The custom approach gives us exact control over error behavior.
- `nock`/`mock_web_server`: These mock at the HTTP level. Rejected because they're heavier than needed — we want to mock at the Dio interceptor level for simplicity.

## R5: Mock WebSocket Layer Design

**Decision**: Custom `FakeWebSocketChannel` class implementing `WebSocketChannel` interface, backed by paired `StreamController`s (one for server→client events, one for client→server messages).

**Rationale**: No WebSocket code exists in the frontend yet (confirmed by codebase exploration). Building the mock now lets us define the contract before the production implementation, which is good test-first practice. The mock needs to support: injecting server events, capturing client messages, and simulating connection close/error.

**Alternatives considered**:
- `web_socket_channel` test utilities: The `web_socket_channel` package has `IOWebSocketChannel` but no built-in fake. A custom fake is the standard approach.
- Wait for production WebSocket implementation: Rejected because the spec requires the mock now, and building test infrastructure first aligns with the TEST_FIRST directive.

## R6: Test Harness Architecture

**Decision**: Builder-style extension methods on `WidgetTester`, composing on top of the existing `pumpWithTokens` helper.

**Rationale**: The existing `pumpWithTokens` (in `test/design_system/test_helpers/pump_with_tokens.dart`) sets the pattern: extension methods on `WidgetTester` that wrap widgets in the necessary providers. New harnesses follow this pattern for consistency. The builder approach allows composition: `pumpAuthenticated` adds auth on top of `pumpWithTokens`, `pumpWithGameState` adds game state on top of `pumpAuthenticated`.

**Alternatives considered**:
- Standalone `TestApp` widget class: Creates a configurable widget tree. Rejected because it breaks the established `tester.pump*()` ergonomic pattern.
- Separate harness classes (e.g., `GameTestHarness`): Rejected as unnecessary abstraction — extension methods achieve the same composability with less ceremony.

## R7: Visual Diff Comparison Tooling

**Decision**: Custom Dart CLI tool (`tool/golden_diff_report.dart`) that reads golden test failure outputs and generates pixel-diff overlays + an HTML comparison report.

**Rationale**: FR-014 requires pixel-diff overlays. FR-015 requires a comparison report with thumbnails. Flutter's built-in golden test failure output includes the baseline, actual, and isolated-diff images. Our tool enhances this with a styled HTML report for easier triage, especially when many tests fail at once (SC-009).

**Alternatives considered**:
- VS Code extension for image comparison: Useful but doesn't help in CI or for batch triage.
- Third-party image diff tools (e.g., `pixelmatch`): These work at the image level but don't integrate with Flutter's golden test output format. Our custom tool reads Flutter's output directly.

## R8: Integration Test Target Platform

**Decision**: Chrome headless for v1. Mobile emulator integration tests are a stretch goal.

**Rationale**: The spec states web is the primary development target and mobile integration tests are a stretch goal (Assumption 5). Chrome headless works in CI without additional setup (no emulator provisioning needed).

**Alternatives considered**:
- Mobile-first integration tests: Rejected per spec assumption. Can be added later.
- Desktop (macOS) integration tests: Rejected because the game targets mobile/web, not desktop.

## R9: CI Pipeline Configuration

**Decision**: Define `just` commands and document CI requirements. Actual CI configuration (GitHub Actions, etc.) deferred per constitution ("Infrastructure decisions TBD").

**Rationale**: The constitution notes CI/CD infrastructure decisions are TBD. We can define the commands (`just flutter-test-golden`, `just flutter-test-integration`) and document artifact patterns without committing to a specific CI platform. FR-010 and FR-011 are satisfied by the commands; the CI YAML is a separate concern.

**Alternatives considered**:
- Write GitHub Actions config now: Rejected because CI platform hasn't been decided per constitution.
- Skip CI commands entirely: Rejected because FR-011 requires independent test layer commands regardless of CI platform.

## R10: Test Directory Organization

**Decision**: Shared infrastructure in `test/helpers/`, golden baselines in `test/design_system/goldens/`, integration tests in `integration_test/`.

**Rationale**: `test/helpers/` is the standard Flutter convention for shared test utilities. Keeping golden baselines near the components they test (`test/design_system/goldens/`) maintains locality. `integration_test/` is Flutter's required directory for integration tests (the `integration_test` package expects this location).

**Alternatives considered**:
- All helpers in `test/design_system/test_helpers/`: Rejected because new helpers (mock HTTP, mock WebSocket, game harness) are not design-system-specific — they're used across all test types.
- Golden baselines at repo root: Rejected because it breaks locality and pollutes the top-level directory.
