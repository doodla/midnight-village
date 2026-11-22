import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/copy/copy.dart';
import 'package:midnight_village/design_system/models/role.dart';
import 'package:midnight_village/design_system/primitives/chips.dart';
import 'package:midnight_village/design_system/primitives/notice.dart';
import 'package:midnight_village/design_system/primitives/player_row.dart';
import 'package:midnight_village/design_system/primitives/primary_button.dart';
import 'package:midnight_village/design_system/primitives/qr_picture.dart';
import 'package:midnight_village/design_system/primitives/role_card.dart';
import 'package:midnight_village/design_system/primitives/role_sheet_body.dart';
import 'package:midnight_village/design_system/primitives/secondary_button.dart';
import 'package:midnight_village/design_system/primitives/text_action.dart';
import 'package:midnight_village/design_system/skin/skin.dart';
import 'package:midnight_village/features/lobby/domain/lobby_state.dart';
import 'package:midnight_village/features/lobby/presentation/deck_screen.dart';

import '../../../helpers/contract/contract_samples.dart';
import '../../../helpers/mock_http_client.dart';
import '../../../helpers/table_setup.dart';

// 01 Join, 02 Table, 03 Deck and 03b through the app's routes and providers,
// every answer a recorded server payload (test/helpers/table_setup.dart).

Finder _button(String label) => find.ancestor(
  of: find.text(label),
  matching: find.byWidgetPredicate(
    (w) => w is PrimaryButton || w is SecondaryButton,
  ),
);

VoidCallback? _onPressed(WidgetTester tester, String label) =>
    switch (tester.widget(_button(label).first)) {
      PrimaryButton(:final onPressed) => onPressed,
      SecondaryButton(:final onPressed) => onPressed,
      _ => null,
    };

Future<void> _tap(WidgetTester tester, TableSetup setup, Finder what) async {
  await tester.ensureVisible(what);
  await tester.pump();
  await tester.tap(what);
  await setup.settle(tester);
}

PresetChip _chip(WidgetTester tester, String label) => tester.widget(
  find.ancestor(of: find.text(label), matching: find.byType(PresetChip)),
);

Finder _role(RoleId role) =>
    find.byWidgetPredicate((w) => w is RoleCard && w.role == role);

void main() {
  group('01 Join', () {
    testWidgets('a phone that never played opens on an empty name, and both '
        'ways in wait for one', (tester) async {
      final setup = await TableSetup.pump(tester);

      expect(find.text(JoinCopy.nameHint), findsOneWidget);
      expect(_onPressed(tester, JoinCopy.joinTable), isNull);
      expect(_onPressed(tester, JoinCopy.startTable), isNull);
      expect(find.text(JoinCopy.online.fill({'n': 23})), findsOneWidget);
      expect(find.text(JoinCopy.lastWon), findsNothing);
      expect(find.text(JoinCopy.lastLost), findsNothing);

      await tester.enterText(find.byType(TextField), 'Ana');
      await tester.pump();

      expect(_onPressed(tester, JoinCopy.joinTable), isNotNull);
      expect(_onPressed(tester, JoinCopy.startTable), isNotNull);
      await setup.close(tester);
    });

    testWidgets('a returning player has their own name and how the last game '
        'went', (tester) async {
      final setup = await TableSetup.pump(
        tester,
        signedInAs: 'Ben',
        lastWon: false,
      );

      expect(find.text('Ben'), findsOneWidget);
      expect(find.text(JoinCopy.lastLost), findsOneWidget);
      expect(_onPressed(tester, JoinCopy.startTable), isNotNull);
      await setup.close(tester);
    });

    testWidgets('starting a table makes this device\'s guest account, opens '
        'a table and shows it', (tester) async {
      final setup = await TableSetup.pump(tester, realAuth: true);
      final created = v2Lobby('created_with_defaults');
      setup.http
        ..answer(
          'POST',
          '/auth/guest/',
          ContractSamples.map('http/auth/guest_created'),
          status: 201,
        )
        ..answer('POST', '/lobbies/', created, status: 201);
      // The guest account the sample makes is id 1; the table's host is Ana.
      (created['host'] as Map)['id'] = 1;
      ((created['players'] as List).first as Map)['user']['id'] = 1;
      setup.sitAt(created, 'Ana');

      await tester.enterText(find.byType(TextField), 'Ana');
      await tester.pump();
      await _tap(tester, setup, find.text(JoinCopy.startTable));
      await setup.settle(tester);

      final guest = setup.http.requests.firstWhere(
        (r) => r.path == '/auth/guest/',
      );
      expect(guest.data, {'display_name': 'Ana'});
      final table = setup.http.requests.firstWhere(
        (r) => r.method == 'POST' && r.path == '/lobbies/',
      );
      expect(table.data, {'game_type': 'onuw', 'defaults': 'v2'});
      expect(find.text(TableCopy.scan), findsOneWidget);
      expect(find.byType(QrPicture), findsOneWidget);
      await setup.close(tester);
    });

    testWidgets('with no web address known (an app build) there is nothing '
        'to scan: no "Scan to join", the code labelled as 01 asks for it', (
      tester,
    ) async {
      final setup = await TableSetup.pump(
        tester,
        lobby: v2Lobby('created_with_defaults'),
        viewer: 'Ana',
        webAddress: false,
      );

      expect(find.byType(QrPicture), findsNothing);
      expect(find.text(TableCopy.scan), findsNothing);
      expect(find.text(JoinCopy.codeHint), findsOneWidget);
      expect(find.text('R5ZD3H'), findsOneWidget);
      await setup.close(tester);
    });

    testWidgets('with the QR code, "Scan to join" is its label and the code '
        'has its own', (tester) async {
      final setup = await TableSetup.pump(
        tester,
        lobby: v2Lobby('created_with_defaults'),
        viewer: 'Ana',
      );

      expect(find.byType(QrPicture), findsOneWidget);
      expect(find.text(TableCopy.scan), findsOneWidget);
      expect(find.text(JoinCopy.codeHint), findsOneWidget);
      await setup.close(tester);
    });

    testWidgets('"Join a table" opens the code; Join sits the player at that '
        'table, and the table shows', (tester) async {
      final setup = await TableSetup.pump(
        tester,
        signedInAs: 'Ben',
        userId: 42,
      );
      final table = v2Lobby('detail_auto_deck_5');
      setup.http.answer(
        'POST',
        '/lobbies/V9YC2J/join/',
        ContractSamples.map('http/lobby/joined'),
      );
      setup.sitAt(table, 'Ben');

      await _tap(tester, setup, find.text(JoinCopy.joinTable));
      expect(_onPressed(tester, JoinCopy.join), isNull);
      await tester.enterText(find.byType(TextField).last, 'v9yc2j');
      await tester.pump();
      await _tap(tester, setup, find.text(JoinCopy.join));
      await setup.settle(tester);

      expect(setup.count('POST', '/lobbies/V9YC2J/join/'), 1);
      expect(
        find.text(TableCopy.hostDeals.fill({'host': 'Ana'})),
        findsOneWidget,
      );
      await setup.close(tester);
    });

    for (final (sample, banner) in [
      ('join_not_found', BannerCopy.lobbyNotFound),
      ('join_full', BannerCopy.lobbyFull),
      ('join_closed', BannerCopy.lobbyClosed),
    ]) {
      testWidgets('a refused join says so plainly: $banner', (tester) async {
        final setup = await TableSetup.pump(tester, signedInAs: 'Ben');
        setup.http.answer(
          'POST',
          '/lobbies/ZZZZZZ/join/',
          ContractSamples.map('http/lobby/$sample'),
          status: sample == 'join_not_found' ? 404 : 400,
        );

        await _tap(tester, setup, find.text(JoinCopy.joinTable));
        await tester.enterText(find.byType(TextField).last, 'ZZZZZZ');
        await tester.pump();
        await _tap(tester, setup, find.text(JoinCopy.join));

        expect(find.text(banner), findsOneWidget);
        expect(find.text(BannerCopy.tryAgain), findsNothing);
        await setup.close(tester);
      });
    }

    testWidgets('joining a table the player already sits at goes there', (
      tester,
    ) async {
      final setup = await TableSetup.pump(
        tester,
        signedInAs: 'Ben',
        userId: 42,
      );
      setup.http.answer(
        'POST',
        '/lobbies/V9YC2J/join/',
        ContractSamples.map('http/lobby/join_already_member'),
        status: 400,
      );
      setup.sitAt(v2Lobby('detail_auto_deck_5'), 'Ben');

      await _tap(tester, setup, find.text(JoinCopy.joinTable));
      await tester.enterText(find.byType(TextField).last, 'V9YC2J');
      await tester.pump();
      await _tap(tester, setup, find.text(JoinCopy.join));
      await setup.settle(tester);

      expect(
        find.text(TableCopy.hostDeals.fill({'host': 'Ana'})),
        findsOneWidget,
      );
      await setup.close(tester);
    });

    testWidgets('a join refused because this player sits at another table '
        '(409): "You\'re at another table." and "Go there" opens it', (
      tester,
    ) async {
      final setup = await TableSetup.pump(
        tester,
        signedInAs: 'Lia',
        userId: 75,
      );
      setup.http.answer(
        'POST',
        '/lobbies/V9YC2J/join/',
        ContractSamples.map('http/lobby/join_already_at_table'),
        status: 409,
      );
      // The table the server says this player is at.
      setup.sitAt(v2Lobby('detail_deck_classic_4'), 'Lia');

      await _tap(tester, setup, find.text(JoinCopy.joinTable));
      await tester.enterText(find.byType(TextField).last, 'V9YC2J');
      await tester.pump();
      await _tap(tester, setup, find.text(JoinCopy.join));
      await setup.settle(tester);

      expect(find.text(BannerCopy.alreadyInLobby), findsOneWidget);
      expect(find.text(BannerCopy.notSent), findsNothing);

      await _tap(tester, setup, find.text(BannerCopy.goThere));
      await setup.settle(tester);

      expect(
        find.text(TableCopy.hostDeals.fill({'host': 'Kai'})),
        findsOneWidget,
      );
      await setup.close(tester);
    });

    testWidgets('opened from a table\'s link: the name and Join, nothing '
        'else', (tester) async {
      final setup = await TableSetup.pump(tester, route: '/join/V9YC2J');

      expect(find.text(JoinCopy.join), findsOneWidget);
      expect(find.text(JoinCopy.joinTable), findsNothing);
      expect(find.text(JoinCopy.startTable), findsNothing);
      expect(_onPressed(tester, JoinCopy.join), isNull);
      await setup.close(tester);
    });

    testWidgets('a link to another table, while seated at one: "You\'re at '
        'another table." and "Go there", never a second seat', (tester) async {
      final setup = await TableSetup.pump(
        tester,
        lobby: v2Lobby('detail_auto_deck_5'),
        viewer: 'Ben',
        route: '/join/ZZZZZZ',
      );

      expect(find.text(BannerCopy.alreadyInLobby), findsOneWidget);
      expect(find.text(JoinCopy.join), findsNothing);

      await _tap(tester, setup, find.text(BannerCopy.goThere));
      await setup.settle(tester);

      expect(setup.count('POST', '/lobbies/ZZZZZZ/join/'), 0);
      expect(
        find.text(TableCopy.hostDeals.fill({'host': 'Ana'})),
        findsOneWidget,
      );
      await setup.close(tester);
    });

    testWidgets('Enter in the name field opens the code; Enter there joins', (
      tester,
    ) async {
      final setup = await TableSetup.pump(
        tester,
        signedInAs: 'Ben',
        userId: 42,
      );
      setup.http.answer(
        'POST',
        '/lobbies/V9YC2J/join/',
        ContractSamples.map('http/lobby/joined'),
      );
      setup.sitAt(v2Lobby('detail_auto_deck_5'), 'Ben');

      await tester.showKeyboard(find.byType(TextField).first);
      await tester.testTextInput.receiveAction(TextInputAction.go);
      await tester.pump();
      // No table of their own by accident.
      expect(setup.http.requests.where((r) => r.path == '/lobbies/'), isEmpty);
      await tester.enterText(find.byType(TextField).last, 'V9YC2J');
      await tester.testTextInput.receiveAction(TextInputAction.go);
      await setup.settle(tester);

      expect(setup.count('POST', '/lobbies/V9YC2J/join/'), 1);
      await setup.close(tester);
    });

    testWidgets('a player who sits at a table opens on it, with no tap', (
      tester,
    ) async {
      final setup = await TableSetup.pump(
        tester,
        lobby: v2Lobby('detail_auto_deck_5'),
        viewer: 'Ben',
      );

      expect(
        find.text(TableCopy.hostDeals.fill({'host': 'Ana'})),
        findsOneWidget,
      );
      expect(find.text(JoinCopy.startTable), findsNothing);
      await setup.close(tester);
    });
  });

  group('02 Table', () {
    testWidgets('the host: the QR code of the table\'s link, the code, '
        'everyone, the chip and "Deal to 5"', (tester) async {
      final setup = await TableSetup.pump(
        tester,
        lobby: v2Lobby('detail_auto_deck_5'),
        viewer: 'Ana',
      );

      final qr = tester.widget<QrPicture>(find.byType(QrPicture));
      expect(qr.data, 'https://midnight.example/#/join/V9YC2J');
      expect(find.text('V9YC2J'), findsOneWidget);
      for (final name in ['Ana', 'Ben', 'Cleo', 'Dev', 'Esme']) {
        expect(find.text(name), findsOneWidget);
      }
      expect(_chip(tester, 'Classic').selected, isTrue);
      expect(_onPressed(tester, TableCopy.deal.fill({'n': 5})), isNotNull);
      // Nobody is asked to be ready: the deal deals in everyone there.
      expect(setup.count('POST', '/lobbies/V9YC2J/ready/'), 0);
      await setup.close(tester);
    });

    testWidgets('alone at the table: "Need 3 players", locked', (tester) async {
      final setup = await TableSetup.pump(
        tester,
        lobby: v2Lobby('created_with_defaults'),
        viewer: 'Ana',
      );

      expect(_onPressed(tester, TableCopy.needPlayers), isNull);
      await setup.close(tester);
    });

    testWidgets('the host\'s own deck shows its cards; one short for the '
        'table (the server\'s need and have) says "Add 1 card", locked', (
      tester,
    ) async {
      final setup = await TableSetup.pump(
        tester,
        lobby: v2Lobby('detail_custom_deck_short'),
        viewer: 'Kai',
      );

      expect(find.byType(RoleCard), findsWidgets);
      // One label, locked: never card arithmetic.
      expect(_onPressed(tester, TableCopy.deal.fill({'n': 8})), isNull);
      expect(find.textContaining('card'), findsNothing);
      await setup.close(tester);
    });

    testWidgets('a player joining tips the deal: "Deal to 7" becomes "Add 1 '
        'card" as the socket brings the eighth', (tester) async {
      final setup = await TableSetup.pump(
        tester,
        lobby: v2Lobby('detail_custom_deck_ok', asRecorded: true),
        viewer: 'Kai',
      );
      expect(_onPressed(tester, TableCopy.deal.fill({'n': 7})), isNotNull);

      setup.event(ContractSamples.map('ws/lobby/lobby_update_joined'));
      await setup.settle(tester);

      expect(find.text('Sam'), findsOneWidget);
      expect(_onPressed(tester, TableCopy.deal.fill({'n': 8})), isNull);
      await setup.close(tester);
    });

    for (final (chip, label) in [
      ('simple', 'Simple'),
      ('classic', 'Classic'),
      ('chaos', 'Chaos'),
    ]) {
      testWidgets('the $label chip shows the server\'s deck for the table, '
          'face up', (tester) async {
        final body = v2Lobby('detail_deck_${chip}_7');
        final setup = await TableSetup.pump(tester, lobby: body, viewer: 'Kai');

        final preview = {
          for (final MapEntry(:key, :value)
              in (body['deck_preview'] as Map<String, dynamic>).entries)
            RoleId.fromServer(key)!: value as int,
        };
        final shown = {
          for (final card in tester.widgetList<RoleCard>(find.byType(RoleCard)))
            card.role: card.count,
        };
        expect(shown, preview);
        expect(_chip(tester, label).selected, isTrue);
        expect(_onPressed(tester, TableCopy.deal.fill({'n': 7})), isNotNull);
        await setup.close(tester);
      });
    }

    testWidgets('a dropped phone is a dimmed row with no words, and comes '
        'back bright', (tester) async {
      final setup = await TableSetup.pump(
        tester,
        lobby: v2Lobby('detail_member_in_grace', asRecorded: true),
        viewer: 'Kai',
      );
      bool away(String name) => tester
          .widget<PlayerRow>(
            find.ancestor(
              of: find.text(name),
              matching: find.byType(PlayerRow),
            ),
          )
          .away;
      // In the grace period the server still counts the phone at the table.
      expect(away('Noa'), isFalse);

      setup.event(ContractSamples.map('ws/lobby/lobby_update_member_dropped'));
      await setup.settle(tester);
      expect(away('Noa'), isTrue);
      expect(away('Kai'), isFalse);

      setup.event(ContractSamples.map('ws/lobby/lobby_update_member_back'));
      await setup.settle(tester);
      expect(away('Noa'), isFalse);
      await setup.close(tester);
    });

    testWidgets('this phone\'s own row is never dimmed', (tester) async {
      final setup = await TableSetup.pump(
        tester,
        lobby: v2Lobby('detail_member_dropped', asRecorded: true),
        viewer: 'Noa',
      );

      final own = tester.widget<PlayerRow>(
        find.ancestor(of: find.text('Noa'), matching: find.byType(PlayerRow)),
      );
      expect(own.away, isFalse);
      await setup.close(tester);
    });

    testWidgets('a guest: "{host} deals", the code, Leave; no deal, no deck', (
      tester,
    ) async {
      final setup = await TableSetup.pump(
        tester,
        lobby: v2Lobby('detail_auto_deck_5'),
        viewer: 'Ben',
      );

      expect(
        find.text(TableCopy.hostDeals.fill({'host': 'Ana'})),
        findsOneWidget,
      );
      // Guests see the code too, to help others join.
      expect(find.text('V9YC2J'), findsOneWidget);
      expect(find.byType(QrPicture), findsOneWidget);
      expect(find.text(TableCopy.editDeck), findsNothing);
      expect(find.textContaining('Deal'), findsNothing);
      // Waiting, said by the screen's shape: who deals is the loudest line,
      // Leave a quiet word at the foot, no outlined button.
      final leave = tester.widget<TextAction>(find.byType(TextAction));
      expect(leave.label, CommonCopy.leave);
      expect(leave.onPressed, isNotNull);
      expect(_button(CommonCopy.leave), findsNothing);
      final heading = tester.widget<Text>(
        find.text(TableCopy.hostDeals.fill({'host': 'Ana'})),
      );
      final skin = tester.element(find.byType(TextAction)).skin;
      expect(heading.style!.fontSize, skin.typography.heroTitle.fontSize);
      await setup.close(tester);
    });

    testWidgets('names are never cut: nine long names at the table', (
      tester,
    ) async {
      const long = 'Rosalind Fairweather';
      final setup = await TableSetup.pump(
        tester,
        lobby: v2Lobby('detail_auto_deck_9', rename: {'Cleo': long}),
        viewer: 'Ana',
      );

      expect(find.text(long), findsOneWidget);
      expect(_onPressed(tester, TableCopy.deal.fill({'n': 9})), isNotNull);
      await setup.close(tester);
    });

    testWidgets('Deal deals, and the table is read again to open the game', (
      tester,
    ) async {
      final setup = await TableSetup.pump(
        tester,
        lobby: v2Lobby('detail_auto_deck_5'),
        viewer: 'Ana',
      );
      final reads = setup.count('GET', '/me/table/');
      setup.http.answer(
        'POST',
        '/onuw/lobbies/V9YC2J/start/',
        ContractSamples.map('http/game/started_with_look'),
        status: 201,
      );

      await _tap(tester, setup, find.text(TableCopy.deal.fill({'n': 5})));

      expect(setup.count('POST', '/onuw/lobbies/V9YC2J/start/'), 1);
      expect(setup.count('GET', '/me/table/'), greaterThan(reads));
      await setup.close(tester);
    });

    testWidgets('a deal that does not get through says "Not sent."; Try again '
        'deals', (tester) async {
      final setup = await TableSetup.pump(
        tester,
        lobby: v2Lobby('detail_auto_deck_5'),
        viewer: 'Ana',
      );
      setup.http.answer(
        'POST',
        '/onuw/lobbies/V9YC2J/start/',
        'Server Error',
        status: 503,
      );

      await _tap(tester, setup, find.text(TableCopy.deal.fill({'n': 5})));
      expect(find.text(BannerCopy.notSent), findsOneWidget);

      setup.http.answer(
        'POST',
        '/onuw/lobbies/V9YC2J/start/',
        ContractSamples.map('http/game/started_with_look'),
        status: 201,
      );
      await _tap(tester, setup, find.text(BannerCopy.tryAgain));

      expect(setup.count('POST', '/onuw/lobbies/V9YC2J/start/'), 2);
      expect(find.text(BannerCopy.notSent), findsNothing);
      await setup.close(tester);
    });

    testWidgets('a guest\'s table is read again when the host deals', (
      tester,
    ) async {
      final setup = await TableSetup.pump(
        tester,
        lobby: v2Lobby('detail_auto_deck_5'),
        viewer: 'Ben',
      );
      final reads = setup.count('GET', '/me/table/');

      setup.event({
        ...ContractSamples.map('ws/lobby/game_started'),
        'game_id': 'game-two',
      });
      await setup.settle(tester);

      expect(setup.count('GET', '/me/table/'), greaterThan(reads));
      await setup.close(tester);
    });

    testWidgets('after a handover the stand-in\'s phone has the host\'s '
        'layout, with no words about it', (tester) async {
      final setup = await TableSetup.pump(
        tester,
        lobby: v2Lobby('detail_auto_deck_5'),
        viewer: 'Ben',
      );
      expect(find.text(TableCopy.editDeck), findsNothing);

      setup.event({
        ...ContractSamples.map('ws/lobby/host_changed_handover'),
        'host_id': setup.viewerId,
        'host_name': 'Ben',
        'original_host_id': memberId(setup.lobby!, 'Ana'),
      });
      await setup.settle(tester);

      expect(find.text(TableCopy.editDeck), findsOneWidget);
      expect(_onPressed(tester, TableCopy.deal.fill({'n': 5})), isNotNull);
      expect(find.textContaining('host'), findsNothing);
      await setup.close(tester);
    });

    testWidgets('a guest leaves: back to 01', (tester) async {
      final setup = await TableSetup.pump(
        tester,
        lobby: v2Lobby('detail_auto_deck_5'),
        viewer: 'Ben',
      );
      setup.http
        ..answer(
          'POST',
          '/lobbies/V9YC2J/leave/',
          ContractSamples.map('http/lobby/left'),
        )
        ..answer(
          'GET',
          '/me/table/',
          ContractSamples.map('http/lobby/my_table_none'),
        );

      await _tap(tester, setup, find.text(CommonCopy.leave));
      await setup.settle(tester);

      expect(setup.count('POST', '/lobbies/V9YC2J/leave/'), 1);
      expect(find.text(JoinCopy.startTable), findsOneWidget);
      await setup.close(tester);
    });

    testWidgets('a table that is gone says so, and Go home goes to 01', (
      tester,
    ) async {
      final setup = await TableSetup.pump(
        tester,
        lobby: v2Lobby('detail_auto_deck_5'),
        viewer: 'Ben',
      );
      setup.http.answer(
        'GET',
        '/lobbies/V9YC2J/',
        ContractSamples.map('http/lobby/not_found'),
        status: 404,
      );

      setup.event(ContractSamples.map('ws/lobby/player_left'));
      await setup.settle(tester);
      expect(find.text(BannerCopy.tableClosed), findsOneWidget);

      setup.http.answer(
        'GET',
        '/me/table/',
        ContractSamples.map('http/lobby/my_table_none'),
      );

      await _tap(tester, setup, find.text(BannerCopy.goHome));
      expect(find.text(JoinCopy.startTable), findsOneWidget);
      await setup.close(tester);
    });

    testWidgets('where there is no share sheet, Share copies the link and '
        'says "Copied"', (tester) async {
      final setup = await TableSetup.pump(
        tester,
        lobby: v2Lobby('detail_auto_deck_5'),
        viewer: 'Ana',
      );
      setup.shareCopies = true;

      await _tap(tester, setup, find.byTooltip(TableCopy.share));

      expect(find.text(BannerCopy.copied), findsOneWidget);
      await setup.close(tester);
    });

    testWidgets('the host\'s Leave asks first: Stay keeps the table, Leave '
        'leaves', (tester) async {
      final setup = await TableSetup.pump(
        tester,
        lobby: v2Lobby('detail_auto_deck_5'),
        viewer: 'Ana',
      );
      setup.http.answer(
        'POST',
        '/lobbies/V9YC2J/leave/',
        ContractSamples.map('http/lobby/left'),
      );

      await _tap(tester, setup, find.text(CommonCopy.leave));
      await tester.pumpAndSettle();
      await tester.tap(find.text(TableCopy.stay));
      await tester.pumpAndSettle();
      expect(setup.count('POST', '/lobbies/V9YC2J/leave/'), 0);

      await _tap(tester, setup, find.text(CommonCopy.leave));
      await tester.pumpAndSettle();
      setup.http.answer(
        'GET',
        '/me/table/',
        ContractSamples.map('http/lobby/my_table_none'),
      );
      await tester.tap(find.text(CommonCopy.leave).last);
      await tester.pumpAndSettle();
      await setup.settle(tester);

      expect(setup.count('POST', '/lobbies/V9YC2J/leave/'), 1);
      expect(find.text(JoinCopy.startTable), findsOneWidget);
      await setup.close(tester);
    });

    testWidgets(
      'a deal refused for no reason worth saying adds nothing, never a bare "Not sent."',
      (tester) async {
        final setup = await TableSetup.pump(
          tester,
          lobby: v2Lobby('detail_auto_deck_5'),
          viewer: 'Ana',
        );
        setup.http.answer(
          'POST',
          '/onuw/lobbies/V9YC2J/start/',
          ContractSamples.map('http/game/start_bad_seed'),
          status: 400,
        );

        await _tap(tester, setup, find.text(TableCopy.deal.fill({'n': 5})));

        // No reason worth saying: nothing extra, never a bare "Not sent.".
        expect(find.text(BannerCopy.cannotDeal), findsNothing);
        expect(find.byType(Notice), findsNothing);
        expect(find.text(BannerCopy.notSent), findsNothing);
        expect(find.text(BannerCopy.tryAgain), findsNothing);
        await setup.close(tester);
      },
    );

    testWidgets('a table that cannot be read says "One moment", and shows '
        'once it answers', (tester) async {
      final setup = await TableSetup.pump(
        tester,
        lobby: v2Lobby('detail_auto_deck_5'),
        viewer: 'Ben',
        lobbyDown: true,
      );
      await tester.pump(const Duration(seconds: 2));
      await setup.settle(tester);
      expect(find.text(BannerCopy.offline), findsOneWidget);

      setup.serverAt(setup.lobby!);
      await tester.pump(const Duration(seconds: 3));
      await setup.settle(tester);

      expect(
        find.text(TableCopy.hostDeals.fill({'host': 'Ana'})),
        findsOneWidget,
      );
      await setup.close(tester);
    });

    testWidgets('Share hands the table\'s link to the share sheet', (
      tester,
    ) async {
      final setup = await TableSetup.pump(
        tester,
        lobby: v2Lobby('detail_auto_deck_5'),
        viewer: 'Ana',
      );

      await _tap(tester, setup, find.byTooltip(TableCopy.share));

      expect(setup.shared, [
        Uri.parse('https://midnight.example/#/join/V9YC2J'),
      ]);
      await setup.close(tester);
    });
  });

  group('03 Deck', () {
    Future<TableSetup> openDeck(
      WidgetTester tester, {
      String sample = 'detail_auto_deck_5',
      String viewer = 'Ana',
    }) async {
      final setup = await TableSetup.pump(
        tester,
        lobby: v2Lobby(sample),
        viewer: viewer,
      );
      await _tap(tester, setup, find.text(TableCopy.editDeck));
      expect(find.text(DeckCopy.headline), findsOneWidget);
      return setup;
    }

    /// The cards face up, by role (the grid's roles with none left out).
    Map<RoleId, int> shown(WidgetTester tester) => {
      for (final card in tester.widgetList<RoleCard>(find.byType(RoleCard)))
        if (card.count > 0) card.role: card.count,
    };

    Map<RoleId, int> cardsOf(Map<String, dynamic> body) => {
      for (final MapEntry(:key, :value)
          in (body['deck_cards'] as Map<String, dynamic>).entries)
        RoleId.fromServer(key)!: value as int,
    };

    testWidgets('a chip is chosen at once and sent as the automatic deck; '
        'its cards show face up when the server answers', (tester) async {
      final setup = await openDeck(
        tester,
        sample: 'detail_deck_classic_7',
        viewer: 'Kai',
      );
      expect(_chip(tester, 'Classic').selected, isTrue);
      expect(shown(tester), cardsOf(v2Lobby('detail_deck_classic_7')));
      final held = setup.http.hold(method: 'PATCH', path: '/lobbies/B7DH4Q/');
      final answer = v2Lobby('detail_deck_chaos_7');
      setup.answerPatch(answer);

      await _tap(tester, setup, find.text('Chaos'));

      expect(_chip(tester, 'Chaos').selected, isTrue);
      expect(_chip(tester, 'Classic').selected, isFalse);
      expect(setup.patches, [
        {'deck': 'auto', 'deck_chip': 'chaos'},
      ]);
      held.releaseAll();
      await setup.settle(tester);
      expect(_chip(tester, 'Chaos').selected, isTrue);
      expect(shown(tester), cardsOf(answer));
      await setup.close(tester);
    });

    testWidgets('a tap on a card of the automatic deck makes it the host\'s '
        'own, from those cards, for the players here', (tester) async {
      final setup = await openDeck(
        tester,
        sample: 'detail_deck_simple_7',
        viewer: 'Kai',
      );
      final cards = cardsOf(v2Lobby('detail_deck_simple_7'));
      expect(find.byType(RoleCard), findsNWidgets(deckOrder.length));
      expect(shown(tester), cards);
      setup.http.hold(method: 'PATCH', path: '/lobbies/B7DH4Q/');
      setup.answerPatch(ContractSamples.map('http/lobby/settings_deck_chip'));

      await _tap(tester, setup, _role(RoleId.tanner));

      final sent = setup.patches.single! as Map;
      expect(sent['deck'], 'custom');
      expect(sent['seats'], 7);
      expect(sent['roles'], {
        for (final MapEntry(:key, :value) in cards.entries)
          key.displayName: value,
        'Tanner': 1,
      });
      expect(_chip(tester, 'Simple').selected, isFalse);
      expect(shown(tester), {...cards, RoleId.tanner: 1});
      await setup.close(tester);
    });

    testWidgets('a deck that does not fit: "Done" is still live; 02 shows '
        'the count to the host only, Deal locked, and the count opens 03', (
      tester,
    ) async {
      // Set for seven, the host's own deck of eleven (built for eight).
      final setup = await openDeck(
        tester,
        sample: 'settings_seats_lowered',
        viewer: 'Tia',
      );
      expect(find.text('11 / 10'), findsOneWidget);
      expect(_onPressed(tester, DeckCopy.done), isNotNull);
      expect(find.textContaining('card'), findsNothing);
      await _tap(tester, setup, find.text(DeckCopy.done));

      expect(find.text('11 / 10'), findsOneWidget, reason: "on the host's 02");
      expect(_onPressed(tester, TableCopy.deal.fill({'n': 7})), isNull);
      await _tap(tester, setup, find.text('11 / 10'));
      expect(find.text(DeckCopy.headline), findsOneWidget, reason: 'to 03');
      await setup.close(tester);

      final guest = await TableSetup.pump(
        tester,
        lobby: v2Lobby('settings_seats_lowered'),
        viewer: 'Ugo',
      );
      expect(find.text('11 / 10'), findsNothing, reason: "never a guest's");
      await guest.close(tester);
    });

    testWidgets('"Done" sends nothing and goes back', (tester) async {
      final setup = await openDeck(tester);

      await _tap(tester, setup, find.text(DeckCopy.done));

      expect(setup.patches, isEmpty);
      expect(find.text(TableCopy.scan), findsOneWidget);
      await setup.close(tester);
    });

    testWidgets('every length the server has shows its value and unit, the '
        'server\'s defaults on a new table, and a step sends it at once', (
      tester,
    ) async {
      final setup = await openDeck(
        tester,
        sample: 'created_with_defaults',
        viewer: 'Ana',
      );
      final lengths =
          v2Lobby('created_with_defaults')['lengths'] as Map<String, dynamic>;
      for (final length in Length.values) {
        // The Doppelganger's is also a card's name in the grid.
        expect(
          find.text(lengthLabel(length)),
          length == Length.doppelganger ? findsWidgets : findsOneWidget,
          reason: length.key,
        );
      }
      expect(lengths['discussion_seconds'], 300);
      expect(find.text('5 min'), findsOneWidget);
      setup.http.hold(method: 'PATCH', path: '/lobbies/R5ZD3H/');
      setup.answerPatch(ContractSamples.map('http/lobby/settings_deck_chip'));

      final talk = find.ancestor(
        of: find.text(DeckCopy.talk),
        matching: find.byType(Row),
      );
      await _tap(
        tester,
        setup,
        find.descendant(of: talk.first, matching: find.byIcon(Icons.add)),
      );

      // Whole minutes from five on.
      expect(setup.patches, [
        {'discussion_seconds': 360},
      ]);
      expect(find.text('6 min'), findsOneWidget);
      await setup.close(tester);
    });

    testWidgets('holding a card opens the role sheet: the role text and '
        'Close, nothing that changes the deck', (tester) async {
      final setup = await openDeck(tester, sample: 'detail_custom_deck');

      await tester.ensureVisible(_role(RoleId.troublemaker));
      await tester.longPress(_role(RoleId.troublemaker));
      await tester.pumpAndSettle();

      expect(find.byType(RoleSheetBody), findsOneWidget);
      expect(find.text(RoleSheetCopy.close), findsOneWidget);
      expect(find.textContaining('Take out'), findsNothing);

      await tester.tap(find.text(RoleSheetCopy.close));
      await tester.pumpAndSettle();
      expect(find.byType(RoleSheetBody), findsNothing);
      await setup.close(tester);
    });

    testWidgets('a restart lands on 02: opening 03 was this phone\'s step', (
      tester,
    ) async {
      final first = await openDeck(tester);
      await first.close(tester);

      final setup = await TableSetup.pump(
        tester,
        lobby: v2Lobby('detail_auto_deck_5'),
        viewer: 'Ana',
      );

      expect(find.text(TableCopy.scan), findsOneWidget);
      expect(find.text(DeckCopy.headline), findsNothing);
      await setup.close(tester);
    });
  });
}

const deckOrder = RoleId.values;
