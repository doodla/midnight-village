# Quickstart: Flutter UI Test Infrastructure

**Feature**: 002-flutter-ui-test-infrastructure
**Date**: 2026-03-25

## Prerequisites

- Flutter SDK (stable channel, Dart ^3.10.4)
- Project dependencies installed: `cd frontend && flutter pub get`
- Fonts bundled in `frontend/assets/fonts/` (already committed)

## Running Tests

```bash
# From project root:
just flutter-test              # All widget + golden tests
just flutter-test-golden       # Golden tests only (NEW)
just flutter-test-integration  # Integration tests on Chrome headless (NEW)
just flutter-golden-update     # Regenerate all golden baselines (NEW)
just flutter-golden-report     # Generate visual diff report after failures (NEW)

# From frontend/:
just test                      # All widget + golden tests
just test-golden               # Golden tests only (NEW)
just test-integration          # Integration tests (NEW)
just golden-update             # Regenerate baselines (NEW)
just golden-report             # Visual diff report (NEW)
```

## Writing a Golden Test

```dart
import 'package:flutter_test/flutter_test.dart';
import '../../helpers/golden_test_helper.dart';
import '../../design_system/test_helpers/pump_with_tokens.dart';

void main() {
  setUpGoldenTests(); // Load fonts, set screen size

  testWidgets('MvButton renders correctly', (tester) async {
    await tester.pumpWithGolden(
      const MvButton(label: 'Test', onPressed: null),
    );
    await expectLater(
      find.byType(MvButton),
      matchesGoldenFile('goldens/${platformDir()}/mv_button.png'),
    );
  });
}
```

**Key points:**
- Call `setUpGoldenTests()` once per test file to load fonts and set screen size
- Use `platformDir()` to get `macos` or `linux` for platform-specific baselines
- First run generates the baseline; subsequent runs compare against it
- Update baselines: `just flutter-golden-update`

## Writing a Widget Test with Harness

```dart
import 'package:flutter_test/flutter_test.dart';
import '../../helpers/test_harness.dart';

void main() {
  testWidgets('shows home screen when authenticated', (tester) async {
    await tester.pumpAuthenticated(
      const HomeScreen(),
      user: User(id: 1, displayName: 'TestPlayer'),
    );

    expect(find.text('TestPlayer'), findsOneWidget);
    expect(find.text('Join Game'), findsOneWidget);
  });
}
```

**Key points:**
- `pumpAuthenticated` sets up auth providers with a test user in ≤5 lines
- Pass custom `User` or use the default test user
- Add `additionalOverrides` for extra Riverpod provider overrides

## Writing a Widget Test with Game State

```dart
import 'package:flutter_test/flutter_test.dart';
import '../../helpers/test_harness.dart';
import '../../helpers/mock_websocket.dart';

void main() {
  testWidgets('voting screen shows player list', (tester) async {
    final ws = FakeWebSocketChannel();

    await tester.pumpWithGameState(
      const VoteSubmission(),
      phase: GamePhase.voting,
      players: [
        PlayerDisplay(id: 1, name: 'Alice', status: PlayerStatus.alive),
        PlayerDisplay(id: 2, name: 'Bob', status: PlayerStatus.alive),
      ],
      webSocket: ws,
    );

    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('Bob'), findsOneWidget);

    // Simulate server event
    ws.addServerEvent({'type': 'vote_submitted', 'player_id': 1});
    await tester.pumpAndSettle();

    expect(find.text('Vote recorded'), findsOneWidget);
  });
}
```

## Writing an Integration Test

```dart
// integration_test/auth_flow_test.dart
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'helpers/integration_test_helper.dart';

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('auth flow: welcome → enter name → home', (tester) async {
    await tester.pumpIntegrationApp();

    // Welcome screen
    expect(find.text('Welcome to Midnight Village'), findsOneWidget);

    // Enter name
    await tester.enterText(find.byType(TextField), 'TestPlayer');
    await tester.tap(find.text('Enter'));
    await tester.pumpAndSettle();

    // Home screen
    expect(find.text('TestPlayer'), findsOneWidget);
  });
}
```

**Key points:**
- Integration tests go in `integration_test/` directory
- Use `IntegrationTestWidgetsFlutterBinding.ensureInitialized()`
- Run with: `just flutter-test-integration`
- HTTP calls are mocked via the same `MockHttpInterceptor`

## Using Mock HTTP

```dart
import '../../helpers/mock_http_client.dart';

void main() {
  late MockHttpInterceptor http;

  setUp(() {
    http = MockHttpInterceptor();
  });

  testWidgets('shows error on API failure', (tester) async {
    http.stubError('POST', '/auth/guest/',
      DioException(type: DioExceptionType.connectionTimeout, requestOptions: RequestOptions()));

    await tester.pumpApp(http: http);
    await tester.tap(find.text('Enter'));
    await tester.pumpAndSettle();

    expect(find.text('Network error'), findsOneWidget);
  });
}
```

**Key points:**
- `stub(method, path, response)` registers a canned response
- `stubError(method, path, exception)` registers an error
- Unmocked requests throw `UnmockedRequestException` (tests fail loudly)
- `http.requests` captures all requests for assertion
- Call `http.reset()` in `setUp` to clear stubs between tests

## Using Timer Control

```dart
import '../../helpers/timer_control.dart';

testWidgets('timer shows urgency at 10 seconds', (tester) async {
  final timer = FakeTimer(duration: Duration(seconds: 30));

  await tester.pumpWithGameState(
    const GameTimer(),
    phase: GamePhase.discussion,
    timer: timer,
  );

  // Advance to 10 seconds remaining
  timer.advance(Duration(seconds: 20));
  await tester.pump();

  // Verify urgency styling
  final text = tester.widget<Text>(find.text('0:10'));
  expect(text.style?.color, equals(testTheme.colors.timerUrgent));
});
```

## Debugging Golden Test Failures

1. **Run the failing test**: `just flutter-test-golden`
2. **Check failure output**: Flutter saves images to `test/failures/`
3. **Generate diff report**: `just flutter-golden-report`
4. **Review**: Open `golden_diff_output/report.html` in browser
5. **If intentional**: `just flutter-golden-update` to regenerate baselines
6. **If regression**: Fix the widget code and re-run

## File Locations

| What | Where |
|------|-------|
| Shared test helpers | `frontend/test/helpers/` |
| Theme test helpers | `frontend/test/design_system/test_helpers/` |
| Golden baselines | `frontend/test/design_system/goldens/{platform}/` |
| Integration tests | `frontend/integration_test/` |
| Visual diff tool | `frontend/tool/golden_diff_report.dart` |
| Diff report output | `frontend/golden_diff_output/` (gitignored) |
| Global test config | `frontend/test/flutter_test_config.dart` |
