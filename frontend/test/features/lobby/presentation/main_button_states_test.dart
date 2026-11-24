import '../../../helpers/finger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/copy/copy.dart';
import 'package:midnight_village/design_system/layout/space.dart';
import 'package:midnight_village/design_system/primitives/nudge.dart';
import 'package:midnight_village/design_system/primitives/primary_button.dart';
import 'package:midnight_village/design_system/primitives/secondary_button.dart';
import 'package:midnight_village/design_system/primitives/text_action.dart';

import '../../../helpers/contract/contract_samples.dart';
import '../../../helpers/table_setup.dart';

// The one main button of 01 and 02 in every state it can be in (the app's
// rule: never silently disabled; players before the deck; the server's
// current need), as the host and as a guest see it.

Finder _primary(String label) => find.widgetWithText(PrimaryButton, label);

PrimaryButton _button(WidgetTester tester, String label) =>
    tester.widget<PrimaryButton>(_primary(label));

Future<void> _tap(WidgetTester tester, TableSetup setup, Finder what) async {
  await tester.ensureVisible(what);
  await tester.pump();
  await pressLikeAFinger(tester, what);
  await setup.settle(tester);
}

void main() {
  group('02, the host\'s one main button', () {
    testWidgets('players before the deck: alone with a deck of the wrong size '
        'it says "Need 3 players", not a deck message, and a tap shares the '
        'link to let friends in', (tester) async {
      // The recorded open table whose own deck is a card short for the eighth
      // player, with the host alone at it.
      final lobby = v2Lobby('detail_custom_deck_short', asRecorded: true);
      (lobby['players'] as List).removeRange(
        1,
        (lobby['players'] as List).length,
      );
      final setup = await TableSetup.pump(tester, lobby: lobby, viewer: 'Kai');

      expect(_primary(TableCopy.needPlayers), findsOneWidget);
      expect(find.text(DeckCopy.addCard), findsNothing);
      expect(find.text(TableCopy.start), findsNothing);
      // The way out of the wait is the table's link, one tap away.
      expect(_button(tester, TableCopy.needPlayers).phase, ButtonPhase.locked);
      await _tap(tester, setup, _primary(TableCopy.needPlayers));
      expect(setup.shared.single.path, endsWith('/join/${setup.code}'));
      await setup.close(tester);
    });

    testWidgets('an open table follows the server\'s current need: the third '
        'player makes the deck message, in the server\'s numbers', (
      tester,
    ) async {
      final setup = await TableSetup.pump(
        tester,
        lobby: v2Lobby('detail_custom_deck_ok', asRecorded: true),
        viewer: 'Kai',
      );
      expect(_primary(TableCopy.start), findsOneWidget);

      // Another player joins: the server's deal now needs one more card.
      setup.event(ContractSamples.map('ws/lobby/lobby_update_joined'));
      await setup.settle(tester);
      expect(_primary(DeckCopy.addCard), findsOneWidget);
      expect(_button(tester, DeckCopy.addCard).onPressed, isNotNull);
      await setup.close(tester);
    });

    testWidgets('a table set for a number says how many more, locked, never '
        'dimmed words', (tester) async {
      final setup = await TableSetup.pump(
        tester,
        lobby: v2Lobby('detail_seats_8_four_here'),
        viewer: 'Tia',
      );
      final words = TableCopy.needMore.fill({'n': 4});
      expect(_button(tester, words).phase, ButtonPhase.locked);
      await setup.close(tester);
    });

    testWidgets('ready: "Start the game", amber and live, with Leave a quiet '
        'word under it (not floating in the body)', (tester) async {
      final setup = await TableSetup.pump(
        tester,
        lobby: v2Lobby('detail_seats_8_full'),
        viewer: 'Tia',
      );
      expect(_button(tester, TableCopy.start).phase, ButtonPhase.ready);
      expect(find.text(TableCopy.editDeck), findsOneWidget);
      final deal = tester.getRect(_primary(TableCopy.start));
      final leave = tester.getRect(
        find.widgetWithText(TextAction, CommonCopy.leave),
      );
      // At the main button's side, on its line.
      expect(leave.center.dy, closeTo(deal.center.dy, 4));
      expect(leave.right, lessThanOrEqualTo(deal.left));
      expect(
        find.widgetWithText(SecondaryButton, CommonCopy.leave),
        findsNothing,
      );
      await setup.close(tester);
    });

    testWidgets('a wrong deck: the button is the fix, "Edit" is hidden, and '
        'there is no second red count', (tester) async {
      final setup = await TableSetup.pump(
        tester,
        lobby: v2Lobby('settings_seats_lowered'),
        viewer: 'Tia',
      );
      expect(_button(tester, DeckCopy.removeCard).phase, ButtonPhase.ready);
      expect(find.text(TableCopy.editDeck), findsNothing);
      expect(find.textContaining(' of 10'), findsNothing);
      await setup.close(tester);
    });
  });

  group('02, a guest at a blocked table', () {
    testWidgets('sees the same table, no button to fix it, no count, and a '
        'quiet Leave', (tester) async {
      final setup = await TableSetup.pump(
        tester,
        lobby: v2Lobby('settings_seats_lowered'),
        viewer: 'Ugo',
      );
      expect(find.byType(PrimaryButton), findsNothing);
      expect(find.text(DeckCopy.removeCard), findsNothing);
      expect(find.text(TableCopy.editDeck), findsNothing);
      expect(
        find.text(TableCopy.hostDeals.fill({'host': 'Tia'})),
        findsOneWidget,
      );
      expect(find.widgetWithText(TextAction, CommonCopy.leave), findsOneWidget);
      await setup.close(tester);
    });
  });

  group('01, a main action with no name does not look dead', () {
    for (final (label, answer) in [
      (JoinCopy.startTable, 'Start a table'),
      (JoinCopy.joinTable, 'Join a table'),
    ]) {
      testWidgets('"$answer": a tap takes the cursor to the name and nudges '
          'it; nothing is sent', (tester) async {
        final setup = await TableSetup.pump(
          tester,
          signedInAs: 'Ben',
          userId: 42,
        );
        await tester.enterText(find.byType(EditableText).first, '');
        await tester.pump();
        FocusManager.instance.primaryFocus?.unfocus();
        await tester.pump();
        expect(find.widgetWithText(SecondaryButton, label), findsOneWidget);
        await pressLikeAFinger(tester, find.text(label));
        await tester.pump();
        await tester.pump(Motion.settle ~/ 12);
        final name = tester.widget<EditableText>(
          find.byType(EditableText).first,
        );
        expect(name.focusNode.hasFocus, isTrue);
        final shake = tester.widget<Transform>(
          find
              .descendant(
                of: find.byType(Nudge),
                matching: find.byType(Transform),
              )
              .first,
        );
        expect(shake.transform.getTranslation().x, isNot(0));
        expect(setup.http.requests.where((r) => r.method == 'POST'), isEmpty);
        await setup.close(tester);
      });
    }
  });
}
