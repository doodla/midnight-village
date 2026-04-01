import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/components/game/role_card.dart';
import 'package:midnight_village/features/game/domain/game_session_state.dart';
import 'package:midnight_village/features/game/domain/night_state.dart';
import 'package:midnight_village/features/game/presentation/night_result_view.dart';

import '../../../design_system/test_helpers/pump_with_tokens.dart';

/// Helper to build a test ActionResult.
ActionResult _makeResult(String actionType, Map<String, dynamic> extra) =>
    ActionResult(wave: 1, revealedInfo: {'action_type': actionType, ...extra});

/// Test players list.
const _players = [
  GamePlayer(playerId: 1, displayName: 'Alice'),
  GamePlayer(playerId: 2, displayName: 'Bob'),
  GamePlayer(playerId: 3, displayName: 'Charlie'),
];

void main() {
  group('NightResultView — peek_player', () {
    testWidgets('shows target name and RoleCard', (tester) async {
      await tester.pumpWithTokens(
        NightResultView(
          result: _makeResult('peek_player', {
            'target_name': 'Alice',
            'role': 'werewolf',
          }),
          players: _players,
        ),
      );

      expect(find.textContaining('Alice'), findsOneWidget);
      expect(find.byType(RoleCard), findsAtLeastNWidgets(1));
    });
  });

  group('NightResultView — peek_center', () {
    testWidgets('shows center card result text and RoleCards', (tester) async {
      await tester.pumpWithTokens(
        NightResultView(
          result: _makeResult('peek_center', {
            'roles': ['seer', 'villager'],
            'card_indices': [0, 2],
          }),
          players: _players,
        ),
      );

      expect(find.textContaining('center card'), findsAtLeastNWidgets(1));
      expect(find.byType(RoleCard), findsAtLeastNWidgets(1));
    });
  });

  group('NightResultView — swap_with_player (Robber)', () {
    testWidgets('shows swap confirmation with new role', (tester) async {
      await tester.pumpWithTokens(
        NightResultView(
          result: _makeResult('swap_with_player', {
            'target_name': 'Bob',
            'new_role': 'villager',
          }),
          players: _players,
        ),
      );

      expect(find.textContaining('Bob'), findsAtLeastNWidgets(1));
      expect(find.byType(RoleCard), findsAtLeastNWidgets(1));
    });
  });

  group('NightResultView — swap_with_center (Drunk)', () {
    testWidgets('shows swap confirmation without role reveal', (tester) async {
      await tester.pumpWithTokens(
        NightResultView(
          result: _makeResult('swap_with_center', {'card_index': 1}),
          players: _players,
        ),
      );

      expect(find.textContaining('center card'), findsAtLeastNWidgets(1));
    });
  });

  group('NightResultView — swap_others (Troublemaker)', () {
    testWidgets('shows both player names', (tester) async {
      await tester.pumpWithTokens(
        NightResultView(
          result: _makeResult('swap_others', {
            'player1_name': 'Alice',
            'player2_name': 'Charlie',
          }),
          players: _players,
        ),
      );

      expect(find.textContaining('Alice'), findsOneWidget);
      expect(find.textContaining('Charlie'), findsOneWidget);
    });
  });

  group('NightResultView — see_team (Werewolf with teammates)', () {
    testWidgets('shows fellow werewolf names', (tester) async {
      await tester.pumpWithTokens(
        NightResultView(
          result: _makeResult('see_team', {
            'role_acting_as': 'Werewolf',
            'teammate_names': ['Bob'],
          }),
          players: _players,
        ),
      );

      expect(find.textContaining('Bob'), findsAtLeastNWidgets(1));
      expect(find.textContaining('fellow'), findsAtLeastNWidgets(1));
    });
  });

  group('NightResultView — see_team (lone Werewolf)', () {
    testWidgets('shows skip message when no center card peeked', (
      tester,
    ) async {
      await tester.pumpWithTokens(
        NightResultView(
          result: _makeResult('see_team', {
            'role_acting_as': 'Werewolf',
            'teammate_names': [],
          }),
          players: _players,
        ),
      );

      expect(find.textContaining('lone Werewolf'), findsOneWidget);
      expect(find.textContaining('chose not to peek'), findsOneWidget);
    });

    testWidgets('shows peeked center card when present', (tester) async {
      await tester.pumpWithTokens(
        NightResultView(
          result: _makeResult('see_team', {
            'role_acting_as': 'Werewolf',
            'teammate_names': [],
            'center_card': {'index': 0, 'role': 'tanner'},
          }),
          players: _players,
        ),
      );

      expect(find.textContaining('peeked'), findsOneWidget);
      expect(find.byType(RoleCard), findsAtLeastNWidgets(1));
    });
  });

  group('NightResultView — see_team (lone Mason)', () {
    testWidgets('shows lone mason message', (tester) async {
      await tester.pumpWithTokens(
        NightResultView(
          result: _makeResult('see_team', {
            'role_acting_as': 'Mason',
            'teammate_names': [],
          }),
          players: _players,
        ),
      );

      expect(find.textContaining('only Mason'), findsOneWidget);
    });
  });

  group('NightResultView — see_team (Minion with no werewolves)', () {
    testWidgets('shows no werewolves message', (tester) async {
      await tester.pumpWithTokens(
        NightResultView(
          result: _makeResult('see_team', {
            'role_acting_as': 'Minion',
            'teammate_names': [],
          }),
          players: _players,
        ),
      );

      expect(find.textContaining('no werewolves'), findsOneWidget);
    });
  });

  group('NightResultView — see_team (Minion with werewolves)', () {
    testWidgets('shows werewolf names', (tester) async {
      await tester.pumpWithTokens(
        NightResultView(
          result: _makeResult('see_team', {
            'role_acting_as': 'Minion',
            'teammate_names': ['Alice', 'Charlie'],
          }),
          players: _players,
        ),
      );

      expect(find.textContaining('Alice'), findsOneWidget);
      expect(find.textContaining('Charlie'), findsOneWidget);
    });
  });

  group('NightResultView — Insomniac', () {
    testWidgets('shows current role', (tester) async {
      await tester.pumpWithTokens(
        NightResultView(
          result: _makeResult('insomniac', {'current_role': 'villager'}),
          players: _players,
        ),
      );

      expect(find.textContaining('card is now'), findsOneWidget);
      expect(find.byType(RoleCard), findsAtLeastNWidgets(1));
    });
  });

  group('NightResultView — unknown action type', () {
    testWidgets('renders without crashing for unknown type', (tester) async {
      await tester.pumpWithTokens(
        NightResultView(
          result: _makeResult('unknown_action', {}),
          players: _players,
        ),
      );

      expect(tester.takeException(), isNull);
    });
  });
}
