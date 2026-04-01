import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/components/game/center_cards.dart';
import 'package:midnight_village/features/game/presentation/lone_werewolf_peek_view.dart';

import '../../../design_system/test_helpers/pump_with_tokens.dart';

void main() {
  group('LoneWerewolfPeekView', () {
    testWidgets('displays the lone werewolf prompt text', (tester) async {
      await tester.pumpWithTokens(
        LoneWerewolfPeekView(
          centerCardCount: 3,
          onSubmit: (action, targets) async {},
        ),
      );

      expect(find.textContaining('lone Werewolf'), findsAtLeastNWidgets(1));
    });

    testWidgets('displays CenterCards with 3 cards', (tester) async {
      await tester.pumpWithTokens(
        LoneWerewolfPeekView(
          centerCardCount: 3,
          onSubmit: (action, targets) async {},
        ),
      );

      expect(find.byType(CenterCards), findsOneWidget);
    });

    testWidgets('displays Peek and Skip buttons', (tester) async {
      await tester.pumpWithTokens(
        LoneWerewolfPeekView(
          centerCardCount: 3,
          onSubmit: (action, targets) async {},
        ),
      );

      expect(find.text('Peek'), findsOneWidget);
      expect(find.text('Skip'), findsOneWidget);
    });

    testWidgets('Peek button is disabled until a card is selected', (
      tester,
    ) async {
      await tester.pumpWithTokens(
        LoneWerewolfPeekView(
          centerCardCount: 3,
          onSubmit: (action, targets) async {},
        ),
      );

      // Initially, no card selected — Peek button should be disabled.
      // We check this by tapping the button and verifying onSubmit is not called.
      String? submittedAction;
      await tester.pumpWithTokens(
        LoneWerewolfPeekView(
          centerCardCount: 3,
          onSubmit: (action, _) async => submittedAction = action,
        ),
      );

      // Tap Peek without selecting a card — should do nothing.
      await tester.tap(find.text('Peek'));
      await tester.pump();

      expect(submittedAction, isNull);
    });

    testWidgets('Skip button submits see_team with empty targets', (
      tester,
    ) async {
      String? submittedAction;
      Map<String, dynamic>? submittedTargets;

      await tester.pumpWithTokens(
        LoneWerewolfPeekView(
          centerCardCount: 3,
          onSubmit: (action, targets) async {
            submittedAction = action;
            submittedTargets = targets;
          },
        ),
      );

      await tester.tap(find.text('Skip'));
      await tester.pump();

      expect(submittedAction, 'see_team');
      expect(submittedTargets, isEmpty);
    });

    testWidgets(
      'selecting card 0 and tapping Peek submits see_team with center_index 0',
      (tester) async {
        String? submittedAction;
        Map<String, dynamic>? submittedTargets;

        await tester.pumpWithTokens(
          LoneWerewolfPeekView(
            centerCardCount: 3,
            onSubmit: (action, targets) async {
              submittedAction = action;
              submittedTargets = targets;
            },
          ),
        );

        // Tap the first center card (index 0, labeled "Card 1").
        await tester.tap(find.text('Card\n1'));
        await tester.pump();

        await tester.tap(find.text('Peek'));
        await tester.pump();

        expect(submittedAction, 'see_team');
        expect(submittedTargets, {'center_index': 0});
      },
    );

    testWidgets('CenterCards has maxSelections of 1', (tester) async {
      await tester.pumpWithTokens(
        LoneWerewolfPeekView(
          centerCardCount: 3,
          onSubmit: (action, targets) async {},
        ),
      );

      final centerCards = tester.widget<CenterCards>(find.byType(CenterCards));
      expect(centerCards.maxSelections, 1);
    });
  });
}
