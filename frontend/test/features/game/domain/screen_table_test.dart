import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/features/game/domain/game_me.dart';
import 'package:midnight_village/features/game/domain/screen_table.dart';
import 'package:midnight_village/features/lobby/domain/lobby_state.dart';

import '../../../helpers/contract/contract_samples.dart';
import '../../../helpers/contract/from_sample.dart';
import '../../../helpers/contract/sample_sets.dart';
import '../../../helpers/contract/server_json.dart';
import '../../../helpers/sheet/sheet_data.dart' show recordedMe;

/// What `/me/table/` answers while [me]'s game runs (or is over).
TableView tableDuring(GameMe me) => TableView.fromMyTable(
  FromSample.myTable(
    serverMyTable(
      code: me.lobbyCode,
      status: me.phase == GamePhase.results ? 'finished' : 'in_game',
      gameId: me.gameId,
      phase: me.phase.server,
    ),
  ),
);

const _allLocal = [
  LocalSteps(),
  LocalSteps(editingDeck: true),
  LocalSteps(countSeen: true),
  LocalSteps(editingDeck: true, countSeen: true),
];

void main() {
  final reached = <AppScreen>{};

  AppScreen screen(TableView table, {GameMe? me, LocalSteps? local}) {
    final s = screenFor(table, me: me, local: local ?? const LocalSteps());
    reached.add(s);
    return s;
  }

  test('every recorded protocol-2 /me/ maps to its one screen', () {
    for (final name in protocolTwoMeSamples()) {
      final me = FromSample.gameMe(recordedMe(name));
      final expected = switch (me.phase) {
        GamePhase.night when me.window == 0 => AppScreen.yourCard,
        GamePhase.night => AppScreen.nightBoard,
        GamePhase.discussion => AppScreen.talk,
        GamePhase.voting => AppScreen.vote,
        GamePhase.results => AppScreen.count,
      };
      // The deck and count steps mean nothing during a game.
      for (final local in _allLocal.take(2)) {
        expect(
          screen(tableDuring(me), me: me, local: local),
          expected,
          reason: name,
        );
      }
    }
  });

  test('every recorded where-am-I answer maps to its one screen', () {
    AppScreen of(String name, {LocalSteps? local}) => screen(
      TableView.fromMyTable(
        FromSample.myTable(ContractSamples.map('http/lobby/my_table_$name')),
      ),
      local: local,
    );
    expect(of('none'), AppScreen.join);
    expect(of('waiting'), AppScreen.table);
    // A guest cannot open the deck: still the table.
    expect(
      of('waiting', local: const LocalSteps(editingDeck: true)),
      AppScreen.table,
    );
    // After play again the last game is still results: the table wins.
    expect(of('after_play_again'), AppScreen.table);
    // Before /me/ is in, the night shows 05 on the board's place.
    expect(of('night'), AppScreen.nightBoard);
    expect(of('discussion'), AppScreen.talk);
    expect(of('voting'), AppScreen.vote);
    expect(of('results'), AppScreen.count);
    expect(
      of('results', local: const LocalSteps(countSeen: true)),
      AppScreen.results,
    );
  });

  test('every recorded lobby body maps to its one screen', () {
    for (final (name, body) in lobbyBodies()) {
      final lobby = LobbyState.fromJson(body);
      for (final viewer in lobby.players) {
        final table = TableView.fromLobby(lobby, viewerId: viewer.id);
        final host = viewer.id == lobby.hostId;
        final expected = switch (lobby.status) {
          'waiting' => AppScreen.table,
          'in_game' => AppScreen.nightBoard,
          'finished' => AppScreen.count,
          _ => fail('$name: unknown status'),
        };
        expect(screen(table), expected, reason: name);
        if (lobby.status == 'waiting') {
          expect(
            screen(table, local: const LocalSteps(editingDeck: true)),
            host ? AppScreen.deck : AppScreen.table,
            reason: '$name, ${viewer.displayName}',
          );
        }
      }
    }
  });

  test('every screen is reached by at least one recorded state', () {
    // Runs after the three above (tests in a file run in order).
    expect(
      reached,
      AppScreen.values.toSet(),
      reason:
          'missing: '
          '${AppScreen.values.toSet().difference(reached)}',
    );
  });

  group('/me/ decides, and only for its own game', () {
    final look = FromSample.gameMe(recordedMe('me_look_stage'));
    final talk = FromSample.gameMe(recordedMe('me_talk_ready'));

    test('a phone that restarts lands where /me/ says, nothing else', () {
      expect(screenFor(tableDuring(look), me: look), AppScreen.yourCard);
      expect(screenFor(tableDuring(talk), me: talk), AppScreen.talk);
    });

    test('a /me/ fetched before the table moved on gives way to it', () {
      // /me/table/ already says voting; the older talk /me/ is behind.
      final table = TableView.fromMyTable(
        FromSample.myTable(
          serverMyTable(
            code: talk.lobbyCode,
            status: 'in_game',
            gameId: talk.gameId,
            phase: 'voting',
          ),
        ),
      );
      expect(screenFor(table, me: talk), AppScreen.vote);
      // A /me/ ahead of /me/table/ wins (the phase only moves forward).
      final behind = TableView.fromMyTable(
        FromSample.myTable(
          serverMyTable(
            code: look.lobbyCode,
            status: 'in_game',
            gameId: look.gameId,
            phase: 'night',
          ),
        ),
      );
      expect(screenFor(behind, me: talk), AppScreen.talk);
    });

    test("another game's /me/ is ignored", () {
      final next = TableView.fromMyTable(
        FromSample.myTable(
          serverMyTable(
            code: talk.lobbyCode,
            status: 'in_game',
            gameId: 'another-game',
            phase: 'night',
          ),
        ),
      );
      expect(screenFor(next, me: talk), AppScreen.nightBoard);
    });

    test('a waiting table is the table, whatever an old /me/ says', () {
      final waiting = TableView.fromMyTable(
        FromSample.myTable(ContractSamples.map('http/lobby/my_table_waiting')),
      );
      expect(screenFor(waiting, me: talk), AppScreen.table);
      expect(screenFor(TableView.nowhere, me: talk), AppScreen.join);
    });
  });
}
