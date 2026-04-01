import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/features/game/presentation/seer_choice_view.dart';

import '../../../design_system/test_helpers/pump_with_tokens.dart';

void main() {
  group('SeerChoiceView', () {
    testWidgets('displays two choice buttons', (tester) async {
      await tester.pumpWithTokens(
        SeerChoiceView(roleActingAs: 'Seer', onActionTypeSelected: (_) {}),
      );

      expect(find.text('Look at a player\'s card'), findsOneWidget);
      expect(find.text('Look at two center cards'), findsOneWidget);
    });

    testWidgets('displays the role acting as label', (tester) async {
      await tester.pumpWithTokens(
        SeerChoiceView(roleActingAs: 'Seer', onActionTypeSelected: (_) {}),
      );

      expect(find.text('Seer'), findsAtLeastNWidgets(1));
    });

    testWidgets('displays Doppelganger label when acting as Seer', (
      tester,
    ) async {
      await tester.pumpWithTokens(
        SeerChoiceView(
          roleActingAs: 'Doppelganger',
          onActionTypeSelected: (_) {},
        ),
      );

      expect(find.text('Doppelganger'), findsAtLeastNWidgets(1));
    });

    testWidgets('tapping peek_player button calls callback with peek_player', (
      tester,
    ) async {
      String? selected;
      await tester.pumpWithTokens(
        SeerChoiceView(
          roleActingAs: 'Seer',
          onActionTypeSelected: (type) => selected = type,
        ),
      );

      await tester.tap(find.text('Look at a player\'s card'));
      await tester.pump();

      expect(selected, 'peek_player');
    });

    testWidgets('tapping peek_center button calls callback with peek_center', (
      tester,
    ) async {
      String? selected;
      await tester.pumpWithTokens(
        SeerChoiceView(
          roleActingAs: 'Seer',
          onActionTypeSelected: (type) => selected = type,
        ),
      );

      await tester.tap(find.text('Look at two center cards'));
      await tester.pump();

      expect(selected, 'peek_center');
    });

    testWidgets('displays "Choose your action" prompt text', (tester) async {
      await tester.pumpWithTokens(
        SeerChoiceView(roleActingAs: 'Seer', onActionTypeSelected: (_) {}),
      );

      expect(find.text('Choose your action'), findsOneWidget);
    });
  });
}
