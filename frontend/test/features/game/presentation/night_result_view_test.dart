import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/components/game/role_card.dart';
import 'package:midnight_village/features/game/domain/night_state.dart';
import 'package:midnight_village/features/game/presentation/night_result_view.dart';

import '../../../design_system/test_helpers/pump_with_tokens.dart';
import '../../../helpers/contract/from_sample.dart';
import '../../../helpers/contract/server_json.dart';
import '../../../helpers/game_state_factory.dart';

/// The server's night result of [kind] (`action_result_<kind>`), with
/// [info] as its values, parsed as the app parses it.
ActionResult _makeResult(String kind, Map<String, dynamic> info) =>
    FromSample.result(serverNightResult(kind, info: info));

/// Alice, Bob and Charlie, as `/me/` lists them.
final _players = FromSample.game(GameMeJsonBuilder().build()).players;

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
          result: _makeResult('see_team_werewolves', {
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
          result: _makeResult('see_team_werewolves', {'teammate_names': []}),
          players: _players,
        ),
      );

      expect(find.textContaining('lone Werewolf'), findsOneWidget);
      expect(find.textContaining('chose not to peek'), findsOneWidget);
    });

    testWidgets('shows peeked center card when present', (tester) async {
      await tester.pumpWithTokens(
        NightResultView(
          result: _makeResult('see_team_lone_werewolf', {
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
          result: _makeResult('see_team_masons', {'teammate_names': []}),
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
          result: _makeResult('see_team_minion', {'teammate_names': []}),
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
          result: _makeResult('see_team_minion', {
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

  group('NightResultView — skip', () {
    testWidgets('says the player did nothing', (tester) async {
      await tester.pumpWithTokens(
        NightResultView(result: _makeResult('skip', {}), players: _players),
      );

      expect(find.text('You did nothing.'), findsOneWidget);
    });
  });

  group('NightResultView — continue button', () {
    testWidgets('is absent by default', (tester) async {
      await tester.pumpWithTokens(
        NightResultView(
          result: _makeResult('insomniac', {'current_role': 'villager'}),
          players: _players,
        ),
      );

      expect(find.text('Continue'), findsNothing);
    });

    testWidgets('shows the label and calls onContinue when tapped', (
      tester,
    ) async {
      var continued = 0;
      await tester.pumpWithTokens(
        NightResultView(
          result: _makeResult('insomniac', {'current_role': 'villager'}),
          players: _players,
          continueLabel: 'Continue to discussion',
          onContinue: () => continued++,
        ),
      );

      // The result is still shown next to the button.
      expect(find.textContaining('card is now'), findsOneWidget);
      await tester.tap(find.text('Continue to discussion'));
      await tester.pump();

      expect(continued, 1);
    });
  });
}
