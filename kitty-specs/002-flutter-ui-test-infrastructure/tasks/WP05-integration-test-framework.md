---
work_package_id: WP05
title: Integration Test Framework
lane: "doing"
dependencies: [WP02]
requirement_refs: [FR-004, FR-005, FR-009, FR-011, FR-012]
planning_base_branch: main
merge_target_branch: main
branch_strategy: Planning artifacts for this feature were generated on main. During /spec-kitty.implement this WP may branch from a dependency-specific base, but completed changes must merge back into main unless the human explicitly redirects the landing branch.
base_branch: 002-flutter-ui-test-infrastructure-WP02
base_commit: aaef6977b04041879d9cb6edcb2aa138876d1b2e
created_at: '2026-03-26T01:41:34.125117+00:00'
subtasks:
- T021
- T022
- T023
- T024
- T025
- T026
phase: Phase 1 - Core Layers
assignee: ''
agent: "headless-reviewer"
shell_pid: "20192"
review_status: has_feedback
reviewed_by: Sridhar Vadlamani
review_feedback: feedback://002-flutter-ui-test-infrastructure/WP05/20260326T020133Z-cb72d00f.md
history:
- timestamp: '2026-03-25T23:55:37Z'
  lane: planned
  agent: system
  shell_pid: ''
  action: Prompt generated via /spec-kitty.tasks
---

# Work Package Prompt: WP05 – Integration Test Framework

## IMPORTANT: Review Feedback Status

**Read this first if you are implementing this task!**

- **Has review feedback?**: Check the `review_status` field above. If it says `has_feedback`, scroll to the **Review Feedback** section immediately (right below this notice).
- **You must address all feedback** before your work is complete. Feedback items are your implementation TODO list.
- **Mark as acknowledged**: When you understand the feedback and begin addressing it, update `review_status: acknowledged` in the frontmatter.
- **Report progress**: As you address each feedback item, update the Activity Log explaining what you changed.

---

## Review Feedback

> **Populated by `/spec-kitty.review`** – Reviewers add detailed feedback here when work needs changes. Implementation must address every item listed below before returning for re-review.

*[This section is empty initially. Reviewers will populate it if the work is returned from review. If you see feedback here, treat each item as a must-do before completion.]*

---

## Markdown Formatting
Wrap HTML/XML tags in backticks: `` `<div>` ``, `` `<script>` ``
Use language identifiers in code blocks: ````python`, ````bash`

---

## Objectives & Success Criteria

Establish the integration test infrastructure using Flutter's `integration_test` package, targeting Chrome headless. Write an example integration test covering the auth flow. Configure navigation assertion utilities for GoRouter.

**Success criteria**:
- Run `just flutter-test-integration` and see the auth flow integration test pass on headless Chrome
- Failure screenshots are captured to `integration_test/screenshots/`
- Navigation assertions (`expectRoute`, `waitForNavigation`) work with GoRouter
- `integration_test` package is properly configured in `pubspec.yaml`

**Implementation command**: `spec-kitty implement WP05 --base WP02`

## Context & Constraints

- **Spec**: `kitty-specs/002-flutter-ui-test-infrastructure/spec.md` — User Story 2; FR-004, FR-005, FR-009, FR-011, FR-012
- **Plan**: `kitty-specs/002-flutter-ui-test-infrastructure/plan.md` — Decisions #8-9
- **Depends on WP02**: Mock HTTP client (`MockHttpClient`) for deterministic API responses
- **GoRouter**: Check `frontend/lib/core/` for router configuration — navigation assertions must work with GoRouter's delegate
- **Target platform**: Chrome headless for CI, Chrome for local dev
- **Constraint**: `IntegrationTestWidgetsFlutterBinding.ensureInitialized()` must be called at the start of each integration test file
- **Constraint**: `integration_test` on web has known limitations (no native platform channels) — acceptable for web-first approach

## Subtasks & Detailed Guidance

### Subtask T021 – Add `integration_test` to `pubspec.yaml`

- **Purpose**: Configure the Flutter integration test package as a dev dependency and create the standard directory structure.
- **Steps**:
  1. Read `frontend/pubspec.yaml` to check current dev dependencies
  2. Add `integration_test` as an SDK dev dependency:
     ```yaml
     dev_dependencies:
       integration_test:
         sdk: flutter
     ```
  3. Create directory structure:
     ```
     frontend/integration_test/
     frontend/integration_test/helpers/
     ```
  4. Run `flutter pub get` from `frontend/` to verify the dependency resolves
- **Files**: `frontend/pubspec.yaml` (modify), `frontend/integration_test/` (new directory)
- **Parallel?**: Yes — independent of T022-T024 (different files)
- **Notes**: `integration_test` is a Flutter SDK package, not a pub.dev package. It's declared as `sdk: flutter` in pubspec.yaml. Check if it's already present before adding.

### Subtask T022 – Create `integration_test_helper.dart`

- **Purpose**: Provide a bootstrap utility for integration tests that initializes the binding, wires mock HTTP, and provides a `launchApp()` function.
- **Steps**:
  1. Create `frontend/integration_test/helpers/integration_test_helper.dart`
  2. Define the helper:
     ```dart
     import 'package:integration_test/integration_test.dart';
     // ... imports

     class IntegrationTestSetup {
       static late IntegrationTestWidgetsFlutterBinding binding;
       static late MockHttpClient mockHttp;

       static void initialize() {
         binding = IntegrationTestWidgetsFlutterBinding.ensureInitialized();
         mockHttp = MockHttpClient();
       }

       static Future<void> launchApp(WidgetTester tester, {
         List<Override>? overrides,
         Map<String, Response>? httpMocks,
       }) async {
         // Register default HTTP mocks (auth endpoints, etc.)
         _registerDefaultMocks(httpMocks);

         await tester.pumpWidget(
           ProviderScope(
             overrides: [
               httpClientProvider.overrideWithValue(mockHttp.dio),
               ...?overrides,
             ],
             child: const MidnightVillageApp(),
           ),
         );
         await tester.pumpAndSettle();
       }

       static void _registerDefaultMocks(Map<String, Response>? additional) {
         // Register common endpoints all integration tests need
         mockHttp.when(method: 'POST', path: '/api/v1/auth/register/')
           .thenReturn(Response(data: {'token': 'test-token'}, statusCode: 201));
         // Add additional mocks
       }
     }
     ```
  3. Check `frontend/lib/` for the app's provider names and main app widget
- **Files**: `frontend/integration_test/helpers/integration_test_helper.dart` (new, ~80 lines)
- **Parallel?**: No — foundational for T023, T024
- **Notes**: The binding must be initialized once per test file (not per test). The `launchApp` function handles the full bootstrap so individual tests stay concise. Consider making `_registerDefaultMocks` configurable so tests can override specific endpoints.

### Subtask T023 – Create navigation assertion utilities

- **Purpose**: Provide assertion helpers for verifying GoRouter navigation in integration tests.
- **Steps**:
  1. Add to `integration_test_helper.dart` or create a separate file `frontend/integration_test/helpers/navigation_helpers.dart`
  2. Define navigation assertion utilities:
     ```dart
     extension NavigationAssertions on WidgetTester {
       /// Assert the current route matches [path]
       void expectRoute(String path) {
         final router = GoRouter.of(state.context);
         final currentLocation = router.routerDelegate.currentConfiguration.fullPath;
         expect(currentLocation, equals(path));
       }

       /// Wait for navigation to [path] with timeout
       Future<void> waitForNavigation(String path, {Duration timeout = const Duration(seconds: 5)}) async {
         final stopwatch = Stopwatch()..start();
         while (stopwatch.elapsed < timeout) {
           await pump(const Duration(milliseconds: 100));
           try {
             expectRoute(path);
             return;
           } catch (_) {
             // Not there yet, keep waiting
           }
         }
         fail('Navigation to $path did not complete within $timeout');
       }
     }
     ```
  3. Provide a fallback assertion using widget finders:
     ```dart
     /// Fallback: assert a screen is visible by finding its widget type
     void expectScreen<T extends Widget>() {
       expect(find.byType(T), findsOneWidget);
     }
     ```
  4. Check how GoRouter exposes current location — the API may differ between versions
- **Files**: `frontend/integration_test/helpers/navigation_helpers.dart` (new, ~50 lines) or added to `integration_test_helper.dart`
- **Parallel?**: No — related to T022 (same helper context)
- **Notes**: GoRouter's internal state may not be easily inspectable in all configurations. The `expectScreen<T>()` fallback is a pragmatic alternative that checks if the destination screen's widget is rendered. Consider both approaches.

### Subtask T024 – Write auth flow integration test

- **Purpose**: Write the first integration test to prove the framework works — covering the complete auth flow from app launch to home screen.
- **Steps**:
  1. Create `frontend/integration_test/auth_flow_test.dart`
  2. Write the integration test:
     ```dart
     import 'package:integration_test/integration_test.dart';
     // ... imports

     void main() {
       IntegrationTestSetup.initialize();

       testWidgets('Auth flow: launch → welcome → enter name → home', (tester) async {
         await IntegrationTestSetup.launchApp(tester);

         // Verify welcome screen
         expect(find.text('Welcome'), findsOneWidget); // Adapt to actual UI

         // Enter player name
         await tester.enterText(find.byType(TextField), 'TestPlayer');
         await tester.pumpAndSettle();

         // Tap the enter/submit button
         await tester.tap(find.byType(ElevatedButton)); // Adapt to actual button
         await tester.pumpAndSettle();

         // Verify navigation to home screen
         tester.expectRoute('/home'); // or expectScreen<HomeScreen>()
       });
     }
     ```
  3. Check `frontend/lib/features/auth/` for the actual auth flow widgets and routes
  4. Configure mock HTTP responses for the auth endpoint in `IntegrationTestSetup`
  5. Run the test: `flutter test integration_test/auth_flow_test.dart -d chrome`
- **Files**: `frontend/integration_test/auth_flow_test.dart` (new, ~50 lines)
- **Parallel?**: No — depends on T022, T023
- **Notes**: The test must adapt to the actual auth flow UI. Check `frontend/lib/features/auth/` for screen names, widget types, and route paths. The mock HTTP layer from WP02 handles the auth API call.

### Subtask T025 – Configure failure screenshot capture

- **Purpose**: Automatically save screenshots when integration tests fail, enabling post-mortem debugging in CI.
- **Steps**:
  1. In `integration_test_helper.dart`, add screenshot capture in test teardown:
     ```dart
     static void setupScreenshotCapture(IntegrationTestWidgetsFlutterBinding binding) {
       // Flutter's integration test binding supports takeScreenshot
       // Configure output directory
     }
     ```
  2. Create `frontend/integration_test/screenshots/` directory
  3. Add `screenshots/` to `frontend/.gitignore`:
     ```
     integration_test/screenshots/
     ```
  4. Verify screenshots are captured on failure by temporarily adding a failing assertion
- **Files**: `frontend/integration_test/helpers/integration_test_helper.dart` (modify), `frontend/integration_test/screenshots/.gitkeep` (new), `frontend/.gitignore` (modify)
- **Parallel?**: Yes — gitignore and directory creation are independent of T022-T024
- **Notes**: `IntegrationTestWidgetsFlutterBinding` provides `takeScreenshot(name)`. The exact API depends on the Flutter version. On web, screenshots may use `html.CanvasElement` rendering. Verify the screenshot mechanism works on Chrome.

### Subtask T026 – Add `flutter-test-integration` justfile command

- **Purpose**: Provide a developer-friendly command for running integration tests on headless Chrome.
- **Steps**:
  1. Read `frontend/justfile` to understand existing patterns
  2. Add the command:
     ```just
     # Run integration tests on headless Chrome
     flutter-test-integration:
         flutter test integration_test/ -d chrome
     ```
  3. Consider adding a `--headless` variant for CI:
     ```just
     # Run integration tests in headless mode (CI)
     flutter-test-integration-ci:
         flutter test integration_test/ -d web-server
     ```
  4. Verify the command works (requires Chrome installed)
- **Files**: `frontend/justfile` (modify, ~8 lines added)
- **Parallel?**: Yes — independent of T021-T025 (different file)
- **Notes**: `flutter test integration_test/ -d chrome` launches a Chrome instance. For CI, `-d web-server` may be more appropriate. Check which option works in the project's CI environment. Follow existing justfile naming conventions.

## Test Strategy

The auth flow integration test (T024) IS the validation:

1. **T024**: Auth flow test passes on Chrome — validates the full integration test setup
2. **Screenshot test**: Temporarily break T024, verify screenshot is captured
3. **justfile test**: Run `just flutter-test-integration` and confirm it completes
4. **Navigation assertions**: Auth flow test uses `expectRoute` or `expectScreen` — validates T023

## Risks & Mitigations

- **Chrome headless may not be available in all environments**: Document the required setup in justfile command comments. Consider `-d web-server` as a fallback.
- **`integration_test` on web has limitations**: No native platform channels, limited screenshot support. This is acceptable for web-first approach.
- **GoRouter's internal state may not be easily inspectable**: Provide `expectScreen<T>()` fallback that checks widget presence instead of route path.
- **Auth flow may have changed since spec was written**: Check actual auth screens and routes in `frontend/lib/features/auth/` before writing the test.

## Review Guidance

- Verify `integration_test` is declared as SDK dependency (not pub.dev)
- Verify `IntegrationTestWidgetsFlutterBinding.ensureInitialized()` is called correctly
- Verify mock HTTP is wired into the app's DI before launch
- Verify navigation assertions work with the actual GoRouter configuration
- Verify screenshot capture works (test manually with a failing assertion)
- Verify justfile command follows existing naming conventions

## Activity Log

> **CRITICAL**: Activity log entries MUST be in chronological order (oldest first, newest last).

### How to Add Activity Log Entries

**When adding an entry**:
1. Scroll to the bottom of this file (Activity Log section below "Valid lanes")
2. **APPEND the new entry at the END** (do NOT prepend or insert in middle)
3. Use exact format: `- YYYY-MM-DDTHH:MM:SSZ – agent_id – lane=<lane> – <action>`
4. Timestamp MUST be current time in UTC (ISO-8601 `YYYY-MM-DDTHH:MM:SSZ`) and should be generated without shell commands (prefer `NOW_UTC_ISO` from `check-prerequisites --json --paths-only`)
5. Lane MUST match the frontmatter `lane:` field exactly
6. Agent ID should identify who made the change (claude-sonnet-4-5, codex, etc.)

**Format**:
```
- YYYY-MM-DDTHH:MM:SSZ – <agent_id> – lane=<lane> – <brief action description>
```

**Initial entry**:
- 2026-03-25T23:55:37Z – system – lane=planned – Prompt created.

---

### Updating Lane Status

To change a work package's lane, either:

1. **Edit directly**: Change the `lane:` field in frontmatter AND append activity log entry (at the end)
2. **Use CLI**: `spec-kitty agent tasks move-task WP05 --to <lane> --note "message"` (recommended)

The CLI command updates both frontmatter and activity log automatically.

**Valid lanes**: `planned`, `doing`, `for_review`, `done`
- 2026-03-26T01:41:34Z – headless-impl – shell_pid=95105 – lane=doing – Assigned agent via workflow command
- 2026-03-26T01:49:06Z – headless-impl – shell_pid=95105 – lane=for_review – Ready for review: Integration test framework with auth flow test, MockHttpClient wiring via ApiClient(dio:), NavigationAssertions extension, screenshot capture dir, and just flutter-test-integration commands. All 173 unit tests pass, flutter analyze clean.
- 2026-03-26T01:49:18Z – headless-reviewer – shell_pid=2309 – lane=doing – Started review via workflow command
- 2026-03-26T01:52:02Z – headless-reviewer – shell_pid=2309 – lane=planned – Moved to planned
- 2026-03-26T01:52:13Z – headless-impl – shell_pid=5214 – lane=doing – Started implementation via workflow command
- 2026-03-26T01:57:46Z – headless-impl – shell_pid=5214 – lane=for_review – Ready for review: addressed all 3 feedback issues — flutter-test-integration in root justfile, setupFailureScreenshots() with captureScreenshot() API and .gitkeep, expectRoute('/') exercised in auth_flow_test.dart
- 2026-03-26T01:57:58Z – headless-reviewer – shell_pid=10920 – lane=doing – Started review via workflow command
- 2026-03-26T02:01:33Z – headless-reviewer – shell_pid=10920 – lane=planned – Moved to planned
- 2026-03-26T02:01:44Z – headless-impl – shell_pid=18132 – lane=doing – Started implementation via workflow command
- 2026-03-26T02:03:16Z – headless-impl – shell_pid=18132 – lane=for_review – Ready for review: switched integration tests from flutter test to flutter drive (flutter test does not support web devices in Flutter 3.38.5), added test_driver/integration_test.dart, called setupFailureScreenshots() in auth_flow_test.dart, documented httpMocks key format constraint
- 2026-03-26T02:03:23Z – headless-reviewer – shell_pid=20192 – lane=doing – Started review via workflow command
