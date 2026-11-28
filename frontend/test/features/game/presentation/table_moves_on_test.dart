import 'package:flutter/widgets.dart' show AppLifecycleState;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/core/healing/healing.dart';
import 'package:midnight_village/design_system/teach/learned_store.dart';
import 'package:midnight_village/features/game/domain/screen_table.dart';
import 'package:midnight_village/features/game/presentation/shell/table_shell.dart';
import 'package:midnight_village/features/game/presentation/table_screen.dart';
import 'package:midnight_village/features/lobby/presentation/where_am_i_provider.dart'
    show askWhereIn;

import '../../../helpers/contract/contract_samples.dart';
import '../../../helpers/contract/server_json.dart';
import '../../../helpers/mock_http_client.dart';
import '../../../helpers/outcome_samples.dart';
import '../../../helpers/shell_setup.dart';
import '../../../helpers/table_setup.dart';

// The owner, 24 November 2026: "Someone starts the game and it takes forever
// for my screen to update. Same with restarts as well." ("5-7 seconds ish").
//
// Every phone at the table is in the game about a second after the host's
// tap, on the deal and on play again:
// - the event moves the screen by itself (`SeatSeed`: `game_started` and
//   `play_again` are where the phone sits; no `/me/table/` read first);
// - a phone that missed the event (its socket down at that moment, the phone
//   asleep) heals in one read as the socket or the app comes back, or as any
//   lobby says the table is in a game: never on the slow poll, which these
//   tests keep at the phone's own 15 s (`HealTiming.tablePoll`);
// - a read that was out when the event landed (older than it) never moves
//   the screen back (`docs/dev/models/phone/seat/`).

/// The phone's own healing: the slow poll is 15 s, as on a phone.
const _phone = HealTiming();

/// How long after the socket or the app comes back the phone may take (the
/// reads answer at once here: this is frames, not network).
const _soon = Duration(milliseconds: 300);

AppScreen? _screen(WidgetTester tester) => ProviderScope.containerOf(
  tester.element(find.byType(TableShell)),
).read(tableScreenProvider).value?.screen;

bool _inGame(WidgetTester tester) => switch (_screen(tester)) {
  AppScreen.yourCard || AppScreen.nightBoard => true,
  _ => false,
};

/// The server deals game [me] at the table: the lobby is in a game,
/// `/me/table/` names it, its `/me/` answers.
void _dealOnServer(TableSetup setup, Map<String, dynamic> me) {
  setup.serverAt({...setup.lobby!, 'status': 'in_game'});
  setup.http.answer(
    'GET',
    '/me/table/',
    serverMyTable(
      code: setup.code,
      status: 'in_game',
      gameId: me['game_id'] as String,
    ),
  );
  setup.answerGame(me);
}

Map<String, dynamic> _gameStarted(Map<String, dynamic> me) => {
  ...ContractSamples.map('ws/lobby/game_started'),
  'game_id': me['game_id'],
};

/// The app goes to the background (the screen locked).
void _sleep(WidgetTester tester) {
  for (final state in const [
    AppLifecycleState.inactive,
    AppLifecycleState.hidden,
    AppLifecycleState.paused,
  ]) {
    tester.binding.handleAppLifecycleStateChanged(state);
  }
}

/// The app comes back to the foreground.
Future<void> _wake(WidgetTester tester) async {
  for (final state in const [
    AppLifecycleState.hidden,
    AppLifecycleState.inactive,
    AppLifecycleState.resumed,
  ]) {
    tester.binding.handleAppLifecycleStateChanged(state);
  }
}

/// A guest (Ben) at the end of a game Ana hosts, the phone's own healing.
Future<ShellSetup> _atTheEnd(WidgetTester tester) async {
  final results = recordedResults('results');
  final s = await ShellSetup.pump(
    tester,
    resultsMeFor(results, viewer: 'Ben', host: 'Ana'),
    learned: const {...Cue.values},
    healTiming: _phone,
    before: (s) => s.answerResults(results),
  );
  await s.settle(tester);
  expect(s.screenOn(tester), AppScreen.end);
  return s;
}

/// The host plays again on the server: the table is waiting, this game
/// still its newest.
void _playAgainOnServer(ShellSetup s) {
  final code = s.me['lobby_code'] as String;
  s.answerLobby(code);
  s.answerTable(serverMyTable(code: code, gameId: s.gameId, phase: 'results'));
}

void main() {
  group('a deal this phone missed at 02 heals in one read', () {
    testWidgets('the socket was down across the deal: in the game as it '
        'comes back, not on the slow poll', (tester) async {
      final setup = await TableSetup.pump(
        tester,
        lobby: v2Lobby('detail_auto_deck_5'),
        viewer: 'Ben',
        reconnectingSocket: true,
        healTiming: _phone,
      );
      expect(_screen(tester), AppScreen.table);

      await setup.dropLobbySocket();
      await tester.pump();
      final dealt = recordedMe('me_look_stage');
      _dealOnServer(setup, dealt);
      setup.event(_gameStarted(dealt)); // reaches nobody: the socket is down

      // The socket's own backoff (a second), then the reads it makes.
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(_soon);
      await tester.pump();

      expect(_inGame(tester), isTrue, reason: '${_screen(tester)}');
      await setup.close(tester);
    });

    testWidgets('the phone slept across the deal: in the game as the app '
        'comes back', (tester) async {
      final setup = await TableSetup.pump(
        tester,
        lobby: v2Lobby('detail_auto_deck_5'),
        viewer: 'Ben',
        healTiming: _phone,
      );
      // Asleep at the deal: its event never came (the socket looked open).
      _sleep(tester);
      final dealt = recordedMe('me_look_stage');
      _dealOnServer(setup, dealt);
      // Just short of the slow poll coming due.
      await tester.pump(const Duration(seconds: 14));

      await _wake(tester);
      await tester.pump(_soon);
      await tester.pump();

      expect(_inGame(tester), isTrue, reason: '${_screen(tester)}');
      await setup.close(tester);
    });

    testWidgets('a lobby update that says the table is in a game moves the '
        'phone on at once', (tester) async {
      final setup = await TableSetup.pump(
        tester,
        lobby: v2Lobby('detail_auto_deck_5'),
        viewer: 'Ben',
        healTiming: _phone,
      );
      final dealt = recordedMe('me_look_stage');
      _dealOnServer(setup, dealt);

      final update = ContractSamples.map(
        'ws/lobby/lobby_update_member_dropped',
      );
      setup.event({
        ...update,
        'data': {...setup.lobby!, 'status': 'in_game'},
      });
      await tester.pump(_soon);
      await tester.pump();

      expect(_inGame(tester), isTrue, reason: '${_screen(tester)}');
      await setup.close(tester);
    });
  });

  group('game_started moves the screen by itself', () {
    testWidgets('a guest is in the dusk on the event, with no read of where '
        'it sits first', (tester) async {
      final setup = await TableSetup.pump(
        tester,
        lobby: v2Lobby('detail_auto_deck_5'),
        viewer: 'Ben',
      );
      final dealt = recordedMe('me_look_stage');
      _dealOnServer(setup, dealt);
      // Where it sits cannot be read from now on: the event alone moves it.
      // (The game's socket opening reads it, behind.)
      final table = setup.http.hold(method: 'GET', path: '/me/table/');

      setup.event(_gameStarted(dealt));
      await tester.pump();

      expect(_inGame(tester), isTrue, reason: '${_screen(tester)}');
      // The game's own `/me/` fills the dusk in.
      await setup.settle(tester);
      expect(_screen(tester), AppScreen.yourCard);
      setup.http.stopHolding(method: 'GET', path: '/me/table/');
      table.releaseAll();
      expect(
        setup.count('GET', '/onuw/games/${dealt['game_id']}/me/'),
        isPositive,
      );
      await setup.close(tester);
    });

    testWidgets('a read of where it sits that was out when the event came '
        '(answered "waiting") does not take the phone back to 02', (
      tester,
    ) async {
      final setup = await TableSetup.pump(
        tester,
        lobby: v2Lobby('detail_auto_deck_5'),
        viewer: 'Ben',
      );
      // A read of where it sits goes out (the app coming back, the socket
      // back) and its answer is held: it was served before the deal.
      final held = setup.http.hold(method: 'GET', path: '/me/table/');
      askWhereIn(setup.container(tester));
      await tester.pump(const Duration(milliseconds: 60));
      expect(held.length, greaterThan(0));

      final dealt = recordedMe('me_look_stage');
      _dealOnServer(setup, dealt);
      setup.event(_gameStarted(dealt));
      await tester.pump();
      expect(_inGame(tester), isTrue);

      held.releaseAll();
      setup.http.stopHolding(method: 'GET', path: '/me/table/');
      await setup.settle(tester);

      expect(_inGame(tester), isTrue, reason: '${_screen(tester)}');
      await setup.close(tester);
    });
  });

  testWidgets('a late game_started for the game this table has already '
      'played (02 after play again) leaves the phone at 02', (tester) async {
    final played = recordedMe('me_look_stage');
    final setup = await TableSetup.pump(
      tester,
      lobby: v2Lobby('detail_auto_deck_5'),
      viewer: 'Ben',
      before: (s) => s.http.answer(
        'GET',
        '/me/table/',
        serverMyTable(
          code: s.code,
          gameId: played['game_id'] as String,
          phase: 'results',
        ),
      ),
    );
    expect(_screen(tester), AppScreen.table);

    setup.event(_gameStarted(played));
    await setup.settle(tester);

    expect(_screen(tester), AppScreen.table);
    await setup.close(tester);
  });

  group('play again this phone missed at the end heals in one read', () {
    testWidgets('the game socket was down: at 02 as it comes back', (
      tester,
    ) async {
      final s = await _atTheEnd(tester);
      s.socket(connected: false);
      await tester.pump();
      _playAgainOnServer(s);

      s.socket(connected: true);
      await tester.pump(_soon);
      await tester.pump();

      expect(s.screenOn(tester), AppScreen.table);
      await s.close(tester);
    });

    testWidgets('the phone slept: at 02 as the app comes back', (tester) async {
      final s = await _atTheEnd(tester);
      _playAgainOnServer(s);
      await tester.pump(const Duration(seconds: 14));

      s.resume();
      await tester.pump(_soon);
      await tester.pump();

      expect(s.screenOn(tester), AppScreen.table);
      await s.close(tester);
    });
  });

  group('an event said before a new screen\'s socket listened heals as it '
      'opens', () {
    testWidgets('a deal while 02\'s socket is still opening: in the game as '
        'it opens, not on the slow poll', (tester) async {
      final setup = await TableSetup.pump(
        tester,
        lobby: v2Lobby('detail_auto_deck_5'),
        viewer: 'Ben',
        reconnectingSocket: true,
        slowLobbySocket: true,
        healTiming: _phone,
      );
      expect(_screen(tester), AppScreen.table);
      final dealt = recordedMe('me_look_stage');
      _dealOnServer(setup, dealt);
      setup.event(_gameStarted(dealt)); // nobody listens yet

      setup.openLobbySocket();
      await tester.pump(_soon);
      await tester.pump();

      expect(_inGame(tester), isTrue, reason: '${_screen(tester)}');
      await setup.close(tester);
    });

    testWidgets('play again before the end board\'s socket is open: at 02 '
        'as it opens', (tester) async {
      final s = await _atTheEnd(tester);
      _playAgainOnServer(s); // its event reached nobody

      s.socket(connected: true); // the game's socket opens
      await tester.pump(_soon);
      await tester.pump();

      expect(s.screenOn(tester), AppScreen.table);
      await s.close(tester);
    });
  });

  group('play_again moves the screen by itself', () {
    testWidgets('a guest is at 02 on the event, with no read of where it '
        'sits first', (tester) async {
      final s = await _atTheEnd(tester);
      final reads = s.http.requests.where((r) => r.path == '/me/table/').length;
      _playAgainOnServer(s);

      s.ws.addServerEvent(ContractSamples.map('ws/game/play_again'));
      await tester.pump();

      expect(s.screenOn(tester), AppScreen.table);
      expect(
        s.http.requests.where((r) => r.path == '/me/table/').length,
        reads,
      );
      await s.close(tester);
    });

    testWidgets('a read of where it sits that was out when the event came '
        '(answered "finished") does not take the phone back to the end', (
      tester,
    ) async {
      final s = await _atTheEnd(tester);
      final held = s.http.hold(method: 'GET', path: '/me/table/');
      s.resume(); // a read goes out, served before play again
      await tester.pump(const Duration(milliseconds: 20));
      await tester.pump(const Duration(milliseconds: 20));
      expect(held.length, greaterThan(0));

      _playAgainOnServer(s);
      s.ws.addServerEvent(ContractSamples.map('ws/game/play_again'));
      await tester.pump();
      expect(s.screenOn(tester), AppScreen.table);

      held.releaseAll();
      s.http.stopHolding(method: 'GET', path: '/me/table/');
      await s.settle(tester);

      expect(s.screenOn(tester), AppScreen.table);
      await s.close(tester);
    });
  });
}
