# Quickstart: Using the Design System

**Feature**: 001-frontend-design-system-and-architecture
**Date**: 2026-03-24

## Reading Tokens in a Widget

Every widget that needs themed styling reads from the `activeThemeProvider`:

```dart
class MyScreen extends ConsumerWidget {
  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final tokens = ref.watch(activeThemeProvider);

    return Container(
      color: tokens.colors.background,
      padding: EdgeInsets.all(tokens.spacing.m),
      child: Text(
        'Hello',
        style: tokens.typography.heading,
      ),
    );
  }
}
```

## Using Core Components

Core components are prefixed with `Mv` to avoid shadowing Flutter's built-in widgets:

```dart
import 'package:midnight_village/design_system/components/core/mv_button.dart';
import 'package:midnight_village/design_system/components/core/mv_card.dart';

// In your build method:
MvCard(
  child: Column(
    children: [
      Text('Welcome', style: tokens.typography.heading),
      SizedBox(height: tokens.spacing.m),
      MvButton(
        label: 'Start Game',
        onPressed: () => startGame(),
      ),
    ],
  ),
)
```

## Using Game Components

Game components accept domain data and render themed UI:

```dart
import 'package:midnight_village/design_system/components/game/role_card.dart';
import 'package:midnight_village/design_system/components/game/player_circle.dart';

// Show a role card
RoleCard(role: RoleId.werewolf, isFaceUp: true)

// Player selection for voting
PlayerCircle(
  players: playerList,
  onPlayerSelected: (playerId) => submitVote(playerId),
  maxSelections: 1,
)
```

## Writing Tests

Use the test helpers to wrap widgets with a token provider:

```dart
import 'package:midnight_village/design_system/tokens/app_tokens.dart';
import 'package:flutter_test/flutter_test.dart';
import '../test_helpers/pump_with_tokens.dart';
import '../test_helpers/test_theme.dart';

void main() {
  testWidgets('role card displays team color', (tester) async {
    await tester.pumpWithTokens(
      RoleCard(role: RoleId.werewolf, isFaceUp: true),
    );

    // Assert: card uses werewolf team color
    final card = tester.widget<Container>(find.byType(Container).first);
    // ... assertions
  });

  testWidgets('renders with alternate theme', (tester) async {
    await tester.pumpWithTokens(
      RoleCard(role: RoleId.werewolf, isFaceUp: true),
      theme: TestThemeTokens(),  // alternate theme
    );

    // Assert: card uses test theme's werewolf team color
    // ...
  });
}
```

The `pumpWithTokens` helper wraps the widget in a `ProviderScope` with the active theme provider overridden. Default is `MidnightVillageTheme`, pass a different `AppTokens` to test with alternate themes.

## Adding a New Theme

1. Create a new file in `lib/design_system/tokens/`:

```dart
class ForestMoonTheme implements AppTokens {
  const ForestMoonTheme();

  @override
  String get name => 'Forest Moon';

  @override
  AppColorTokens get colors => const ForestMoonColors();

  @override
  AppTypographyTokens get typography => const ForestMoonTypography();

  @override
  AppSpacingTokens get spacing => const ForestMoonSpacing();

  @override
  AppElevationTokens get elevation => const ForestMoonElevation();
}

// Implement all sub-contracts...
```

2. The compiler enforces completeness — if any token is missing, the code won't compile.

3. Activate it: `ref.read(activeThemeProvider.notifier).switchTheme(ForestMoonTheme())`

## Architecture: Building a New Game Feature

When creating a new screen (e.g., the voting screen):

1. **Create the feature module** in `lib/features/game/`:
   - `domain/` — Models for the screen's data (e.g., `VoteState`)
   - `data/` — Service that talks to backend API/WebSocket
   - `presentation/` — Riverpod notifier + screen widget

2. **Screen widget** is a `ConsumerWidget` that:
   - Watches `activeThemeProvider` for tokens
   - Watches the feature's state notifier for game data
   - Composes design system components (don't build raw widgets)

3. **No game logic in the client**. The screen:
   - Displays what the server sends
   - Sends player actions to the server
   - Reacts to server state changes via WebSocket events

4. **Navigation** is driven by game phase. When the server sends a phase change event, the router navigates to the corresponding screen.
