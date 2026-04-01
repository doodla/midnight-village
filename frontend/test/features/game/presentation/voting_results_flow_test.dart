import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/components/game/game_results.dart';

import '../../../helpers/game_events.dart';
import '../../../helpers/game_state_factory.dart';
import '../../../helpers/game_test_setup.dart';

void main() {
  group('Voting → Results flow', () {
    testWidgets('vote_reveal shows intermediate tally view', (tester) async {
      final setup = await tester.pumpGameFlow(
        gameMeJson: GameMeJsonBuilder().inPhase('voting').build(),
      );
      addTearDown(setup.dispose);

      // Inject vote_reveal: Alice(1)→Charlie(3), Bob(2)→Charlie(3), Charlie(3)→Alice(1).
      setup.ws.addServerEvent(
        GameEvents.voteReveal(votes: {'1': 3, '2': 3, '3': 1}),
      );
      await tester.pump();

      // Votes heading.
      expect(find.text('Votes'), findsOneWidget);

      // Per-voter lines.
      expect(find.text('Alice voted for Charlie'), findsOneWidget);
      expect(find.text('Bob voted for Charlie'), findsOneWidget);

      // Tally heading.
      expect(find.text('Tally'), findsOneWidget);

      // Calculating footer.
      expect(find.text('Calculating results...'), findsOneWidget);
    });

    testWidgets('game_results triggers REST fetch and shows GameResults', (
      tester,
    ) async {
      final resultsJson = {
        'winning_teams': ['village'],
        'reason': 'Werewolf eliminated',
        'players': [
          {
            'player_id': 1,
            'display_name': 'Alice',
            'original_role': 'Seer',
            'final_role': 'Seer',
            'team': 'village',
            'is_eliminated': false,
            'outcome': 'win',
            'vote_target_id': 2,
          },
          {
            'player_id': 2,
            'display_name': 'Bob',
            'original_role': 'Werewolf',
            'final_role': 'Werewolf',
            'team': 'werewolf',
            'is_eliminated': true,
            'outcome': 'lose',
            'elimination_reason': 'vote',
            'vote_target_id': 1,
          },
          {
            'player_id': 3,
            'display_name': 'Charlie',
            'original_role': 'Villager',
            'final_role': 'Villager',
            'team': 'village',
            'is_eliminated': false,
            'outcome': 'win',
            'vote_target_id': 2,
          },
        ],
        'votes': [
          {
            'voter_id': 1,
            'voter_name': 'Alice',
            'target_id': 2,
            'target_name': 'Bob',
          },
          {
            'voter_id': 2,
            'voter_name': 'Bob',
            'target_id': 1,
            'target_name': 'Alice',
          },
          {
            'voter_id': 3,
            'voter_name': 'Charlie',
            'target_id': 2,
            'target_name': 'Bob',
          },
        ],
        'center_cards': ['Drunk', 'Villager', 'Mason'],
      };

      final setup = await tester.pumpGameFlow(
        gameMeJson: GameMeJsonBuilder().inPhase('voting').build(),
      );
      addTearDown(setup.dispose);

      // Register the results endpoint before game_results arrives.
      setup.registerResults(resultsJson: resultsJson);

      // Inject vote_reveal first (mirrors real server sequence).
      setup.ws.addServerEvent(
        GameEvents.voteReveal(votes: {'1': 2, '2': 1, '3': 2}),
      );
      await tester.pump();

      // Then inject game_results — triggers _fetchResultsFallback().
      setup.ws.addServerEvent(GameEvents.gameResults());
      await tester.pump(); // Process the WS event.
      await tester.pump(); // Allow the REST Future to start.
      await tester.pump(
        const Duration(milliseconds: 401),
      ); // AnimatedSwitcher transition.
      await tester.pump(); // Rebuild after results arrive.

      // The GameResults widget should now be visible.
      expect(find.byType(GameResults), findsOneWidget);
    });

    testWidgets('results loading placeholder when results are null', (
      tester,
    ) async {
      final setup = await tester.pumpGameFlow(
        gameMeJson: GameMeJsonBuilder().inPhase('voting').build(),
      );
      addTearDown(setup.dispose);

      // Inject game_results WITHOUT registering the results endpoint.
      // The REST fetch will fail (no mock registered), so results stays null.
      setup.ws.addServerEvent(GameEvents.gameResults());
      await tester.pump(); // Process the WS event — phase changes to results.
      await tester.pump(
        const Duration(milliseconds: 401),
      ); // AnimatedSwitcher transition.

      // Phase is results but results data is null → loading placeholder shown.
      expect(find.text('Loading results...'), findsOneWidget);
    });
  });
}
