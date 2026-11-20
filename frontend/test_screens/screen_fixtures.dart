import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/tokens/firelit_gothic_theme.dart';
import 'package:midnight_village/features/game/presentation/timer_provider.dart';

import '../test/helpers/contract/server_json.dart';
import '../test/helpers/game_events.dart';
import '../test/helpers/game_state_factory.dart';
import '../test/helpers/game_test_setup.dart';

// One game at one table, from the deal to the results, as the server tells it:
// every payload is built from the server's recorded samples
// (contract_samples/, see test/helpers/contract/), so it has the server's keys
// and casing, and the screens are reached through the events the server
// sends, in its order.
//
// Five players, the mocks' names. Ana set the table up, so she hosts.

const _tableCode = 'K7QX4M';
const _gameId = '7d3f2c1a-5b8e-4c2d-9a6f-1e0b3c4d5e6f';
const _players = ['Ana', 'Ben', 'Cleo', 'Dev', 'Esme'];
const ana = 1;
const ben = 2;
const cleo = 3;
const dev = 4;
const esme = 5;

/// Eight cards, in the server's casing.
const _deck = {
  'Werewolf': 2,
  'Seer': 1,
  'Robber': 1,
  'Troublemaker': 1,
  'Insomniac': 1,
  'Villager': 2,
};
const _dealt = {
  ana: 'Seer',
  ben: 'Robber',
  cleo: 'Werewolf',
  dev: 'Troublemaker',
  esme: 'Werewolf',
};
const _center = ['Villager', 'Insomniac', 'Villager'];

/// With no Doppelganger in the deck the night is one window, numbered 2.
const _window = 2;

/// Voter -> accused. Cleo, a Werewolf, dies; the village wins.
const _votes = {ana: cleo, ben: cleo, cleo: dev, dev: cleo, esme: ana};

// Countdowns are drawn as if it were [_now], so a capture does not depend on
// the clock: 14 s of night left, 4:12 of talk, 0:48 of vote.
final _now = DateTime.utc(2026, 11, 19, 21);
const _nightDeadline = '2026-11-19T21:00:14+00:00';
const _talkDeadline = '2026-11-19T21:04:12+00:00';
const _voteDeadline = '2026-11-19T21:00:48+00:00';

final _seats = [
  for (var id = ana; id <= esme; id++) (id: id, name: _players[id - 1]),
];

// ---------------------------------------------------------------------------
// The night (window 2)
// ---------------------------------------------------------------------------

/// `GET /me/` during the night window on [viewer]'s phone.
GameMeJsonBuilder _nightMe(int viewer, {bool hasActed = false}) =>
    GameMeJsonBuilder()
        .withGameId(_gameId)
        .withSeats(_seats)
        .forViewer(viewer)
        .withRole(_dealt[viewer]!, hasActed: hasActed)
        .withDeck(_deck)
        .withDeadline(_nightDeadline)
        .withLobbyCode(_tableCode)
        .withHostId(ana);

/// Ana, the Seer, is asked what to look at.
Future<GameTestSetup> pumpSeerPrompt(WidgetTester tester) =>
    _pumpGame(tester, ana, _nightMe(ana).withPrompt('seer'));

/// Ben, the Robber, is asked whom to rob.
Future<GameTestSetup> pumpRobberPrompt(WidgetTester tester) =>
    _pumpGame(tester, ben, _nightMe(ben).withPrompt('robber'));

/// Ana has chosen; nobody is told anything until the window closes.
Future<GameTestSetup> pumpSeerWaiting(WidgetTester tester) =>
    _pumpGame(tester, ana, _nightMe(ana, hasActed: true));

/// The window closes: Ana's result, the window's end and the move to the talk
/// arrive together (services.send_wave_results, transition_to_discussion).
Future<GameTestSetup> pumpSeerResult(WidgetTester tester) async {
  final game = await pumpSeerWaiting(tester);
  game.ws
    ..addServerEvent(
      GameEvents.actionResult(
        'peek_player',
        wave: _window,
        info: {'target_name': 'Cleo', 'role': 'werewolf'},
      ),
    )
    ..addServerEvent(GameEvents.waveComplete(wave: _window))
    ..addServerEvent(
      GameEvents.phaseChange(phase: 'discussion', deadline: _talkDeadline),
    );
  await _settle(tester);
  return game;
}

// ---------------------------------------------------------------------------
// Day: the talk, the vote, the count, the results
// ---------------------------------------------------------------------------

/// Ana reads her result and goes on to the talk.
Future<GameTestSetup> pumpTalk(WidgetTester tester) async {
  final game = await pumpSeerResult(tester);
  await tester.tap(find.text('Continue to discussion'));
  await _settle(tester);
  return game;
}

/// The talk ends; Ben has voted, Ana has not.
Future<GameTestSetup> pumpVote(WidgetTester tester) async {
  final game = await pumpTalk(tester);
  game.ws
    ..addServerEvent(
      GameEvents.phaseChange(phase: 'voting', deadline: _voteDeadline),
    )
    ..addServerEvent(GameEvents.voteSubmitted(playerId: ben));
  await _settle(tester);
  return game;
}

/// Everyone has voted; the votes are revealed. The server sends the results
/// straight after this (services.reveal_votes), so on a phone this screen
/// shows only until they arrive.
Future<GameTestSetup> pumpCount(WidgetTester tester) async {
  final game = await pumpVote(tester);
  for (final voter in _votes.keys.where((v) => v != ben)) {
    game.ws.addServerEvent(GameEvents.voteSubmitted(playerId: voter));
  }
  game.ws.addServerEvent(
    GameEvents.voteReveal(
      votes: {for (final e in _votes.entries) '${e.key}': e.value},
    ),
  );
  await _settle(tester);
  return game;
}

/// The results arrive and the phone fetches them.
Future<GameTestSetup> pumpResults(WidgetTester tester) async {
  final game = await pumpCount(tester);
  final results = _resultsJson();
  game.registerResults(resultsJson: results);
  game.ws.addServerEvent(GameEvents.gameResults(eliminatedPlayers: [cleo]));
  await _settle(tester);
  return game;
}

/// `GET /results/`: Cleo, a Werewolf, dies; the village wins.
Map<String, dynamic> _resultsJson() => serverResults(
  winningTeams: ['village'],
  reason: 'A Werewolf was eliminated.',
  players: [
    for (final seat in _seats)
      ResultSeat(
        seat,
        // Ben and Dev did nothing, so no card moved.
        originalRole: _dealt[seat.id]!,
        team: _dealt[seat.id] == 'Werewolf' ? 'werewolf' : 'village',
        won: _dealt[seat.id] != 'Werewolf',
        eliminatedBy: seat.id == cleo ? 'vote' : null,
        votedFor: _votes[seat.id],
      ),
  ],
  centerCards: _center,
  nightActionsLog: [
    for (final (i, (werewolf, other)) in [(cleo, esme), (esme, cleo)].indexed)
      serverLogEntry(
        orderGroup: 2,
        order: i,
        playerId: werewolf,
        role: 'Werewolf',
        actionType: 'see_team',
        result: {
          'werewolves': [other],
        },
      ),
    serverLogEntry(
      orderGroup: 3,
      order: 0,
      playerId: ana,
      role: 'Seer',
      actionType: 'peek_player',
      targets: {'player_id': cleo},
      result: {'peeked_role': 'Werewolf'},
    ),
    serverLogEntry(
      orderGroup: 3,
      order: 1,
      playerId: ben,
      role: 'Robber',
      actionType: 'skip',
    ),
    serverLogEntry(
      orderGroup: 3,
      order: 2,
      playerId: dev,
      role: 'Troublemaker',
      actionType: 'skip',
    ),
  ],
);

// ---------------------------------------------------------------------------

/// The game screen on [viewer]'s phone, in the app's theme, with the
/// countdowns drawn as at [_now].
Future<GameTestSetup> _pumpGame(
  WidgetTester tester,
  int viewer,
  GameMeJsonBuilder me,
) => tester.pumpGameFlow(
  gameId: _gameId,
  gameMeJson: me.build(),
  playerName: _players[viewer - 1],
  userId: viewer,
  theme: const FirelitGothicTheme(),
  extraOverrides: [
    gameTimerProvider.overrideWith(
      (ref, deadline) => deadline == null
          ? const Stream.empty()
          : Stream.value(deadline.difference(_now)),
    ),
  ],
);

/// Lets the events above reach the screen and its transition finish before
/// the next step taps it.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}
