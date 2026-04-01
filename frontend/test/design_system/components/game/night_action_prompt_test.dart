import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/components/game/night_action_prompt.dart';
import 'package:midnight_village/design_system/models/night_action.dart';
import 'package:midnight_village/design_system/models/player_display.dart';
import 'package:midnight_village/design_system/models/role.dart';
import 'package:midnight_village/design_system/tokens/app_tokens_provider.dart';
import 'package:midnight_village/design_system/tokens/theme_bridge.dart';

import '../../../design_system/test_helpers/test_theme.dart';

// Use a tall logical size so the full prompt fits without overflow in tests.
const _kTestScreenSize = Size(400, 1000);

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const _testTheme = TestThemeTokens();

/// Pumps a [NightActionPrompt] inside a full-screen [Scaffold] so that
/// [Expanded] widgets get a bounded height constraint from the test harness.
Future<void> _pumpPrompt(
  WidgetTester tester, {
  required NightActionType actionType,
  required ValueChanged<NightActionSelection> onActionSubmitted,
  RoleId playerRole = RoleId.seer,
  List<PlayerDisplay> players = const [],
  int centerCardCount = 3,
  Duration timeRemaining = const Duration(minutes: 1),
  VoidCallback? onSkip,
}) async {
  tester.view.physicalSize = _kTestScreenSize * tester.view.devicePixelRatio;
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [activeThemeProvider.overrideWithValue(_testTheme)],
      child: MaterialApp(
        theme: generateThemeData(_testTheme),
        home: Scaffold(
          body: NightActionPrompt(
            actionType: actionType,
            playerRole: playerRole,
            players: players,
            centerCardCount: centerCardCount,
            timeRemaining: timeRemaining,
            onActionSubmitted: onActionSubmitted,
            onSkip: onSkip,
          ),
        ),
      ),
    ),
  );
}

/// Returns three generic non-current players.
List<PlayerDisplay> _threePlayers() => [
  const PlayerDisplay(id: 'p1', displayName: 'Alice'),
  const PlayerDisplay(id: 'p2', displayName: 'Bob'),
  const PlayerDisplay(id: 'p3', displayName: 'Carol'),
];

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // -------------------------------------------------------------------------
  // peekPlayer: confirm button disabled until a player is selected
  // -------------------------------------------------------------------------

  testWidgets('peekPlayer — confirm button disabled when no player selected', (
    tester,
  ) async {
    await _pumpPrompt(
      tester,
      actionType: NightActionType.peekPlayer,
      players: _threePlayers(),
      onActionSubmitted: (_) {},
    );

    // The FilledButton labelled 'Confirm' should have a null onPressed,
    // which Flutter renders as a disabled button.
    final confirmButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Confirm'),
    );
    expect(
      confirmButton.onPressed,
      isNull,
      reason: 'Confirm must be disabled before any player is tapped',
    );
  });

  // -------------------------------------------------------------------------
  // peekPlayer: confirm button enabled after selection
  // -------------------------------------------------------------------------

  testWidgets('peekPlayer — confirm button enabled after selecting a player', (
    tester,
  ) async {
    await _pumpPrompt(
      tester,
      actionType: NightActionType.peekPlayer,
      players: _threePlayers(),
      onActionSubmitted: (_) {},
    );

    await tester.tap(find.text('Alice'));
    await tester.pump();

    final confirmButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Confirm'),
    );
    expect(
      confirmButton.onPressed,
      isNotNull,
      reason: 'Confirm must be enabled after a player is selected',
    );
  });

  // -------------------------------------------------------------------------
  // peekPlayer: fires PlayerTarget after selection + confirm
  // -------------------------------------------------------------------------

  testWidgets('peekPlayer — fires PlayerTarget with correct id on confirm', (
    tester,
  ) async {
    NightActionSelection? submitted;

    await _pumpPrompt(
      tester,
      actionType: NightActionType.peekPlayer,
      players: _threePlayers(),
      onActionSubmitted: (s) => submitted = s,
    );

    await tester.tap(find.text('Bob'));
    await tester.pump();
    await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
    await tester.pump();

    expect(submitted, isA<PlayerTarget>());
    expect((submitted as PlayerTarget).playerId, 'p2');
  });

  // -------------------------------------------------------------------------
  // swapOthers: fires TwoPlayerTargets after 2 selections + confirm
  // -------------------------------------------------------------------------

  testWidgets(
    'swapOthers — fires TwoPlayerTargets with both player ids on confirm',
    (tester) async {
      NightActionSelection? submitted;

      await _pumpPrompt(
        tester,
        actionType: NightActionType.swapOthers,
        playerRole: RoleId.troublemaker,
        players: _threePlayers(),
        onActionSubmitted: (s) => submitted = s,
      );

      // Select Alice then Bob.
      await tester.tap(find.text('Alice'));
      await tester.pump();
      await tester.tap(find.text('Bob'));
      await tester.pump();

      await tester.tap(find.widgetWithText(FilledButton, 'Confirm'));
      await tester.pump();

      expect(submitted, isA<TwoPlayerTargets>());
      final two = submitted as TwoPlayerTargets;
      expect({two.player1Id, two.player2Id}, {'p1', 'p2'});
    },
  );

  // -------------------------------------------------------------------------
  // seeTeam: fires NoAction on acknowledge
  // -------------------------------------------------------------------------

  testWidgets('seeTeam — fires NoAction when Acknowledge is tapped', (
    tester,
  ) async {
    NightActionSelection? submitted;

    await _pumpPrompt(
      tester,
      actionType: NightActionType.seeTeam,
      playerRole: RoleId.werewolf,
      players: const [],
      onActionSubmitted: (s) => submitted = s,
    );

    await tester.tap(find.widgetWithText(FilledButton, 'Acknowledge'));
    await tester.pump();

    expect(submitted, isA<NoAction>());
  });

  // -------------------------------------------------------------------------
  // Skip button absent when onSkip is null
  // -------------------------------------------------------------------------

  testWidgets('Skip button is absent when onSkip is null', (tester) async {
    await _pumpPrompt(
      tester,
      actionType: NightActionType.seeTeam,
      playerRole: RoleId.werewolf,
      onActionSubmitted: (_) {},
      onSkip: null,
    );

    expect(find.widgetWithText(OutlinedButton, 'Skip'), findsNothing);
  });

  // -------------------------------------------------------------------------
  // Skip button present when onSkip is provided
  // -------------------------------------------------------------------------

  testWidgets('Skip button is present when onSkip is provided', (tester) async {
    bool skipped = false;

    await _pumpPrompt(
      tester,
      actionType: NightActionType.seeTeam,
      playerRole: RoleId.werewolf,
      onActionSubmitted: (_) {},
      onSkip: () => skipped = true,
    );

    expect(find.widgetWithText(OutlinedButton, 'Skip'), findsOneWidget);

    await tester.tap(find.widgetWithText(OutlinedButton, 'Skip'));
    await tester.pump();

    expect(skipped, isTrue);
  });
}
