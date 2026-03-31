import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/components/game/vote_submission.dart';
import 'package:midnight_village/design_system/models/player_display.dart';
import 'package:midnight_village/design_system/tokens/app_tokens_provider.dart';
import 'package:midnight_village/design_system/tokens/theme_bridge.dart';

import '../../../design_system/test_helpers/test_theme.dart';

// Use a tall logical size so the full widget fits without overflow in tests.
const _kTestScreenSize = Size(400, 800);

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

const _testTheme = TestThemeTokens();

/// Pumps a [VoteSubmission] inside a full-screen [Scaffold] so that
/// [Expanded] widgets receive a bounded height constraint from the test harness.
Future<void> _pumpVoteSubmission(
  WidgetTester tester, {
  required List<PlayerDisplay> players,
  required ValueChanged<String> onVoteSubmitted,
  Duration timeRemaining = const Duration(minutes: 1),
  bool isLocked = false,
}) async {
  tester.view.physicalSize = _kTestScreenSize * tester.view.devicePixelRatio;
  addTearDown(tester.view.resetPhysicalSize);

  await tester.pumpWidget(
    ProviderScope(
      overrides: [activeThemeProvider.overrideWithValue(_testTheme)],
      child: MaterialApp(
        theme: generateThemeData(_testTheme),
        home: Scaffold(
          body: VoteSubmission(
            players: players,
            timeRemaining: timeRemaining,
            onVoteSubmitted: onVoteSubmitted,
            isLocked: isLocked,
          ),
        ),
      ),
    ),
  );
}

/// Three generic non-current, selectable players.
List<PlayerDisplay> _threePlayers() => const [
  PlayerDisplay(id: 'p1', displayName: 'Alice'),
  PlayerDisplay(id: 'p2', displayName: 'Bob'),
  PlayerDisplay(id: 'p3', displayName: 'Carol'),
];

// ---------------------------------------------------------------------------
// Tests
// ---------------------------------------------------------------------------

void main() {
  // -------------------------------------------------------------------------
  // Confirm button is disabled when no player is selected
  // -------------------------------------------------------------------------

  testWidgets('confirm button is disabled when no player is selected', (
    tester,
  ) async {
    await _pumpVoteSubmission(
      tester,
      players: _threePlayers(),
      onVoteSubmitted: (_) {},
    );

    final confirmButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Lock in your vote'),
    );
    expect(
      confirmButton.onPressed,
      isNull,
      reason: '"Lock in your vote" must be disabled before a player is tapped',
    );
  });

  // -------------------------------------------------------------------------
  // Confirm button becomes enabled after a player is selected
  // -------------------------------------------------------------------------

  testWidgets('confirm button is enabled after tapping a player', (
    tester,
  ) async {
    await _pumpVoteSubmission(
      tester,
      players: _threePlayers(),
      onVoteSubmitted: (_) {},
    );

    await tester.tap(find.text('Alice'));
    await tester.pump();

    final confirmButton = tester.widget<FilledButton>(
      find.widgetWithText(FilledButton, 'Lock in your vote'),
    );
    expect(
      confirmButton.onPressed,
      isNotNull,
      reason: '"Lock in your vote" must be enabled after a player is tapped',
    );
  });

  // -------------------------------------------------------------------------
  // Confirm button calls onVoteSubmitted with correct player ID
  // -------------------------------------------------------------------------

  testWidgets(
    'confirm button calls onVoteSubmitted with the selected player ID',
    (tester) async {
      String? submittedId;

      await _pumpVoteSubmission(
        tester,
        players: _threePlayers(),
        onVoteSubmitted: (id) => submittedId = id,
      );

      // Select Bob (id: 'p2').
      await tester.tap(find.text('Bob'));
      await tester.pump();

      await tester.tap(find.widgetWithText(FilledButton, 'Lock in your vote'));
      await tester.pump();

      expect(
        submittedId,
        'p2',
        reason: 'onVoteSubmitted must receive the ID of the selected player',
      );
    },
  );

  // -------------------------------------------------------------------------
  // isLocked=true shows "Vote submitted" message and check icon
  // -------------------------------------------------------------------------

  testWidgets(
    'isLocked=true shows "Vote submitted" message and check_circle icon',
    (tester) async {
      await _pumpVoteSubmission(
        tester,
        players: _threePlayers(),
        onVoteSubmitted: (_) {},
        isLocked: true,
      );

      // The generic confirmation message must be visible.
      expect(find.text('Vote submitted'), findsOneWidget);
      expect(find.text('Your vote has been submitted.'), findsOneWidget);

      // The check_circle icon must appear with the primary test token color.
      // TestColorTokens.primary = Color(0xFF00FF00)
      final checkIconFinder = find.byWidgetPredicate((widget) {
        if (widget is Icon && widget.icon == Icons.check_circle) {
          return widget.color == const Color(0xFF00FF00);
        }
        return false;
      });
      expect(
        checkIconFinder,
        findsOneWidget,
        reason:
            'check_circle icon with primary token color must be visible after vote is locked',
      );
    },
  );

  // -------------------------------------------------------------------------
  // isLocked=true does NOT show player names prominently
  //
  // "Prominently" means: no Text widget using heading/subheading/body typography
  // that contains any player name.  The player circle (and its caption-sized
  // player name labels) are not rendered in the locked state at all, so this
  // check is straightforward: none of the player display names must appear in
  // any Text with a font size >= body (18 pt in the test theme).
  // -------------------------------------------------------------------------

  testWidgets('isLocked=true does not display any player name in large text', (
    tester,
  ) async {
    await _pumpVoteSubmission(
      tester,
      players: _threePlayers(),
      onVoteSubmitted: (_) {},
      isLocked: true,
    );

    const playerNames = ['Alice', 'Bob', 'Carol'];
    // Body font size in TestTypographyTokens is 18.
    const kBodyFontSize = 18.0;

    for (final name in playerNames) {
      // Look for any Text widget that (a) contains the player name and
      // (b) is rendered at body-or-larger font size.
      final largeNameFinder = find.byWidgetPredicate((widget) {
        if (widget is! Text) return false;
        final data = widget.data ?? '';
        if (!data.contains(name)) return false;
        final fontSize = widget.style?.fontSize;
        return fontSize != null && fontSize >= kBodyFontSize;
      });

      expect(
        largeNameFinder,
        findsNothing,
        reason:
            'Player name "$name" must not appear in large text when vote is locked',
      );
    }
  });

  // -------------------------------------------------------------------------
  // Timer is visible in the pre-vote state
  // -------------------------------------------------------------------------

  testWidgets('timer is visible in pre-vote state (isLocked=false)', (
    tester,
  ) async {
    await _pumpVoteSubmission(
      tester,
      players: _threePlayers(),
      onVoteSubmitted: (_) {},
      timeRemaining: const Duration(minutes: 2),
      isLocked: false,
    );

    // GameTimer formats 2 minutes as "02:00".
    expect(
      find.text('02:00'),
      findsOneWidget,
      reason: 'Timer must be visible in pre-vote state',
    );
  });

  // -------------------------------------------------------------------------
  // Timer is visible in the post-vote (locked) state
  // -------------------------------------------------------------------------

  testWidgets('timer is visible in post-vote state (isLocked=true)', (
    tester,
  ) async {
    await _pumpVoteSubmission(
      tester,
      players: _threePlayers(),
      onVoteSubmitted: (_) {},
      timeRemaining: const Duration(minutes: 2),
      isLocked: true,
    );

    // Timer must still be shown so players know the phase has not ended.
    expect(
      find.text('02:00'),
      findsOneWidget,
      reason: 'Timer must remain visible after vote is locked',
    );
  });

  // -------------------------------------------------------------------------
  // Player circle shows all players in pre-vote state
  // -------------------------------------------------------------------------

  testWidgets('player circle shows all player names in pre-vote state', (
    tester,
  ) async {
    await _pumpVoteSubmission(
      tester,
      players: _threePlayers(),
      onVoteSubmitted: (_) {},
      isLocked: false,
    );

    expect(find.text('Alice'), findsOneWidget);
    expect(find.text('Bob'), findsOneWidget);
    expect(find.text('Carol'), findsOneWidget);
  });

  // -------------------------------------------------------------------------
  // Tapping a player again deselects them (toggle behaviour)
  // -------------------------------------------------------------------------

  testWidgets(
    'tapping the selected player again deselects and disables confirm',
    (tester) async {
      await _pumpVoteSubmission(
        tester,
        players: _threePlayers(),
        onVoteSubmitted: (_) {},
      );

      // Select Alice.
      await tester.tap(find.text('Alice'));
      await tester.pump();

      // Confirm should be enabled.
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Lock in your vote'),
            )
            .onPressed,
        isNotNull,
      );

      // Tap Alice again to deselect.
      await tester.tap(find.text('Alice'));
      await tester.pump();

      // Confirm should be disabled again.
      expect(
        tester
            .widget<FilledButton>(
              find.widgetWithText(FilledButton, 'Lock in your vote'),
            )
            .onPressed,
        isNull,
        reason: 'Deselecting the player must disable the confirm button again',
      );
    },
  );
}
