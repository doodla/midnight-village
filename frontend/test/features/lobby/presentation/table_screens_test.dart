import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/copy/copy.dart';
import 'package:midnight_village/design_system/models/role.dart';
import 'package:midnight_village/design_system/primitives/chips.dart';
import 'package:midnight_village/design_system/primitives/primary_button.dart';
import 'package:midnight_village/design_system/primitives/qr_picture.dart';
import 'package:midnight_village/design_system/primitives/role_card.dart';
import 'package:midnight_village/design_system/primitives/role_sheet_body.dart';
import 'package:midnight_village/design_system/primitives/secondary_button.dart';

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
        'a protocol-2 table and shows it', (tester) async {
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

    testWidgets('"Join a table" opens the code; Join sits the player at that '
        'table, and the table shows', (tester) async {
      final setup = await TableSetup.pump(
        tester,
        signedInAs: 'Ben',
        userId: 42,
      );
      final table = v2Lobby('detail_v2_auto_deck_5');
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
      setup.sitAt(v2Lobby('detail_v2_auto_deck_5'), 'Ben');

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

    testWidgets('opened from a table\'s link: the name and Join, nothing '
        'else', (tester) async {
      final setup = await TableSetup.pump(tester, route: '/join/V9YC2J');

      expect(find.text(JoinCopy.join), findsOneWidget);
      expect(find.text(JoinCopy.joinTable), findsNothing);
      expect(find.text(JoinCopy.startTable), findsNothing);
      expect(_onPressed(tester, JoinCopy.join), isNull);
      await setup.close(tester);
    });

    testWidgets('a player who sits at a table opens on it, with no tap', (
      tester,
    ) async {
      final setup = await TableSetup.pump(
        tester,
        lobby: v2Lobby('detail_v2_auto_deck_5'),
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
        lobby: v2Lobby('detail_v2_auto_deck_5'),
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
      // Everyone in the sample is ready already: nothing to send.
      expect(setup.count('POST', '/lobbies/V9YC2J/ready/'), 0);
      await setup.close(tester);
    });

    testWidgets('a player not ready yet sits down ready, with no button', (
      tester,
    ) async {
      final setup = await TableSetup.pump(
        tester,
        lobby: v2Lobby('created_with_defaults'),
        viewer: 'Ana',
      );

      final ready = setup.http.requests.where(
        (r) => r.path == '/lobbies/R5ZD3H/ready/',
      );
      expect(ready.map((r) => r.data), [
        {'is_ready': true},
      ]);
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

    testWidgets('the host\'s own deck shows its cards; one too many for the '
        'table says "Remove 1 cards"', (tester) async {
      final setup = await TableSetup.pump(
        tester,
        lobby: v2Lobby('detail_v2_custom_deck', players: 8),
        viewer: 'Ana',
      );

      expect(find.byType(RoleCard), findsWidgets);
      expect(_onPressed(tester, CommonCopy.removeCards.fill({'n': 1})), isNull);
      await setup.close(tester);
    });

    testWidgets('a guest: "{host} deals", the code, Leave; no deal, no deck', (
      tester,
    ) async {
      final setup = await TableSetup.pump(
        tester,
        lobby: v2Lobby('detail_v2_auto_deck_5'),
        viewer: 'Ben',
      );

      expect(
        find.text(TableCopy.hostDeals.fill({'host': 'Ana'})),
        findsOneWidget,
      );
      expect(find.text('V9YC2J'), findsOneWidget);
      expect(find.byType(QrPicture), findsNothing);
      expect(find.text(TableCopy.editDeck), findsNothing);
      expect(find.textContaining('Deal'), findsNothing);
      expect(_onPressed(tester, CommonCopy.leave), isNotNull);
      await setup.close(tester);
    });

    testWidgets('names are never cut: ten long names at the table', (
      tester,
    ) async {
      const long = 'Rosalind Fairweather';
      final setup = await TableSetup.pump(
        tester,
        lobby: v2Lobby(
          'detail_v2_auto_deck_9',
          players: 10,
          rename: {'Cleo': long},
        ),
        viewer: 'Ana',
      );

      expect(find.text(long), findsOneWidget);
      expect(_onPressed(tester, TableCopy.deal.fill({'n': 10})), isNotNull);
      await setup.close(tester);
    });

    testWidgets('Deal deals, and the table is read again to open the game', (
      tester,
    ) async {
      final setup = await TableSetup.pump(
        tester,
        lobby: v2Lobby('detail_v2_auto_deck_5'),
        viewer: 'Ana',
      );
      final reads = setup.count('GET', '/me/table/');
      setup.http.answer(
        'POST',
        '/onuw/lobbies/V9YC2J/start/',
        ContractSamples.map('http/game/started_v2'),
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
        lobby: v2Lobby('detail_v2_auto_deck_5'),
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
        ContractSamples.map('http/game/started_v2'),
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
        lobby: v2Lobby('detail_v2_auto_deck_5'),
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
        lobby: v2Lobby('detail_v2_auto_deck_5'),
        viewer: 'Ben',
      );
      expect(find.byType(QrPicture), findsNothing);

      setup.event({
        ...ContractSamples.map('ws/lobby/host_changed_handover'),
        'host_id': setup.viewerId,
        'host_name': 'Ben',
        'original_host_id': memberId(setup.lobby!, 'Ana'),
      });
      await setup.settle(tester);

      expect(find.byType(QrPicture), findsOneWidget);
      expect(_onPressed(tester, TableCopy.deal.fill({'n': 5})), isNotNull);
      expect(find.textContaining('host'), findsNothing);
      await setup.close(tester);
    });

    testWidgets('a guest leaves: back to 01', (tester) async {
      final setup = await TableSetup.pump(
        tester,
        lobby: v2Lobby('detail_v2_auto_deck_5'),
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
        lobby: v2Lobby('detail_v2_auto_deck_5'),
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

    testWidgets('Share hands the table\'s link to the share sheet', (
      tester,
    ) async {
      final setup = await TableSetup.pump(
        tester,
        lobby: v2Lobby('detail_v2_auto_deck_5'),
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
      String sample = 'detail_v2_auto_deck_5',
    }) async {
      final setup = await TableSetup.pump(
        tester,
        lobby: v2Lobby(sample),
        viewer: 'Ana',
      );
      await _tap(tester, setup, find.text(TableCopy.editDeck));
      expect(find.text(DeckCopy.headline), findsOneWidget);
      return setup;
    }

    testWidgets('a chip is chosen at once, and sent as the automatic deck', (
      tester,
    ) async {
      final setup = await openDeck(tester);
      expect(_chip(tester, 'Classic').selected, isTrue);
      final held = setup.http.hold(method: 'PATCH', path: '/lobbies/V9YC2J/');
      final answer = v2Lobby('detail_v2_auto_deck_5');
      (answer['settings'] as Map)['deck_chip'] = 'chaos';
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
      await setup.close(tester);
    });

    testWidgets('Edit opens the grid; the deck is sent with "Use this deck", '
        'amber only at a card for everyone and three more', (tester) async {
      final setup = await openDeck(tester, sample: 'detail_v2_custom_deck');
      // The grid is open on the host's own deck of twelve, for nine.
      expect(find.byType(RoleCard), findsNWidgets(deckOrder.length));
      expect(_onPressed(tester, DeckCopy.useDeck), isNotNull);

      await _tap(tester, setup, _role(RoleId.tanner));
      expect(_onPressed(tester, CommonCopy.addCards.fill({'n': 1})), isNull);
      await _tap(tester, setup, _role(RoleId.hunter));
      expect(_onPressed(tester, DeckCopy.useDeck), isNotNull);

      final answer = v2Lobby('detail_v2_custom_deck');
      setup.answerPatch(answer);
      await _tap(tester, setup, find.text(DeckCopy.useDeck));

      final sent = setup.patches.single! as Map;
      expect(sent['deck'], 'custom');
      expect((sent['roles'] as Map)['Hunter'], 1);
      expect((sent['roles'] as Map).containsKey('Tanner'), isFalse);
      // Back at the table.
      expect(find.text(TableCopy.scan), findsOneWidget);
      await setup.close(tester);
    });

    testWidgets('"Use this deck" with a chip sends nothing and goes back', (
      tester,
    ) async {
      final setup = await openDeck(tester);

      await _tap(tester, setup, find.text(DeckCopy.useDeck));

      expect(setup.patches, isEmpty);
      expect(find.text(TableCopy.scan), findsOneWidget);
      await setup.close(tester);
    });

    testWidgets('a pace chip sends the preset\'s lengths and is chosen at '
        'once', (tester) async {
      final setup = await openDeck(tester);
      // Held: its answer is not needed for what shows.
      setup.http.hold(method: 'PATCH', path: '/lobbies/V9YC2J/');
      setup.answerPatch(v2Lobby('detail_v2_auto_deck_5'));

      await _tap(tester, setup, find.text('Quick'));

      expect(_chip(tester, 'Quick').selected, isTrue);
      expect(setup.patches, [
        {
          'discussion_seconds': 180,
          'voting_seconds': 45,
          'night_wave_seconds': 20,
        },
      ]);
      // The lengths show under it.
      expect(find.text(DeckCopy.talk), findsOneWidget);
      await setup.close(tester);
    });

    testWidgets('holding a card opens the role sheet: the role text and '
        'Close, nothing that changes the deck', (tester) async {
      final setup = await openDeck(tester, sample: 'detail_v2_custom_deck');

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
        lobby: v2Lobby('detail_v2_auto_deck_5'),
        viewer: 'Ana',
      );

      expect(find.text(TableCopy.scan), findsOneWidget);
      expect(find.text(DeckCopy.headline), findsNothing);
      await setup.close(tester);
    });
  });
}

const deckOrder = RoleId.values;
