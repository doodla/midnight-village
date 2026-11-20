import 'dart:async';

import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/core/websocket/reconnecting_websocket.dart';
import 'package:midnight_village/core/websocket/websocket_channel.dart';
import 'package:midnight_village/features/game/domain/night_state.dart';
import 'package:midnight_village/features/game/presentation/game_notifier.dart';

import '../../../helpers/contract/contract_samples.dart';
import '../../../helpers/contract/server_json.dart';
import '../../../helpers/game_events.dart';
import '../../../helpers/game_state_factory.dart';
import '../../../helpers/game_test_setup.dart';

/// A [GameTestSetup] whose first state has been read.
Future<GameTestSetup> _loaded({Map<String, dynamic>? gameMeJson}) async {
  final setup = GameTestSetup.create(gameMeJson: gameMeJson);
  addTearDown(setup.dispose);
  await setup.readGameState();
  return setup;
}

Future<void> _pump() => Future<void>.delayed(Duration.zero);

void main() {
  group('GameNotifier initial load', () {
    test('fetches initial state from GameService', () async {
      final setup = await _loaded();

      final state = setup.currentState;
      expect(state.gameId, 'test-game-id');
      expect(state.phase, 'night');
      expect(state.players.length, 3);
      expect(state.yourRole.originalRole, 'Seer');
    });

    test(
      'derives nightSubView from initial state with action_prompt',
      () async {
        final setup = await _loaded(
          gameMeJson: GameMeJsonBuilder().withPrompt('seer').build(),
        );

        expect(setup.currentState.nightSubView, NightSubView.seerChoice);
      },
    );

    test('derives nightSubView as waiting when no action_prompt', () async {
      final setup = await _loaded();

      expect(setup.currentState.nightSubView, NightSubView.waiting);
    });
  });

  group('GameNotifier initial load in voting phase', () {
    test('hydrates voteProgress from server has_voted data', () async {
      final setup = await _loaded(
        gameMeJson: GameMeJsonBuilder()
            .inPhase('voting')
            .withPlayersHavingVoted({2: true})
            .build(),
      );

      final progress = setup.currentState.voteProgress;
      expect(progress.playerVoted, {1: false, 2: true, 3: false});
      expect(progress.currentPlayerVoted, false);
    });

    test('hydrates currentPlayerVoted when player already voted', () async {
      final setup = await _loaded(
        gameMeJson: GameMeJsonBuilder()
            .inPhase('voting')
            .hasVoted(true)
            .build(),
      );

      expect(setup.currentState.voteProgress.currentPlayerVoted, true);
      expect(setup.currentState.voteProgress.playerVoted[1], true);
    });

    test('leaves voteProgress empty when not in voting phase', () async {
      final setup = await _loaded();

      expect(setup.currentState.voteProgress.playerVoted, isEmpty);
      expect(setup.currentState.voteProgress.currentPlayerVoted, false);
    });
  });

  group('GameNotifier initial load in results phase', () {
    test(
      'fetches results via REST when reconnecting to results phase',
      () async {
        final setup = GameTestSetup.create(
          gameMeJson: GameMeJsonBuilder().inPhase('results').build(),
        );
        addTearDown(setup.dispose);
        setup.registerResults(
          resultsJson: serverResults(
            players: [
              ResultSeat(defaultSeats[0], originalRole: 'Seer', votedFor: 2),
              ResultSeat(
                defaultSeats[1],
                originalRole: 'Werewolf',
                team: 'werewolf',
                won: false,
                eliminatedBy: 'vote',
                votedFor: 1,
              ),
              ResultSeat(
                defaultSeats[2],
                originalRole: 'Villager',
                votedFor: 2,
              ),
            ],
          ),
        );

        final state = await setup.readGameState();
        expect(state.phase, 'results');
        expect(state.results, isNotNull);
        expect(state.results!.winningTeams.length, 1);
        expect(state.results!.players.length, 3);
        expect(state.results!.centerCards.length, 3);
      },
    );

    test('survives a refused results fetch on reconnect', () async {
      final setup = GameTestSetup.create(
        gameMeJson: GameMeJsonBuilder().inPhase('results').build(),
      );
      addTearDown(setup.dispose);
      setup.registerGet(
        '/onuw/games/test-game-id/results/',
        ContractSamples.load('http/game/results_not_ready'),
        statusCode: 403,
      );

      final state = await setup.readGameState();
      // State should still load (phase=results, results=null).
      expect(state.phase, 'results');
      expect(state.results, isNull);
    });

    test('does not fetch results for non-results phases', () async {
      // The results endpoint is not mocked: a call would fail the test.
      final setup = await _loaded();

      expect(setup.currentState.phase, 'night');
      expect(setup.currentState.results, isNull);
    });
  });

  group('GameNotifier WS event: wave_start', () {
    test('updates currentWave and deadline', () async {
      final setup = await _loaded(
        gameMeJson: GameMeJsonBuilder()
            .withRole('Doppelganger')
            .withWave(1)
            .build(),
      );

      setup.ws.addServerEvent(
        GameEvents.waveStart(wave: 2, deadline: '2026-11-19T21:00:30+00:00'),
      );
      await _pump();

      final state = setup.currentState;
      expect(state.currentWave, 2);
      expect(state.deadline, DateTime.utc(2026, 11, 19, 21, 0, 30));
      expect(state.actionPrompt, isNull);
      expect(state.lastActionResult, isNull);
    });
  });

  group('GameNotifier WS event: action_prompt', () {
    test('sets nightSubView to seerChoice for multi-action types', () async {
      final setup = await _loaded();

      setup.ws.addServerEvent(GameEvents.actionPrompt('seer'));
      await _pump();

      final state = setup.currentState;
      expect(state.nightSubView, NightSubView.seerChoice);
      expect(state.actionPrompt!.roleActingAs, 'Seer');
      expect(state.actionPrompt!.choiceTypes, ['peek_player', 'peek_center']);
    });

    test('sets nightSubView to actionPrompt for single action type', () async {
      final setup = await _loaded(
        gameMeJson: GameMeJsonBuilder().withRole('Drunk').build(),
      );

      setup.ws.addServerEvent(GameEvents.actionPrompt('drunk'));
      await _pump();

      expect(setup.currentState.nightSubView, NightSubView.actionPrompt);
      expect(setup.currentState.actionPrompt!.actionTypes, [
        'swap_with_center',
      ]);
    });
  });

  group('GameNotifier WS event: action_result', () {
    test('stores result and transitions to actionResult subview', () async {
      final setup = await _loaded();

      setup.ws.addServerEvent(
        GameEvents.actionResult(
          'peek_player',
          info: {'target_name': 'Charlie', 'role': 'werewolf'},
        ),
      );
      await _pump();

      final state = setup.currentState;
      expect(state.nightSubView, NightSubView.actionResult);
      expect(state.lastActionResult!.wave, 2);
      expect(state.lastActionResult!.revealedInfo['role'], 'werewolf');
      expect(
        state.lastActionResult!.revealedInfo['action_type'],
        'peek_player',
      );
    });
  });

  group('GameNotifier WS event: wave_complete', () {
    test(
      'clears the prompt and keeps the result the player was shown',
      () async {
        final setup = await _loaded();

        // Results arrive as the window closes, so the result must outlive the
        // wave_complete that follows it.
        setup.ws.addServerEvent(GameEvents.actionResult('peek_player'));
        setup.ws.addServerEvent(GameEvents.waveComplete());
        await _pump();

        final state = setup.currentState;
        expect(state.nightSubView, NightSubView.actionResult);
        expect(state.actionPrompt, isNull);
        expect(state.lastActionResult, isNotNull);
      },
    );

    test('with no result sets waiting and clears the prompt', () async {
      final setup = await _loaded(
        gameMeJson: GameMeJsonBuilder().withRole('Robber').build(),
      );

      setup.ws.addServerEvent(GameEvents.actionPrompt('robber'));
      await _pump();
      setup.ws.addServerEvent(GameEvents.waveComplete());
      await _pump();

      final state = setup.currentState;
      expect(state.nightSubView, NightSubView.waiting);
      expect(state.actionPrompt, isNull);
      expect(state.lastActionResult, isNull);
    });
  });

  group('GameNotifier WS event: wave_waiting', () {
    test('sets nightSubView to waiting', () async {
      final setup = await _loaded();

      setup.ws.addServerEvent(GameEvents.waveWaiting());
      await _pump();

      expect(setup.currentState.nightSubView, NightSubView.waiting);
    });
  });

  group('GameNotifier WS event: phase_change', () {
    test('updates phase and deadline', () async {
      final setup = await _loaded();

      setup.ws.addServerEvent(
        GameEvents.phaseChange(
          phase: 'discussion',
          deadline: '2026-11-19T21:05:00+00:00',
        ),
      );
      await _pump();

      final state = setup.currentState;
      expect(state.phase, 'discussion');
      expect(state.deadline, DateTime.utc(2026, 11, 19, 21, 5));
      expect(state.actionPrompt, isNull);
      expect(state.lastActionResult, isNull);
      expect(state.nightSubView, NightSubView.waiting);
    });

    test('handles a null deadline (an untimed talk)', () async {
      final setup = await _loaded();

      setup.ws.addServerEvent(GameEvents.phaseChange(phase: 'discussion'));
      await _pump();

      expect(setup.currentState.phase, 'discussion');
      expect(setup.currentState.deadline, isNull);
    });
  });

  group('GameNotifier WS event: vote_submitted', () {
    test('marks player as voted in VoteProgress', () async {
      final setup = await _loaded(
        gameMeJson: GameMeJsonBuilder().inPhase('voting').build(),
      );

      setup.ws.addServerEvent(GameEvents.voteSubmitted(playerId: 2));
      await _pump();

      expect(setup.currentState.voteProgress.playerVoted[2], true);
    });

    test('accumulates multiple vote_submitted events', () async {
      final setup = await _loaded(
        gameMeJson: GameMeJsonBuilder().inPhase('voting').build(),
      );

      setup.ws.addServerEvent(GameEvents.voteSubmitted(playerId: 1));
      setup.ws.addServerEvent(GameEvents.voteSubmitted(playerId: 2));
      await _pump();

      expect(setup.currentState.voteProgress.playerVoted, {
        1: true,
        2: true,
        3: false,
      });
    });
  });

  group('GameNotifier WS event: vote_reveal', () {
    test('stores vote mapping and computes tally', () async {
      final setup = await _loaded(
        gameMeJson: GameMeJsonBuilder().inPhase('voting').build(),
      );

      setup.ws.addServerEvent(
        GameEvents.voteReveal(votes: {'1': 3, '2': 3, '3': 1}),
      );
      await _pump();

      final reveal = setup.currentState.voteRevealData!;
      expect(reveal.votes['1'], 3);
      expect(reveal.votes['2'], 3);
      expect(reveal.tally['3'], 2);
      expect(reveal.tally['1'], 1);
    });

    test('handles null (abstain) votes', () async {
      final setup = await _loaded(
        gameMeJson: GameMeJsonBuilder().inPhase('voting').build(),
      );

      setup.ws.addServerEvent(
        GameEvents.voteReveal(votes: {'1': 3, '2': null, '3': null}),
      );
      await _pump();

      final reveal = setup.currentState.voteRevealData!;
      expect(reveal.votes['2'], isNull);
      expect(reveal.tally, {'3': 1});
    });
  });

  group('GameNotifier WS event: game_results', () {
    test('transitions to results phase', () async {
      final setup = await _loaded(
        gameMeJson: GameMeJsonBuilder().inPhase('voting').build(),
      );
      setup.registerResults();

      setup.ws.addServerEvent(GameEvents.gameResults(eliminatedPlayers: [3]));
      for (var i = 0; i < 10; i++) {
        await _pump();
      }

      expect(setup.currentState.phase, 'results');
      expect(setup.currentState.results, isNotNull);
    });
  });

  group('GameNotifier full night window', () {
    test(
      'wave_start -> action_prompt -> action_result -> wave_complete',
      () async {
        final setup = await _loaded(
          gameMeJson: GameMeJsonBuilder().withRole('Robber').build(),
        );

        setup.ws.addServerEvent(
          GameEvents.waveStart(wave: 2, deadline: '2026-11-19T21:00:30+00:00'),
        );
        await _pump();
        expect(setup.currentState.currentWave, 2);

        setup.ws.addServerEvent(GameEvents.actionPrompt('robber'));
        await _pump();
        expect(setup.currentState.nightSubView, NightSubView.actionPrompt);
        expect(setup.currentState.actionPrompt, isNotNull);

        setup.ws.addServerEvent(
          GameEvents.actionResult(
            'swap_with_player',
            info: {'target_name': 'Charlie', 'new_role': 'werewolf'},
          ),
        );
        await _pump();
        expect(setup.currentState.nightSubView, NightSubView.actionResult);
        expect(
          setup.currentState.lastActionResult!.revealedInfo['new_role'],
          'werewolf',
        );

        // The result stays: it is what the player learned, and it arrived only
        // as the window closed.
        setup.ws.addServerEvent(GameEvents.waveComplete());
        await _pump();
        final state = setup.currentState;
        expect(state.nightSubView, NightSubView.actionResult);
        expect(state.actionPrompt, isNull);
        expect(state.lastActionResult!.revealedInfo['new_role'], 'werewolf');
      },
    );
  });

  group('GameNotifier Doppelganger multi-step', () {
    test(
      'action_result followed by another action_prompt in same window',
      () async {
        final setup = await _loaded(
          gameMeJson: GameMeJsonBuilder()
              .withRole('Doppelganger')
              .withWave(1)
              .build(),
        );

        setup.ws.addServerEvent(
          GameEvents.actionPrompt('doppelganger', wave: 1),
        );
        await _pump();
        expect(setup.currentState.nightSubView, NightSubView.actionPrompt);
        expect(setup.currentState.actionPrompt!.roleActingAs, 'Doppelganger');

        // Her look (she copied the Seer), then her follow-up as the Seer.
        setup.ws.addServerEvent(
          GameEvents.actionResult('doppelganger_look', wave: 1),
        );
        await _pump();
        expect(setup.currentState.nightSubView, NightSubView.actionResult);

        setup.ws.addServerEvent(
          GameEvents.actionPrompt('doppelganger_followup', wave: 1),
        );
        await _pump();

        // Her look result stays on screen (with a Continue) instead of being
        // replaced at once by the follow-up prompt, which is stored for later.
        var state = setup.currentState;
        expect(state.nightSubView, NightSubView.actionResult);
        expect(state.lastActionResult!.revealedInfo['copied_role'], 'Seer');
        expect(state.actionPrompt!.roleActingAs, 'Seer');

        // Continue moves on to the follow-up prompt.
        setup.container
            .read(gameProvider('test-game-id').notifier)
            .dismissNightResult();
        state = setup.currentState;
        expect(state.nightSubView, NightSubView.seerChoice);
        expect(state.lastActionResult, isNull);
        expect(state.actionPrompt!.roleActingAs, 'Seer');
      },
    );
  });

  group('GameNotifier refreshState', () {
    test('re-fetches state from server and re-hydrates', () async {
      final setup = await _loaded();
      expect(setup.currentState.phase, 'night');

      // The game has moved to the talk.
      setup.registerGameMe(
        GameMeJsonBuilder()
            .inPhase('discussion')
            .withDeadline('2026-11-19T21:05:00+00:00')
            .build(),
      );
      await setup.container
          .read(gameProvider('test-game-id').notifier)
          .refreshState();

      expect(setup.currentState.phase, 'discussion');
      expect(setup.currentState.deadline, isNotNull);
    });

    test('re-hydrates voting phase with vote progress', () async {
      final setup = await _loaded();

      final voting = GameMeJsonBuilder()
          .inPhase('voting')
          .hasVoted(true)
          .withPlayersHavingVoted({2: true})
          .build();
      setup
        ..registerGameMe(voting)
        ..registerPlayersOf(voting);
      await setup.container
          .read(gameProvider('test-game-id').notifier)
          .refreshState();

      final refreshed = setup.currentState;
      expect(refreshed.phase, 'voting');
      expect(refreshed.voteProgress.currentPlayerVoted, true);
      expect(refreshed.voteProgress.playerVoted, {1: true, 2: true, 3: false});
    });

    test('fetches results when refreshing into results phase', () async {
      final setup = await _loaded();

      setup
        ..registerGameMe(GameMeJsonBuilder().inPhase('results').build())
        ..registerResults();
      await setup.container
          .read(gameProvider('test-game-id').notifier)
          .refreshState();

      expect(setup.currentState.phase, 'results');
      expect(setup.currentState.results!.winningTeams.length, 1);
    });
  });

  group('GameNotifier reconnection-triggered refresh', () {
    late StreamController<WebSocketConnectionState> connection;

    Future<GameTestSetup> loadedWithSocket() async {
      connection = StreamController<WebSocketConnectionState>.broadcast(
        sync: true,
      );
      addTearDown(connection.close);
      final ws = _MockReconnectingWebSocket(connection.stream);
      final setup = GameTestSetup.create(socket: ws);
      addTearDown(setup.dispose);
      await setup.readGameState();
      return setup;
    }

    test(
      'refreshes state when WebSocket reconnects after disconnect',
      () async {
        final setup = await loadedWithSocket();
        expect(setup.currentState.phase, 'night');

        // The game moved to the talk while the socket was down.
        setup.registerGameMe(GameMeJsonBuilder().inPhase('discussion').build());
        connection
          ..add(WebSocketConnectionState.disconnected)
          ..add(WebSocketConnectionState.reconnecting)
          ..add(WebSocketConnectionState.connected);
        for (var i = 0; i < 10; i++) {
          await _pump();
        }

        expect(setup.currentState.phase, 'discussion');
      },
    );

    test('initial connection does not trigger refresh', () async {
      final setup = await loadedWithSocket();

      // A second fetch would see the talk.
      setup.registerGameMe(GameMeJsonBuilder().inPhase('discussion').build());
      connection.add(WebSocketConnectionState.connected);
      await _pump();
      await _pump();

      expect(setup.currentState.phase, 'night');
    });
  });
}

/// A [ReconnectingWebSocket] whose connection state the test drives; its
/// messages come from the setup's mock socket.
class _MockReconnectingWebSocket implements ReconnectingWebSocket {
  _MockReconnectingWebSocket(this.connectionState);

  @override
  final Stream<WebSocketConnectionState> connectionState;

  @override
  Stream<dynamic> get stream => const Stream.empty();

  @override
  void send(dynamic data) {}

  @override
  Future<void> close([int? code, String? reason]) async {}

  @override
  bool get isClosed => false;

  @override
  Future<void> connect() async {}

  @override
  void dispose() {}
}
