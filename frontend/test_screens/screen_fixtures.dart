import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/core/api/authenticated_client.dart';
import 'package:midnight_village/design_system/tokens/firelit_gothic_theme.dart';
import 'package:midnight_village/features/auth/domain/auth_state.dart';
import 'package:midnight_village/features/auth/domain/user.dart';
import 'package:midnight_village/features/game/presentation/timer_provider.dart';
import 'package:midnight_village/features/lobby/data/lobby_service.dart';
import 'package:midnight_village/features/lobby/presentation/lobby_notifier.dart';

import '../test/helpers/game_events.dart';
import '../test/helpers/game_state_factory.dart';
import '../test/helpers/game_test_setup.dart';
import '../test/helpers/mock_http_client.dart';
import '../test/helpers/mock_websocket.dart';
import '../test/helpers/pump_app.dart';

// One game at one table, from the deal to the results, as the server tells it:
// every payload has the shape and casing of backend/apps/core/serializers.py
// (lobby), backend/apps/onuw/serializers.py (/me), engine/night.py (prompts),
// services.py (socket events) and views.py (results), and the screens are
// reached through the events the server sends, in its order. Helper defaults
// that differ from the server (e.g. GameMeJsonBuilder's lowercase roles) are
// overridden here.
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

AuthState _signedInAs(int id) =>
    AuthState.authenticated(User(id: id, displayName: _players[id - 1]));

Map<String, dynamic> _user(int id) => {
  'id': id,
  // The server names guests with a UUID; players see the display name.
  'username': '00000000-0000-4000-8000-00000000000$id',
  'display_name': _players[id - 1],
};

// ---------------------------------------------------------------------------
// Home and lobby
// ---------------------------------------------------------------------------

/// The home screen, signed out (name entry) or signed in as Ana.
Future<void> pumpHome(WidgetTester tester, {required bool signedIn}) =>
    tester.pumpApp(
      auth: signedIn ? _signedInAs(ana) : const AuthState.unauthenticated(),
    );

/// The lobby on [viewer]'s phone, everyone ready, through the real lobby
/// service (mock HTTP) and a mock socket.
Future<void> pumpLobby(WidgetTester tester, {int viewer = ana}) {
  final http = MockHttpClient();
  const path = '/lobbies/$_tableCode/';
  http
      .when(method: 'GET', path: path)
      .thenReturn(
        Response(
          requestOptions: RequestOptions(path: path),
          statusCode: 200,
          data: _lobbyJson(),
        ),
      );
  return tester.pumpApp(
    initialRoute: '/lobby/$_tableCode',
    auth: _signedInAs(viewer),
    overrides: [
      lobbyServiceProvider.overrideWithValue(
        // Test code; the analyzer only counts test/ and *_test.dart as tests.
        // ignore: invalid_use_of_visible_for_testing_member
        LobbyService(client: AuthenticatedClient.forTesting(dio: http.dio)),
      ),
      lobbyWebSocketFactoryProvider.overrideWithValue(
        (_) => MockWebSocketChannel(),
      ),
    ],
  );
}

/// `GET /lobbies/<code>/` (LobbySerializer).
Map<String, dynamic> _lobbyJson() => {
  'code': _tableCode,
  'host': _user(ana),
  'original_host_id': ana,
  'is_acting_host': false,
  'game_type': 'onuw',
  'status': 'waiting',
  'max_players': 10,
  'settings': {'roles': _deck},
  'players': [
    for (var id = ana; id <= esme; id++)
      {
        'user': _user(id),
        'is_ready': true,
        'joined_at': '2026-11-19T20:5$id:00+00:00',
      },
  ],
  'created_at': '2026-11-19T20:50:00+00:00',
};

// ---------------------------------------------------------------------------
// The night (window 2)
// ---------------------------------------------------------------------------

/// `GET /me/` during the night window on [viewer]'s phone.
GameMeJsonBuilder _nightMe(int viewer, {bool hasActed = false}) {
  final me = GameMeJsonBuilder()
      .withGameId(_gameId)
      .inPhase('night')
      .withWave(_window)
      .withDeadline(_nightDeadline)
      .withRole(_dealt[viewer]!, hasActed: hasActed)
      .withPlayers([
        for (var id = ana; id <= esme; id++)
          {'player_id': id, 'display_name': _players[id - 1]},
      ])
      .withRolesInGame([
        for (final MapEntry(:key, :value) in _deck.entries)
          {'role': key, 'count': value},
      ])
      .withLobbyCode(_tableCode)
      .withHostId(ana);
  return viewer == ana ? me.asHost() : me;
}

/// The window's prompt for [viewer], as engine/night.py builds it: the
/// role's action types plus `skip`, and only the targets those types take.
Map<String, dynamic> _prompt(int viewer, List<String> actionTypes) {
  final others = [
    for (var id = ana; id <= esme; id++)
      if (id != viewer) id,
  ];
  return {
    'role_acting_as': _dealt[viewer],
    'action_types': [...actionTypes, 'skip'],
    'valid_targets': {
      if (actionTypes.any((t) => t.endsWith('player'))) 'player_ids': others,
      if (actionTypes.contains('peek_center')) 'center_indices': [0, 1, 2],
    },
    'wave': _window,
  };
}

/// Ana, the Seer, is asked what to look at.
Future<GameTestSetup> pumpSeerPrompt(WidgetTester tester) => _pumpGame(
  tester,
  ana,
  _nightMe(ana).withActionPrompt(_prompt(ana, ['peek_player', 'peek_center'])),
);

/// Ben, the Robber, is asked whom to rob.
Future<GameTestSetup> pumpRobberPrompt(WidgetTester tester) => _pumpGame(
  tester,
  ben,
  _nightMe(ben).withActionPrompt(_prompt(ben, ['swap_with_player'])),
);

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
        wave: _window,
        actionType: 'peek_player',
        revealedInfo: {'target_name': 'Cleo', 'role': 'werewolf'},
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
  game.ws.addServerEvent(
    GameEvents.gameResults(
      data: {
        'winning_teams': results['winning_teams'],
        'reason': results['reason'],
        'eliminated_players': [cleo],
      },
    ),
  );
  await _settle(tester);
  return game;
}

/// `GET /results/` (views.GameResultsView).
Map<String, dynamic> _resultsJson() => {
  'winning_teams': ['village'],
  'reason': 'A Werewolf was eliminated.',
  'eliminated_players': [
    {
      'player_id': cleo,
      'display_name': 'Cleo',
      'role': 'Werewolf',
      'elimination_reason': 'vote',
    },
  ],
  'players': [
    for (var id = ana; id <= esme; id++)
      {
        'player_id': id,
        'display_name': _players[id - 1],
        // Ben and Dev did nothing, so no card moved.
        'original_role': _dealt[id],
        'final_role': _dealt[id],
        'team': _dealt[id] == 'Werewolf' ? 'werewolf' : 'village',
        'is_eliminated': id == cleo,
        'elimination_reason': id == cleo ? 'vote' : null,
        'outcome': _dealt[id] == 'Werewolf' ? 'lose' : 'win',
        'vote_target_id': _votes[id],
      },
  ],
  'center_cards': _center,
  'night_actions_log': [
    for (final (i, werewolf) in [cleo, esme].indexed)
      _logEntry(
        2,
        i,
        werewolf,
        'Werewolf',
        'see_team',
        result: {
          'werewolves': [cleo, esme],
        },
      ),
    _logEntry(
      3,
      0,
      ana,
      'Seer',
      'peek_player',
      targets: {'player_id': cleo},
      result: {'peeked_role': 'Werewolf'},
    ),
    _logEntry(3, 1, ben, 'Robber', 'skip'),
    _logEntry(3, 2, dev, 'Troublemaker', 'skip'),
  ],
};

/// One stored night log entry (services.persist_wave_results); [orderGroup]
/// is the wake-order step it resolved in.
Map<String, dynamic> _logEntry(
  int orderGroup,
  int order,
  int playerId,
  String role,
  String actionType, {
  Map<String, dynamic> targets = const {},
  Map<String, dynamic> result = const {},
}) => {
  'wave': orderGroup,
  'player_id': playerId,
  'action_type': actionType,
  'targets': targets,
  'result': result,
  'timestamp_order': order,
  'role_acting_as': role,
};

// ---------------------------------------------------------------------------

/// The game screen on [viewer]'s phone, in the app's theme, with the
/// countdowns drawn as at [_now].
Future<GameTestSetup> _pumpGame(
  WidgetTester tester,
  int viewer,
  GameMeJsonBuilder me,
) => tester.pumpGameFlow(
  gameId: _gameId,
  gameMeJson: {
    // Sent by the server in every phase; the builder leaves them out.
    'has_voted': false,
    'action_prompt': null,
    'night_results': <dynamic>[],
    ...me.build(),
  },
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
