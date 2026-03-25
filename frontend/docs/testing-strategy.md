# Frontend Testing Strategy

This document defines how to test any frontend code in Midnight Village. It answers "how do I test this?" for any kind of code you write.

**Coverage target**: 80% minimum for all design system code.

---

## Test Organization

Tests mirror the source tree exactly:

```
test/
├── core/
│   ├── api/         → tests for lib/core/api/
│   └── storage/     → tests for lib/core/storage/
├── design_system/
│   ├── test_helpers/   → shared test utilities (not test files)
│   ├── tokens/         → tests for lib/design_system/tokens/
│   └── components/
│       ├── core/       → tests for core UI components
│       └── game/       → tests for game-specific components
├── features/
│   ├── auth/           → tests for lib/features/auth/
│   └── game/           → tests for lib/features/game/ (when built)
└── design_system/
    └── examples/       → runnable pattern examples (copy and adapt these)
```

Run all tests:
```bash
just flutter-test
```

---

## Unit Tests — Domain Models and Notifiers

Unit tests are pure Dart: no Flutter widgets, no `pumpWidget`.

### Domain Model Tests

Domain models live in `lib/features/<feature>/domain/`. They have no Flutter dependencies, so tests are simple:

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/features/auth/domain/user.dart';

void main() {
  group('User', () {
    test('creates with valid id and display name', () {
      final user = User(id: 1, displayName: 'Alice');
      expect(user.id, 1);
      expect(user.displayName, 'Alice');
    });

    test('throws on non-positive id', () {
      expect(() => User(id: 0, displayName: 'Alice'), throwsArgumentError);
    });

    test('throws on empty display name', () {
      expect(() => User(id: 1, displayName: '  '), throwsArgumentError);
    });
  });
}
```

### Riverpod Notifier Tests

Test notifiers by creating a `ProviderContainer`, overriding dependencies with mocks, and asserting on state transitions:

```dart
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:midnight_village/features/game/data/game_service.dart';
import 'package:midnight_village/features/game/presentation/game_notifier.dart';

class MockGameService extends Mock implements GameService {}

void main() {
  test('GameNotifier updates state on phase change event', () {
    final mockService = MockGameService();
    when(() => mockService.fetchCurrentGame()).thenAnswer((_) async => /* ... */);

    final container = ProviderContainer(
      overrides: [
        gameServiceProvider.overrideWithValue(mockService),
      ],
    );
    addTearDown(container.dispose);

    final notifier = container.read(gameNotifierProvider.notifier);
    notifier.handleEvent(PhaseChangeEvent(phase: GamePhase.voting));

    expect(container.read(gameNotifierProvider), isA<GameVoting>());
  });
}
```

**Key rules for notifier tests:**
- Always call `addTearDown(container.dispose)` to clean up
- Override all providers the notifier reads with mocks
- Test state transitions, not implementation details

---

## Widget Tests — Components and Screens

Widget tests render Flutter widgets. Always use `pumpWithTokens` from `test/design_system/test_helpers/pump_with_tokens.dart` — it sets up the design token provider and a Material app wrapper.

### Basic Component Test

```dart
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/components/core/mv_button.dart';
import '../../test_helpers/pump_with_tokens.dart';

void main() {
  testWidgets('MvButton renders label', (tester) async {
    await tester.pumpWithTokens(
      MvButton(label: 'Continue', onPressed: () {}),
    );

    expect(find.text('Continue'), findsOneWidget);
  });

  testWidgets('MvButton is disabled when onPressed is null', (tester) async {
    await tester.pumpWithTokens(
      MvButton(label: 'Disabled', onPressed: null),
    );

    final button = tester.widget<ElevatedButton>(find.byType(ElevatedButton));
    expect(button.onPressed, isNull);
  });
}
```

### Testing State-Driven Widgets

For screens backed by a Riverpod notifier, override providers in `ProviderScope`:

```dart
testWidgets('NightPhaseScreen shows loading while waiting', (tester) async {
  final container = ProviderContainer(
    overrides: [
      gameNotifierProvider.overrideWith(() => FakeGameNotifier()),
    ],
  );

  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(home: NightPhaseScreen()),
    ),
  );

  expect(find.byType(MvLoading), findsOneWidget);
});
```

---

## Theme Compatibility Tests

Theme tests verify a component renders correctly under each theme without crashing or overflowing. Always test with both `MidnightVillageTheme` (production) and `TestThemeTokens` (distinct values that catch hardcoded colors).

```dart
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/components/core/mv_card.dart';
import 'package:midnight_village/design_system/tokens/midnight_village_theme.dart';
import '../../test_helpers/pump_with_tokens.dart';
import '../../test_helpers/test_theme.dart';

void main() {
  final themes = [
    const MidnightVillageTheme(),
    const TestThemeTokens(),
  ];

  for (final theme in themes) {
    testWidgets('MvCard renders without error with ${theme.name}', (tester) async {
      await tester.pumpWithTokens(
        const MvCard(child: Text('Content')),
        theme: theme,
      );

      expect(tester.takeException(), isNull);
      expect(find.text('Content'), findsOneWidget);
    });
  }
}
```

`TestThemeTokens` uses visually distinct values (bright green primary, magenta secondary) specifically to catch components that hardcode colors instead of reading from tokens.

---

## What to Mock

| Mock these | Don't mock these |
|---|---|
| HTTP services (`AuthService`, `GameService`) | Domain models (`User`, `GameState`) |
| WebSocket connections (`WsClient`) | Riverpod state logic (test the notifier directly) |
| Local storage (`TokenStorage`, `UserStorage`) | Widget rendering |
| External APIs | Design system components |

Use `mocktail` (already in `dev_dependencies`). Register fallback values for any custom types used in `when()` calls:

```dart
setUpAll(() {
  registerFallbackValue(const NightAction.none());
});
```

---

## Test Helpers

### `pumpWithTokens` — `test/design_system/test_helpers/pump_with_tokens.dart`

Wraps a widget in `ProviderScope` with the design token provider and a `MaterialApp`. Accepts an optional `theme` parameter.

```dart
extension PumpWithTokens on WidgetTester {
  Future<void> pumpWithTokens(Widget widget, {AppTokens? theme}) async { ... }
}
```

### `TestThemeTokens` — `test/design_system/test_helpers/test_theme.dart`

A complete `AppTokens` implementation with visually distinct values. Use it in theme compatibility tests to verify token consumption.

---

## Examples

Runnable, copy-paste-able examples live in `test/design_system/examples/`:

| File | Pattern demonstrated |
|---|---|
| `unit_test_example.dart` | Domain model invariants and serialization |
| `widget_test_example.dart` | Component rendering and interaction |
| `theme_test_example.dart` | Multi-theme compatibility |

These tests run as part of `just flutter-test`. Copy an example file and adapt it for your new component.
