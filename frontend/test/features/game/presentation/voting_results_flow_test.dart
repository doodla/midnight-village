import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/components/game/game_results.dart';

import '../../../helpers/contract/server_json.dart';
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
      final resultsJson = serverResults(
        players: [
          ResultSeat(defaultSeats[0], originalRole: 'Seer', votedFor: 2),
          ResultSeat(
            defaultSeats[1],
            originalRole: 'Werewolf',
            team: 'werewolf',
            won: false,
            eliminatedBy: 'vote',
            votedFor: 1,
          ),
          ResultSeat(defaultSeats[2], originalRole: 'Villager', votedFor: 2),
        ],
        centerCards: ['Drunk', 'Villager', 'Mason'],
      );

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

      // The results fetch fails, so results stays null.
      setup.registerGet(
        '/onuw/games/test-game-id/results/',
        '<h1>Server Error (500)</h1>',
        statusCode: 500,
      );
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
