import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/components/game/role_card.dart';
import 'package:midnight_village/design_system/models/role.dart';
import 'package:midnight_village/features/game/presentation/seer_choice_view.dart';

import '../../../design_system/test_helpers/pump_with_tokens.dart';

void main() {
  group('SeerChoiceView', () {
    testWidgets('displays two choice buttons', (tester) async {
      await tester.pumpWithTokens(
        SeerChoiceView(
          roleId: RoleId.seer,
          roleActingAs: 'Seer',
          onActionTypeSelected: (_) {},
        ),
      );

      expect(find.text('Look at a player\'s card'), findsOneWidget);
      expect(find.text('Look at two center cards'), findsOneWidget);
    });

    testWidgets('displays the role acting as label', (tester) async {
      await tester.pumpWithTokens(
        SeerChoiceView(
          roleId: RoleId.seer,
          roleActingAs: 'Seer',
          onActionTypeSelected: (_) {},
        ),
      );

      expect(find.text('Seer'), findsAtLeastNWidgets(1));
    });

    testWidgets('displays a RoleCard in the identity strip', (tester) async {
      await tester.pumpWithTokens(
        SeerChoiceView(
          roleId: RoleId.seer,
          roleActingAs: 'Seer',
          onActionTypeSelected: (_) {},
        ),
      );

      expect(find.byType(RoleCard), findsOneWidget);
    });

    testWidgets('displays Doppelganger label and card when acting as Seer', (
      tester,
    ) async {
      await tester.pumpWithTokens(
        SeerChoiceView(
          roleId: RoleId.doppelganger,
          roleActingAs: 'Doppelganger',
          onActionTypeSelected: (_) {},
        ),
      );

      expect(find.text('Doppelganger'), findsAtLeastNWidgets(1));
      expect(find.byType(RoleCard), findsOneWidget);
    });

    testWidgets('tapping peek_player button calls callback with peek_player', (
      tester,
    ) async {
      String? selected;
      await tester.pumpWithTokens(
        SeerChoiceView(
          roleId: RoleId.seer,
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
          roleId: RoleId.seer,
          roleActingAs: 'Seer',
          onActionTypeSelected: (type) => selected = type,
        ),
      );

      await tester.tap(find.text('Look at two center cards'));
      await tester.pump();

      expect(selected, 'peek_center');
    });

    testWidgets('shows no Skip button unless the server offered skip', (
      tester,
    ) async {
      await tester.pumpWithTokens(
        SeerChoiceView(
          roleId: RoleId.seer,
          roleActingAs: 'Seer',
          onActionTypeSelected: (_) {},
        ),
      );

      expect(find.text('Skip'), findsNothing);
    });

    testWidgets('Skip button calls onSkip when provided', (tester) async {
      var skipped = 0;
      String? selected;
      await tester.pumpWithTokens(
        SeerChoiceView(
          roleId: RoleId.seer,
          roleActingAs: 'Seer',
          onActionTypeSelected: (type) => selected = type,
          onSkip: () => skipped++,
        ),
      );

      await tester.tap(find.text('Skip'));
      await tester.pump();

      expect(skipped, 1);
      expect(selected, isNull);
    });

    testWidgets('displays "Choose your action" prompt text', (tester) async {
      await tester.pumpWithTokens(
        SeerChoiceView(
          roleId: RoleId.seer,
          roleActingAs: 'Seer',
          onActionTypeSelected: (_) {},
        ),
      );

      expect(find.text('Choose your action'), findsOneWidget);
    });
  });
}
