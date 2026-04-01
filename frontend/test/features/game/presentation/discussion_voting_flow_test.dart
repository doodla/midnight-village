import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/components/game/vote_submission.dart';

import '../../../helpers/game_events.dart';
import '../../../helpers/game_state_factory.dart';
import '../../../helpers/game_test_setup.dart';

void main() {
  group('Discussion → Voting flow', () {
    testWidgets('host can end discussion and transition to voting', (
      tester,
    ) async {
      final setup = await tester.pumpGameFlow(
        gameMeJson: GameMeJsonBuilder().inPhase('discussion').asHost().build(),
        userId: 1,
      );
      addTearDown(setup.dispose);

      // Register the end-discussion endpoint before we trigger the action.
      setup.registerEndDiscussion();

      // Host should see the "End Discussion" button.
      expect(find.text('End Discussion'), findsOneWidget);

      // Tap "End Discussion" to open the confirmation dialog.
      await tester.tap(find.text('End Discussion'));
      await tester.pump();

      // Confirmation dialog appears with "End Early" confirm button.
      expect(find.text('End Early'), findsOneWidget);
      expect(find.text('Cancel'), findsOneWidget);

      // Confirm ending discussion.
      await tester.tap(find.text('End Early'));
      await tester.pump();

      // Server sends phase_change to voting.
      setup.ws.addServerEvent(GameEvents.phaseChange(phase: 'voting'));
      await tester.pump();

      // Wait for the AnimatedSwitcher 400ms transition to clear the
      // outgoing DiscussionView.
      await tester.pump(const Duration(milliseconds: 401));

      // Voting view should now be shown.
      expect(find.byType(VoteSubmission), findsOneWidget);
      expect(find.text('0 of 3 voted'), findsOneWidget);
    });

    testWidgets('non-host does not see end discussion button', (tester) async {
      // Default userId 1, but isHost is false (no .asHost() call).
      final setup = await tester.pumpGameFlow(
        gameMeJson: GameMeJsonBuilder().inPhase('discussion').build(),
        userId: 1,
      );
      addTearDown(setup.dispose);

      expect(find.text('End Discussion'), findsNothing);
    });

    testWidgets('vote progress updates as players vote', (tester) async {
      final setup = await tester.pumpGameFlow(
        gameMeJson: GameMeJsonBuilder().inPhase('voting').build(),
        userId: 1,
      );
      addTearDown(setup.dispose);

      // Initial state: no votes cast.
      expect(find.text('0 of 3 voted'), findsOneWidget);

      // Player 2 votes.
      setup.ws.addServerEvent(GameEvents.voteSubmitted(playerId: 2));
      await tester.pump();
      expect(find.text('1 of 3 voted'), findsOneWidget);

      // Player 3 votes.
      setup.ws.addServerEvent(GameEvents.voteSubmitted(playerId: 3));
      await tester.pump();
      expect(find.text('2 of 3 voted'), findsOneWidget);
    });

    testWidgets('vote reveal shows vote mapping and tally heading', (
      tester,
    ) async {
      final setup = await tester.pumpGameFlow(
        gameMeJson: GameMeJsonBuilder().inPhase('voting').build(),
        userId: 1,
      );
      addTearDown(setup.dispose);

      // Inject a vote_reveal event.
      // Players: Alice(1), Bob(2), Charlie(3)
      // votes: Alice→Charlie, Bob→Charlie, Charlie→Alice
      setup.ws.addServerEvent(
        GameEvents.voteReveal(votes: {'1': 3, '2': 3, '3': 1}),
      );
      await tester.pump();

      // "Votes" heading is shown.
      expect(find.text('Votes'), findsOneWidget);

      // Individual vote descriptions.
      expect(find.text('Alice voted for Charlie'), findsOneWidget);
      expect(find.text('Bob voted for Charlie'), findsOneWidget);
      expect(find.text('Charlie voted for Alice'), findsOneWidget);

      // "Tally" heading is shown.
      expect(find.text('Tally'), findsOneWidget);
    });
  });
}
