import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/core/healing/healing.dart';
import 'package:midnight_village/features/game/domain/screen_table.dart';
import 'package:midnight_village/features/game/presentation/shell/table_shell.dart';
import 'package:midnight_village/features/game/presentation/table_screen.dart';

import '../../../helpers/contract/contract_samples.dart';
import '../../../helpers/contract/server_json.dart';
import '../../../helpers/live_game_setup.dart' show recordedMe;
import '../../../helpers/mock_http_client.dart';
import '../../../helpers/table_setup.dart';

// Where the phone sits is asked again through one helper (`askWhere`): one
// heal is one `/me/table/` request before the screen moves, never a read
// thrown away for another; a lobby that says the table is in a game asks
// at once, and once per change of status; a seat the phone built from an
// event is checked by the server behind the screen.

const _phone = HealTiming();
const _soon = Duration(milliseconds: 300);

AppScreen? _screen(WidgetTester tester) => ProviderScope.containerOf(
  tester.element(find.byType(TableShell)),
).read(tableScreenProvider).value?.screen;

bool _inGame(WidgetTester tester) => switch (_screen(tester)) {
  AppScreen.yourCard || AppScreen.nightBoard => true,
  _ => false,
};

Map<String, dynamic> _inGameTable(TableSetup setup, Map<String, dynamic> me) =>
    serverMyTable(
      code: setup.code,
      status: 'in_game',
      gameId: me['game_id'] as String,
    );

/// The server deals [me]'s game: the lobby is in a game, `/me/table/` names
/// it, its `/me/` answers.
void _dealOnServer(TableSetup setup, Map<String, dynamic> me) {
  setup.serverAt({...setup.lobby!, 'status': 'in_game'});
  setup.http.answer('GET', '/me/table/', _inGameTable(setup, me));
  setup.answerGame(me);
}

Future<void> _frames(WidgetTester tester) async {
  for (var i = 0; i < 20; i++) {
    await tester.pump(Duration.zero);
  }
}

void main() {
  group('one heal, one read of where the phone sits', () {
    testWidgets('the app comes back after a missed deal: the lobby answering '
        'first does not throw the table\'s read away for another', (
      tester,
    ) async {
      final setup = await TableSetup.pump(
        tester,
        lobby: v2Lobby('detail_auto_deck_5'),
        viewer: 'Ben',
        healTiming: _phone,
      );
      final dealt = recordedMe('me_look_stage');
      _dealOnServer(setup, dealt);
      final table = setup.http.hold(method: 'GET', path: '/me/table/');

      for (final state in const [
        AppLifecycleState.inactive,
        AppLifecycleState.hidden,
        AppLifecycleState.paused,
        AppLifecycleState.hidden,
        AppLifecycleState.inactive,
        AppLifecycleState.resumed,
      ]) {
        tester.binding.handleAppLifecycleStateChanged(state);
      }
      await _frames(tester);

      expect(table.length, 1, reason: 'the lobby said "in a game" meanwhile');
      setup.http.stopHolding(method: 'GET', path: '/me/table/');
      table.releaseAll();
      await _frames(tester);
      expect(_inGame(tester), isTrue, reason: '${_screen(tester)}');
      await setup.close(tester);
    });

    testWidgets('the socket comes back after a missed deal: one read', (
      tester,
    ) async {
      final setup = await TableSetup.pump(
        tester,
        lobby: v2Lobby('detail_auto_deck_5'),
        viewer: 'Ben',
        reconnectingSocket: true,
        healTiming: _phone,
      );
      await setup.dropLobbySocket();
      // Its lobby read while down answers before the deal.
      await _frames(tester);
      final dealt = recordedMe('me_look_stage');
      _dealOnServer(setup, dealt);
      final table = setup.http.hold(method: 'GET', path: '/me/table/');

      await tester.pump(const Duration(seconds: 1));
      await _frames(tester);

      expect(table.length, 1);
      setup.http.stopHolding(method: 'GET', path: '/me/table/');
      table.releaseAll();
      await _frames(tester);
      expect(_inGame(tester), isTrue, reason: '${_screen(tester)}');
      await setup.close(tester);
    });
  });

  group('a lobby that says the table is in a game', () {
    testWidgets('its first read (02 opened just before the deal): in the '
        'game at once', (tester) async {
      final dealt = recordedMe('me_look_stage');
      final setup = await TableSetup.pump(
        tester,
        lobby: v2Lobby('detail_auto_deck_5'),
        viewer: 'Ben',
        healTiming: _phone,
        settle: false,
        before: (s) {
          s.answerGame(dealt);
          s.http.answer('GET', '/lobbies/${s.code}/', {
            ...s.lobby!,
            'status': 'in_game',
          });
          // The deal lands between the table's read and the lobby's.
          s.http.answerEach(
            method: 'GET',
            path: '/lobbies/${s.code}/',
            answer: (_) =>
                s.http.answer('GET', '/me/table/', _inGameTable(s, dealt)),
          );
        },
      );
      await setup.settle(tester);

      expect(_inGame(tester), isTrue, reason: '${_screen(tester)}');
      await setup.close(tester);
    });

    testWidgets('asks once per change of status, not on every update (a '
        'table this player joined while it played)', (tester) async {
      final lobby = {...v2Lobby('detail_auto_deck_5'), 'status': 'in_game'};
      final setup = await TableSetup.pump(
        tester,
        lobby: lobby,
        viewer: 'Ben',
        healTiming: _phone,
        before: (s) => s.http.answer(
          'GET',
          '/me/table/',
          serverMyTable(code: s.code, status: 'in_game'),
        ),
      );
      expect(_screen(tester), AppScreen.table);
      final reads = setup.count('GET', '/me/table/');

      final update = ContractSamples.map(
        'ws/lobby/lobby_update_member_dropped',
      );
      for (var i = 0; i < 5; i++) {
        setup.event({...update, 'data': lobby});
        await tester.pump();
      }
      await setup.settle(tester);

      expect(setup.count('GET', '/me/table/'), reads);
      expect(_screen(tester), AppScreen.table);
      await setup.close(tester);
    });
  });

  group('a seat from an event is checked by the server', () {
    // Ben left (answered) while his lobby's read again failed, so his own
    // list still has him; the host deals without him and the event seats
    // him from that list.
    Future<TableSetup> leftThenDealt(
      WidgetTester tester, {
      required bool gameSocketRefused,
    }) async {
      final setup = await TableSetup.pump(
        tester,
        lobby: v2Lobby('detail_auto_deck_5'),
        viewer: 'Ben',
        healTiming: _phone,
        gameSocketRefused: gameSocketRefused,
      );
      final dealt = recordedMe('me_look_stage');
      setup.http
        ..answer('GET', '/me/table/', serverMyTable())
        ..answer(
          'GET',
          '/onuw/games/${dealt['game_id']}/me/',
          ContractSamples.map('http/game/me_not_a_player'),
          status: 403,
        );
      setup.event({
        ...ContractSamples.map('ws/lobby/game_started'),
        'game_id': dealt['game_id'],
      });
      await tester.pump();
      return setup;
    }

    testWidgets('a game that refuses this player reads where it sits: 01 '
        '(its socket never opens)', (tester) async {
      final setup = await leftThenDealt(tester, gameSocketRefused: true);

      await tester.pump(_soon);
      await tester.pump();

      expect(_screen(tester), AppScreen.join);
      await setup.close(tester);
    });

    testWidgets('the game\'s socket opening reads where it sits: 01', (
      tester,
    ) async {
      final setup = await leftThenDealt(tester, gameSocketRefused: false);

      await tester.pump(_soon);
      await tester.pump();

      expect(_screen(tester), AppScreen.join);
      await setup.close(tester);
    });
  });
}
