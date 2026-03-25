import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/components/game/player_circle.dart';
import 'package:midnight_village/design_system/models/player_display.dart';

import '../../../design_system/test_helpers/pump_with_tokens.dart';
import '../../../design_system/test_helpers/test_theme.dart';

void main() {
  // ---------------------------------------------------------------------------
  // Helpers
  // ---------------------------------------------------------------------------

  const testTheme = TestThemeTokens();

  /// Build a minimal list of players suitable for most tests.
  List<PlayerDisplay> _buildPlayers({
    String currentPlayerId = 'p1',
    List<String> selectedIds = const [],
    List<String> nonSelectableIds = const [],
    Map<String, PlayerStatus> statuses = const {},
  }) {
    const allIds = ['p1', 'p2', 'p3'];
    return allIds.map((id) {
      return PlayerDisplay(
        id: id,
        displayName: 'Player $id',
        isCurrentPlayer: id == currentPlayerId,
        isSelectable: !nonSelectableIds.contains(id),
        isSelected: selectedIds.contains(id),
        status: statuses[id] ?? PlayerStatus.active,
      );
    }).toList();
  }

  // ---------------------------------------------------------------------------
  // Test 1: tap callback fires with the correct player ID
  // ---------------------------------------------------------------------------

  testWidgets('tap callback fires with the tapped player ID', (tester) async {
    final tapped = <String>[];
    final players = _buildPlayers();

    await tester.pumpWithTokens(
      PlayerCircle(
        players: players,
        onPlayerSelected: tapped.add,
      ),
      theme: testTheme,
    );

    // Tap a non-current player (p2).
    await tester.tap(find.text('Player p2'));
    await tester.pump();

    expect(tapped, ['p2']);
  });

  // ---------------------------------------------------------------------------
  // Test 2: tapping the current player does nothing (self-exclusion guard)
  // ---------------------------------------------------------------------------

  testWidgets('tapping current player does not fire callback', (tester) async {
    final tapped = <String>[];
    final players = _buildPlayers(currentPlayerId: 'p1');

    await tester.pumpWithTokens(
      PlayerCircle(
        players: players,
        onPlayerSelected: tapped.add,
      ),
      theme: testTheme,
    );

    await tester.tap(find.text('Player p1 (You)'));
    await tester.pump();

    expect(tapped, isEmpty);
  });

  // ---------------------------------------------------------------------------
  // Test 3: maxSelections: 1 — once one player is selected, tapping another
  //         non-selected player does nothing
  // ---------------------------------------------------------------------------

  testWidgets(
      'maxSelections: 1 — tapping another player when one already selected does nothing',
      (tester) async {
    final tapped = <String>[];
    // p2 is already selected.
    final players = _buildPlayers(selectedIds: ['p2']);

    await tester.pumpWithTokens(
      PlayerCircle(
        players: players,
        onPlayerSelected: tapped.add,
        maxSelections: 1,
      ),
      theme: testTheme,
    );

    // p3 is unselected and the max is reached — tap should be ignored.
    await tester.tap(find.text('Player p3'));
    await tester.pump();

    expect(tapped, isEmpty,
        reason: 'max selections reached; p3 tap must be swallowed');
  });

  // ---------------------------------------------------------------------------
  // Test 4: showStatus: true renders eliminated overlay (error-colored icon)
  // ---------------------------------------------------------------------------

  testWidgets('showStatus: true renders an error-colored icon for eliminated player',
      (tester) async {
    final players = _buildPlayers(
      statuses: {'p2': PlayerStatus.eliminated},
    );

    await tester.pumpWithTokens(
      PlayerCircle(players: players, showStatus: true),
      theme: testTheme,
    );

    // The eliminated overlay uses Icons.close with the error color.
    final closeIconFinder = find.byWidgetPredicate((widget) {
      if (widget is Icon && widget.icon == Icons.close) {
        // TestColorTokens.error = Color(0xFFFF0000)
        return widget.color == const Color(0xFFFF0000);
      }
      return false;
    });

    expect(closeIconFinder, findsOneWidget,
        reason: 'eliminated player should show error-colored close icon');
  });

  // ---------------------------------------------------------------------------
  // Test 5: current player is NOT dimmed (full opacity, not _kDimOpacity)
  // ---------------------------------------------------------------------------

  testWidgets('current player slot has full opacity, not dimmed', (tester) async {
    final players = _buildPlayers(currentPlayerId: 'p1');

    await tester.pumpWithTokens(
      PlayerCircle(
        players: players,
        // Provide a callback so that non-current players become dimmed when
        // max is reached, giving us contrast to assert against.
        onPlayerSelected: (_) {},
      ),
      theme: testTheme,
    );

    // Find all Opacity widgets whose child subtree contains the current player's
    // text. None of them should have opacity == _kDimOpacity (0.45).
    const kDimOpacity = 0.45;

    final opacityWidgets = tester.widgetList<Opacity>(find.byType(Opacity));
    for (final op in opacityWidgets) {
      // Check if this Opacity widget wraps the current player avatar by looking
      // for the player text inside it.
      final element = tester.element(
        find.byWidgetPredicate((w) => identical(w, op)),
      );
      final containsCurrentPlayer = find
          .descendant(
            of: find.byElementPredicate((e) => identical(e, element)),
            matching: find.text('Player p1 (You)'),
          )
          .evaluate()
          .isNotEmpty;

      if (containsCurrentPlayer) {
        expect(op.opacity, isNot(kDimOpacity),
            reason: 'current player must not be dimmed with _kDimOpacity');
      }
    }
  });
}
