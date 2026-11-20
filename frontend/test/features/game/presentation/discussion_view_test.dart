import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/components/game/game_timer.dart';
import 'package:midnight_village/design_system/components/game/role_token_list.dart';
import 'package:midnight_village/features/game/presentation/discussion_view.dart';

import '../../../design_system/test_helpers/pump_with_tokens.dart';
import '../../../helpers/contract/from_sample.dart';
import '../../../helpers/game_state_factory.dart';

void main() {
  group('DiscussionView', () {
    testWidgets('renders a GameTimer widget', (tester) async {
      // Null deadline avoids a pending timer in test environment.
      // GameTimer still renders (shows 0:00 via Duration.zero fallback).
      await tester.pumpWithTokens(
        DiscussionView(
          deadline: null,
          rolesInGame: const [],
          isHost: false,
          onEndDiscussion: () {},
        ),
      );

      expect(find.byType(GameTimer), findsOneWidget);
    });

    testWidgets('shows a RoleTokenList widget', (tester) async {
      await tester.pumpWithTokens(
        DiscussionView(
          deadline: null,
          rolesInGame: FromSample.game(
            GameMeJsonBuilder().inPhase('discussion').build(),
          ).rolesInGame,
          isHost: false,
          onEndDiscussion: () {},
        ),
      );

      expect(find.byType(RoleTokenList), findsOneWidget);
    });

    testWidgets('host sees End Discussion button', (tester) async {
      await tester.pumpWithTokens(
        DiscussionView(
          deadline: null,
          rolesInGame: const [],
          isHost: true,
          onEndDiscussion: () {},
        ),
      );

      expect(find.text('End Discussion'), findsOneWidget);
    });

    testWidgets('non-host does not see End Discussion button', (tester) async {
      await tester.pumpWithTokens(
        DiscussionView(
          deadline: null,
          rolesInGame: const [],
          isHost: false,
          onEndDiscussion: () {},
        ),
      );

      expect(find.text('End Discussion'), findsNothing);
    });

    testWidgets('tapping End Discussion shows confirmation dialog', (
      tester,
    ) async {
      await tester.pumpWithTokens(
        DiscussionView(
          deadline: null,
          rolesInGame: const [],
          isHost: true,
          onEndDiscussion: () {},
        ),
      );

      await tester.tap(find.text('End Discussion'));
      await tester.pumpAndSettle();

      // Confirmation dialog should appear with the specified message.
      expect(
        find.text('End discussion early? Players are still talking.'),
        findsOneWidget,
      );
    });

    testWidgets('confirming dialog invokes onEndDiscussion callback', (
      tester,
    ) async {
      var callCount = 0;

      await tester.pumpWithTokens(
        DiscussionView(
          deadline: null,
          rolesInGame: const [],
          isHost: true,
          onEndDiscussion: () => callCount++,
        ),
      );

      await tester.tap(find.text('End Discussion'));
      await tester.pumpAndSettle();

      // Tap "End Discussion" in the dialog (confirm button).
      await tester.tap(find.text('End Early').last);
      await tester.pumpAndSettle();

      expect(callCount, 1);
    });

    testWidgets('cancelling dialog does not invoke onEndDiscussion callback', (
      tester,
    ) async {
      var callCount = 0;

      await tester.pumpWithTokens(
        DiscussionView(
          deadline: null,
          rolesInGame: const [],
          isHost: true,
          onEndDiscussion: () => callCount++,
        ),
      );

      await tester.tap(find.text('End Discussion'));
      await tester.pumpAndSettle();

      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();

      expect(callCount, 0);
    });
  });
}
