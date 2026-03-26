# Feature Specification: Flutter UI Test Infrastructure

**Feature Branch**: `002-flutter-ui-test-infrastructure`
**Created**: 2026-03-25
**Status**: Draft
**Input**: Production-grade UI testing infrastructure — golden tests, integration tests, and interaction test harnesses — as a prerequisite for all future frontend screen development.

## User Scenarios & Testing *(mandatory)*

### User Story 1 - Golden Test Framework for Visual Regression (Priority: P1)

A developer building or modifying a Flutter widget runs a single command and gets pixel-level verification that the widget renders correctly. When a visual change is intentional, they update the baseline with one command. When it's accidental, the test fails with a clear diff showing what changed.

**Why this priority**: Every future spec (design system realignment, screen builds) will produce visual output. Without golden tests, visual regressions go undetected until manual review. This is the foundation that makes all other UI work trustworthy.

**Independent Test**: Can be fully tested by creating golden tests for 2-3 existing components (MvButton, RoleCard, PlayerCircle) and verifying the generate/compare/update cycle works end-to-end.

**Acceptance Scenarios**:

1. **Given** an existing widget with no golden file, **When** the developer runs the golden test suite, **Then** baseline images are generated and the test passes on subsequent runs with no changes.
2. **Given** a widget with an existing golden baseline, **When** a code change alters the widget's appearance, **Then** the golden test fails with a visual diff artifact showing the before/after difference.
3. **Given** an intentional visual change, **When** the developer runs the baseline update command, **Then** new baselines are generated and tests pass on subsequent runs.
4. **Given** a widget that uses theme tokens, **When** the golden test renders it, **Then** the test uses a deterministic theme so that font rendering, colors, and spacing are consistent across machines.
5. **Given** a CI environment, **When** golden tests run, **Then** results are consistent with local runs (deterministic font loading, no platform-dependent rendering differences).

---

### User Story 2 - Integration Test Framework for Full App Flows (Priority: P1)

A developer writes a test that launches the full app, navigates through multiple screens, interacts with widgets, and asserts on the final state. These tests run against a real rendering engine (on a device, emulator, or headless browser) and catch issues that widget tests miss — routing bugs, provider wiring, lifecycle problems, and cross-screen state.

**Why this priority**: The game has a linear multi-screen flow (Welcome → Home → Lobby → Night → Discussion → Voting → Results). Unit and widget tests can't verify that this flow actually works end-to-end. Integration tests are the only way to catch navigation, provider initialization, and cross-screen state bugs.

**Independent Test**: Can be tested by writing an integration test for the existing auth flow (launch app → see welcome → enter name → tap enter → arrive at home screen) and running it on Chrome and an emulator.

**Acceptance Scenarios**:

1. **Given** the `integration_test` package is configured, **When** a developer writes a test that launches the app and navigates, **Then** the test can interact with widgets (tap, enter text, scroll) and assert on screen content.
2. **Given** an integration test that depends on API calls, **When** the test runs, **Then** it uses a mock HTTP layer so tests are deterministic and don't require a running backend.
3. **Given** a CI environment, **When** integration tests run, **Then** they execute on a headless platform (Chrome for web, or emulator) and report pass/fail with screenshots on failure.
4. **Given** a test that needs to verify navigation, **When** GoRouter navigates to a new route, **Then** the test can assert on the presence of the destination screen's widgets.

---

### User Story 3 - Reusable Test Harnesses for Game Scenarios (Priority: P1)

A developer building a game screen (e.g., night action, voting) uses pre-built test harnesses that set up realistic game state — providers pre-loaded with mock data, WebSocket event simulators, timer controls — so they can focus on testing the widget interaction rather than spending 50 lines on setup boilerplate. These harnesses are used within widget tests (via `flutter_test`), not as a separate test layer.

**Why this priority**: Every future game screen needs the same setup: authenticated user, game state provider, WebSocket event stream, timer. Without reusable harnesses, every screen spec will reinvent this setup, leading to inconsistent and brittle tests. Building the harness now means future specs deliver tested screens from day one.

**Independent Test**: Can be tested by creating a harness for the existing auth flow and one for a simulated game phase (e.g., mock "night action prompt" scenario), then writing tests that use each harness with minimal setup code.

**Acceptance Scenarios**:

1. **Given** a test harness for authenticated app state, **When** a developer uses it in a widget or integration test, **Then** the app renders with a logged-in user, valid tokens, and the home screen, in under 5 lines of setup.
2. **Given** a test harness for game phase state, **When** a developer configures it with a specific phase (e.g., voting) and player list, **Then** providers are pre-loaded and the test can immediately interact with the phase-specific UI.
3. **Given** a WebSocket event simulator, **When** a test emits a mock event (e.g., `vote_submitted`, `phase_change`), **Then** the app's state updates as if a real server sent the event, and the UI reflects the change.
4. **Given** a timer control harness, **When** a test fast-forwards time, **Then** timer-dependent UI (countdown displays, auto-transitions) behaves as expected without waiting real seconds.
5. **Given** multiple test files using the same harness, **When** the harness API changes, **Then** only the harness file needs updating — individual tests remain stable.

---

### User Story 4 - Visual Diff Comparison Tooling (Priority: P2)

When a golden test fails, a developer can quickly review what changed using a comparison tool — side-by-side baseline vs actual, overlay diff highlighting changed pixels, and a summary of which components regressed. This works locally (command-line or browser-based viewer) and in CI (diff artifacts linked from the build report).

**Why this priority**: Raw golden test failures just say "image didn't match." Without comparison tooling, developers have to manually open two images and squint at the difference. A visual diff tool turns a 10-minute investigation into a 10-second glance — critical when a design system change touches dozens of components at once.

**Independent Test**: Can be tested by deliberately breaking a golden baseline (change a color token), running the test, and verifying the comparison tool produces a clear side-by-side diff and a highlighted-pixel overlay.

**Acceptance Scenarios**:

1. **Given** a golden test failure, **When** the developer runs the comparison tool, **Then** they see a side-by-side view of the baseline (expected) and actual (current) images.
2. **Given** a golden test failure, **When** the comparison tool runs, **Then** it produces a pixel-diff overlay image highlighting exactly which pixels changed, saved alongside the test output.
3. **Given** multiple golden test failures in a single run, **When** the developer opens the comparison report, **Then** they see a summary listing all failing components with thumbnails, so they can triage which changes are intentional vs regressions.
4. **Given** a golden test failure in CI, **When** the developer views the build report, **Then** the diff images (side-by-side + overlay) are available as downloadable artifacts or inline in the report.
5. **Given** an intentional design change that affects many components, **When** the developer reviews all diffs and confirms they're expected, **Then** they can bulk-update all baselines with a single command.

---

### User Story 5 - CI Pipeline Integration (Priority: P2)

All three test layers (golden, integration, interaction) run automatically in CI on every push. Failures block merges. Test artifacts (golden diffs, failure screenshots) are uploaded for easy debugging.

**Why this priority**: Tests that don't run in CI are tests that get ignored. This ensures the infrastructure actually enforces quality rather than being optional.

**Independent Test**: Can be tested by configuring the CI job and pushing a deliberately failing test to verify it blocks the build and uploads artifacts.

**Acceptance Scenarios**:

1. **Given** a push to any branch, **When** CI runs, **Then** widget tests, golden tests, and integration tests all execute.
2. **Given** a golden test failure in CI, **When** the developer reviews the build, **Then** the diff image is available as a downloadable artifact.
3. **Given** an integration test failure in CI, **When** the developer reviews the build, **Then** a failure screenshot is available showing the app state at the point of failure.
4. **Given** all tests pass, **When** the developer views CI status, **Then** the build is green and the merge is unblocked.

---

### User Story 6 - Developer Ergonomics & Documentation (Priority: P3)

A developer new to the project can find clear instructions on how to write each type of test, run them locally, update baselines, and debug failures. The testing patterns are documented with working examples that serve as both documentation and regression tests.

**Why this priority**: Infrastructure without documentation becomes tribal knowledge. Clear patterns and examples ensure consistent test quality across all future specs.

**Independent Test**: Can be tested by having someone unfamiliar with the test setup follow the documentation to write a golden test, an integration test, and a harness-backed widget test.

**Acceptance Scenarios**:

1. **Given** a developer wants to add a golden test, **When** they look at existing examples, **Then** they can follow the pattern to create a new golden test in under 5 minutes.
2. **Given** a developer wants to write an integration test, **When** they consult the test README, **Then** they find step-by-step instructions for setup, writing, running, and debugging.
3. **Given** existing example tests, **When** the test suite runs, **Then** the examples themselves pass (they're living documentation, not stale comments).

---

### Edge Cases

- What happens when golden tests produce different results on macOS vs Linux (CI)? Deterministic font loading and platform-specific baseline directories must handle this.
- How does the integration test mock layer handle unexpected API calls? Tests should fail loudly (throw) on unmocked endpoints rather than silently returning empty data.
- What happens when a WebSocket event simulator emits events faster than the UI can process? The harness should use Flutter's test event loop (`pump`/`pumpAndSettle`) to ensure events are processed.
- What happens when a golden baseline file is committed but the corresponding widget is deleted? Stale baselines should be detected and flagged.

## Requirements *(mandatory)*

### Functional Requirements

- **FR-001**: System MUST provide a golden test runner that generates, compares, and updates pixel-level baseline images for Flutter widgets.
- **FR-002**: System MUST ensure golden test output is deterministic across platforms by controlling font loading, theme injection, and screen size.
- **FR-003**: System MUST provide platform-specific golden baseline directories (macOS, Linux) to handle rendering differences between development and CI environments.
- **FR-004**: System MUST include the `integration_test` package configured for the Flutter project with support for web (Chrome) and mobile (emulator) targets.
- **FR-005**: System MUST provide a mock HTTP layer for integration tests so they run without a live backend.
- **FR-006**: System MUST provide a mock WebSocket layer that can simulate server-sent events (game state changes, phase transitions, vote submissions) in tests.
- **FR-007**: System MUST provide reusable test harnesses for common app states: unauthenticated, authenticated, in-lobby, in-game-phase (configurable phase and player data).
- **FR-008**: System MUST provide timer control utilities that allow tests to fast-forward countdowns without waiting real time.
- **FR-009**: System MUST provide integration test utilities for GoRouter navigation assertions (verify current route, wait for navigation to complete).
- **FR-010**: System MUST capture and save failure artifacts (golden diffs, screenshots) that can be uploaded as CI build artifacts.
- **FR-011**: System MUST include a `just` command (or equivalent) to run each test layer independently: `just flutter-test-golden`, `just flutter-test-integration`.
- **FR-012**: System MUST include working example tests for each layer: at least one golden test, one integration test, and one harness-backed widget test using existing components.
- **FR-013**: System MUST extend the existing `pumpWithTokens` helper to support golden test configuration (fixed screen size, deterministic fonts).
- **FR-014**: System MUST produce a pixel-diff overlay image for each golden test failure, highlighting changed pixels in a contrasting color.
- **FR-015**: System MUST provide a comparison report (local and CI) that lists all failing golden tests with side-by-side thumbnails (baseline vs actual vs diff overlay).
- **FR-016**: System MUST provide a bulk baseline update command that regenerates all golden baselines in a single invocation.
- **FR-017**: Each test layer (golden, widget, integration) MUST provide a base helper or wrapper that encapsulates infrastructure concerns (theme injection, provider setup, font loading, screen sizing, mock wiring) so that individual tests only specify what's unique to them — the widget under test, the state scenario, and the assertions. Harness-backed widget tests (game scenario tests) are a subset of widget tests, not a separate layer.

### Key Entities

- **Golden Baseline**: A reference image of a widget's rendered output, stored in the repo, used for pixel-level comparison.
- **Test Harness**: A reusable setup utility that pre-configures Riverpod providers, mock services, and app state for a specific test scenario.
- **Mock HTTP Layer**: An interceptor or fake that captures HTTP requests in tests and returns pre-configured responses.
- **Mock WebSocket Layer**: A fake WebSocket channel that allows tests to inject server events and capture client-sent messages.
- **Failure Artifact**: A diff image (golden) or screenshot (integration) saved when a test fails, used for debugging.
- **Pixel-Diff Overlay**: An image where unchanged pixels are dimmed and changed pixels are highlighted in a contrasting color, making visual regressions immediately obvious.
- **Comparison Report**: A summary view (HTML or terminal) listing all failing golden tests with thumbnails, enabling batch triage of visual changes.

## Success Criteria *(mandatory)*

### Measurable Outcomes

- **SC-001**: A developer can write a golden test for any existing widget and get a passing baseline in under 5 minutes of work.
- **SC-002**: Golden tests detect a 1-pixel color change in a widget and fail with a visible diff artifact.
- **SC-003**: An integration test can launch the app, navigate through the auth flow, and assert on the home screen — all within 30 seconds of wall-clock time.
- **SC-004**: All test harnesses reduce per-test setup to 5 lines or fewer for common scenarios (authenticated state, game phase state).
- **SC-005**: The mock WebSocket layer can simulate a complete game phase transition (e.g., night → discussion) and the test verifies the UI updates accordingly.
- **SC-006**: All test layers (widget — including harness-backed game scenario tests — golden, and integration) run in CI and a failure in any layer blocks the merge.
- **SC-007**: Working example tests exist for each layer and pass in both local and CI environments.
- **SC-008**: A golden test failure produces a side-by-side comparison and pixel-diff overlay viewable locally and as a CI artifact.
- **SC-009**: When a design token change breaks 10+ golden tests, the developer can review all diffs in a single report and bulk-update baselines with one command.

## Assumptions

- Flutter's built-in golden test support (`matchesGoldenFile`) is sufficient; no third-party golden test packages are needed unless platform inconsistency requires it.
- CI runs on Linux; golden baselines may need platform-specific directories if font rendering differs from macOS development.
- The existing `pumpWithTokens` helper is the right foundation to extend for golden and harness utilities rather than replacing it.
- WebSocket mock layer design will be informed by the backend's actual WebSocket event contract (documented in backend API), but the mock itself is a frontend-only concern.
- Integration tests for web will run on headless Chrome; mobile integration tests are a stretch goal for this spec.
