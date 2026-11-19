import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/core/host/host_change.dart';
import 'package:midnight_village/features/game/presentation/game_notifier.dart';

import '../../../helpers/game_events.dart';
import '../../../helpers/game_state_factory.dart';
import '../../../helpers/game_test_setup.dart';

const _gameId = 'test-game-id';
const _names = ['Ana', 'Ben', 'Cleo', 'Dev', 'Esme'];

List<Map<String, dynamic>> _players() => [
  for (final (i, n) in _names.indexed) {'player_id': i + 1, 'display_name': n},
];

/// A game as seen by [hostId]'s table, with Dev away.
GameMeJsonBuilder _me({int hostId = 1, String phase = 'night'}) =>
    GameMeJsonBuilder()
        .inPhase(phase)
        .withPlayers(_players())
        .withPlayersAway({4})
        .withHostId(hostId);

Map<String, dynamic> _resultsJson() => {
  'winning_teams': ['village'],
  'reason': 'The werewolf was found.',
  'center_cards': <String>[],
  'players': [
    for (final (i, n) in _names.indexed)
      {
        'player_id': i + 1,
        'display_name': n,
        'original_role': 'villager',
        'final_role': 'villager',
        'team': 'village',
        'is_eliminated': false,
        'outcome': 'win',
      },
  ],
  'votes': <dynamic>[],
};

String _handover() =>
    GameEvents.hostChanged(hostId: 2, hostName: 'Ben', originalHostId: 1);

String _transferred() => GameEvents.hostChanged(
  hostId: 2,
  hostName: 'Ben',
  originalHostId: 2,
  reason: 'transferred',
);

String _returned() => GameEvents.hostChanged(
  hostId: 1,
  hostName: 'Ana',
  originalHostId: 1,
  reason: 'returned',
);

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

/// Rejects every later POST with [statusCode] (first in line, ahead of the
/// mock that answers every request).
void _rejectPostsWith(GameTestSetup setup, int statusCode) {
  setup.http.dio.interceptors.insert(
    0,
    InterceptorsWrapper(
      onRequest: (options, handler) {
        if (options.method != 'POST') return handler.next(options);
        handler.reject(
          DioException(
            requestOptions: options,
            response: Response(
              requestOptions: options,
              statusCode: statusCode,
              data: {'detail': 'no'},
            ),
            type: DioExceptionType.badResponse,
          ),
        );
      },
    ),
  );
}

void main() {
  group('Host in game state', () {
    test('follows host_id from /me/ over is_host', () async {
      final setup = GameTestSetup.create(
        gameMeJson: _me(hostId: 1).build()..['is_host'] = false,
      );
      addTearDown(setup.dispose);

      expect((await setup.readGameState()).isHost, isTrue);
    });

    test('without host_id the server\'s is_host stands', () async {
      final setup = GameTestSetup.create(
        gameMeJson: GameMeJsonBuilder().asHost().build(),
      );
      addTearDown(setup.dispose);

      final state = await setup.readGameState();

      expect(state.hostId, isNull);
      expect(state.isHost, isTrue);
    });

    test('host_changed moves the host at once, without a refetch', () async {
      final setup = GameTestSetup.create(gameMeJson: _me().build());
      addTearDown(setup.dispose);
      await setup.readGameState();
      final before = setup.http.requests.length;

      setup.ws.addServerEvent(_handover());

      expect(setup.currentState.isHost, isFalse);
      expect(setup.currentState.hostId, 2);
      expect(setup.http.requests.length, before);
    });

    test('host_changed makes the new host the host', () async {
      final setup = GameTestSetup.create(gameMeJson: _me().build(), userId: 2);
      addTearDown(setup.dispose);
      expect((await setup.readGameState()).isHost, isFalse);

      setup.ws.addServerEvent(_handover());

      expect(setup.currentState.isHost, isTrue);
    });

    test('a handover then a return gives the role back', () async {
      final setup = GameTestSetup.create(gameMeJson: _me().build());
      addTearDown(setup.dispose);
      await setup.readGameState();

      setup.ws.addServerEvent(_handover());
      setup.ws.addServerEvent(_returned());

      expect(setup.currentState.isHost, isTrue);
      expect(setup.currentState.hostNotice?.reason, HostChangeReason.returned);
    });

    test('a malformed host_changed is ignored', () async {
      final setup = GameTestSetup.create(gameMeJson: _me().build());
      addTearDown(setup.dispose);
      await setup.readGameState();

      setup.ws.addServerEvent({'type': 'host_changed', 'reason': 'handover'});

      expect(setup.currentState.isHost, isTrue);
      expect(setup.currentState.hostNotice, isNull);
    });

    test('a refetch after a reconnect picks up the effective host', () async {
      // Ana missed the handover: her phone was offline.
      final setup = GameTestSetup.create(gameMeJson: _me().build());
      addTearDown(setup.dispose);
      await setup.readGameState();
      expect(setup.currentState.isHost, isTrue);

      setup.registerGameMe(_me(hostId: 2).build());
      await setup.container.read(gameProvider(_gameId).notifier).refreshState();

      expect(setup.currentState.isHost, isFalse);
      expect(setup.currentState.hostId, 2);
    });

    test('a refetch after a missed return gives the role back and drops the '
        'handover line', () async {
      final setup = GameTestSetup.create(gameMeJson: _me().build());
      addTearDown(setup.dispose);
      await setup.readGameState();
      setup.ws.addServerEvent(_handover());
      expect(setup.currentState.hostNotice, isNotNull);

      setup.registerGameMe(_me(hostId: 1).build());
      await setup.container.read(gameProvider(_gameId).notifier).refreshState();

      expect(setup.currentState.isHost, isTrue);
      expect(setup.currentState.hostNotice, isNull);
    });

    test('the next phase change clears the "hosting again" line but not a '
        'handover line', () async {
      final setup = GameTestSetup.create(gameMeJson: _me().build());
      addTearDown(setup.dispose);
      await setup.readGameState();

      setup.ws.addServerEvent(_handover());
      setup.ws.addServerEvent(GameEvents.phaseChange(phase: 'discussion'));
      expect(setup.currentState.hostNotice?.reason, HostChangeReason.handover);

      setup.ws.addServerEvent(_returned());
      setup.ws.addServerEvent(GameEvents.phaseChange(phase: 'voting'));
      expect(setup.currentState.hostNotice, isNull);
    });
  });

  group('A host action refused because the role moved (403)', () {
    test(
      'refreshes state, says so plainly and throws NoLongerHostException',
      () async {
        final setup = GameTestSetup.create(gameMeJson: _me().build());
        addTearDown(setup.dispose);
        await setup.readGameState();
        _rejectPostsWith(setup, 403);
        setup.registerGameMe(_me(hostId: 2).build());
        final notifier = setup.container.read(gameProvider(_gameId).notifier);

        await expectLater(
          notifier.advanceNight(),
          throwsA(isA<NoLongerHostException>()),
        );

        expect(setup.currentState.isHost, isFalse);
        expect(setup.currentState.hostActionNotice, kNoLongerHostMessage);
      },
    );

    test(
      'covers revealing the votes, ending the talk and playing again',
      () async {
        final setup = GameTestSetup.create(
          gameMeJson: _me(phase: 'voting').withLobbyCode('ABC123').build(),
        );
        addTearDown(setup.dispose);
        await setup.readGameState();
        _rejectPostsWith(setup, 403);
        final notifier = setup.container.read(gameProvider(_gameId).notifier);

        await expectLater(
          notifier.revealVotesNow(),
          throwsA(isA<NoLongerHostException>()),
        );
        await expectLater(
          notifier.endDiscussion(),
          throwsA(isA<NoLongerHostException>()),
        );
        await expectLater(
          notifier.playAgain(),
          throwsA(isA<NoLongerHostException>()),
        );
      },
    );

    test('other failures are not turned into "no longer the host"', () async {
      final setup = GameTestSetup.create(gameMeJson: _me().build());
      addTearDown(setup.dispose);
      await setup.readGameState();
      _rejectPostsWith(setup, 500);
      final notifier = setup.container.read(gameProvider(_gameId).notifier);

      await expectLater(
        notifier.advanceNight(),
        throwsA(isNot(isA<NoLongerHostException>())),
      );
      expect(setup.currentState.hostActionNotice, isNull);
    });
  });

  group('Night waiting screen', () {
    testWidgets('"Continue without them" moves to the new host on a handover '
        'and back on the return', (tester) async {
      // Ana (1) hosts; Ben (2) watches on his own phone, and so on. Each
      // viewer is its own pump below.
      final setup = await tester.pumpGameFlow(gameMeJson: _me().build());
      expect(find.text('Continue without them'), findsOneWidget);

      setup.ws.addServerEvent(_handover());
      await _settle(tester);
      expect(find.text('Continue without them'), findsNothing);

      setup.ws.addServerEvent(_returned());
      await _settle(tester);
      expect(find.text('Continue without them'), findsOneWidget);
      expect(find.text('Ana is hosting again'), findsNothing);
      await tester.pump(const Duration(seconds: 7));
    });

    testWidgets('the new host gets the control and "You are hosting while Ana '
        'is away"', (tester) async {
      final setup = await tester.pumpGameFlow(
        gameMeJson: _me().build(),
        userId: 2,
        playerName: 'Ben',
      );
      expect(find.text('Continue without them'), findsNothing);

      setup.ws.addServerEvent(_handover());
      await _settle(tester);

      expect(find.text('Continue without them'), findsOneWidget);
      expect(find.text('You are hosting while Ana is away'), findsOneWidget);
    });

    testWidgets(
      'a bystander reads "Ben is hosting while Ana is away" and has no '
      'control',
      (tester) async {
        final setup = await tester.pumpGameFlow(
          gameMeJson: _me().build(),
          userId: 3,
          playerName: 'Cleo',
        );

        setup.ws.addServerEvent(_handover());
        await _settle(tester);

        expect(find.text('Ben is hosting while Ana is away'), findsOneWidget);
        expect(find.text('Continue without them'), findsNothing);
      },
    );

    testWidgets('the old host reads "Ben is hosting while you are away"', (
      tester,
    ) async {
      final setup = await tester.pumpGameFlow(gameMeJson: _me().build());

      setup.ws.addServerEvent(_handover());
      await _settle(tester);

      expect(find.text('Ben is hosting while you are away'), findsOneWidget);
    });

    testWidgets('"Ana is hosting again" shows for a few seconds, then goes', (
      tester,
    ) async {
      final setup = await tester.pumpGameFlow(
        gameMeJson: _me(hostId: 2).build(),
        userId: 3,
        playerName: 'Cleo',
      );

      setup.ws.addServerEvent(_returned());
      await _settle(tester);
      expect(find.text('Ana is hosting again'), findsOneWidget);

      await tester.pump(const Duration(seconds: 7));
      expect(find.text('Ana is hosting again'), findsNothing);
    });

    testWidgets('a refused "Continue without them" says "You are no longer the '
        'host." and the control goes', (tester) async {
      final setup = await tester.pumpGameFlow(gameMeJson: _me().build());
      _rejectPostsWith(setup, 403);
      setup.registerGameMe(_me(hostId: 2).build());

      await tester.tap(find.text('Continue without them'));
      // The refresh runs real async work through the mock.
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await _settle(tester);
      await _settle(tester);

      expect(find.text(kNoLongerHostMessage), findsOneWidget);
      expect(find.text('Continue without them'), findsNothing);
      await tester.pump(const Duration(seconds: 7));
    });
  });

  group('Vote screen', () {
    testWidgets('"Reveal votes now" follows the host role', (tester) async {
      final setup = await tester.pumpGameFlow(
        gameMeJson: _me(phase: 'voting').build(),
      );
      expect(find.text('Reveal votes now'), findsOneWidget);

      setup.ws.addServerEvent(_handover());
      await _settle(tester);
      expect(find.text('Reveal votes now'), findsNothing);
    });

    testWidgets('"Reveal votes now" appears for the new host', (tester) async {
      final setup = await tester.pumpGameFlow(
        gameMeJson: _me(phase: 'voting').build(),
        userId: 2,
        playerName: 'Ben',
      );
      expect(find.text('Reveal votes now'), findsNothing);

      setup.ws.addServerEvent(_handover());
      await _settle(tester);

      expect(find.text('Reveal votes now'), findsOneWidget);
      expect(find.text('You are hosting while Ana is away'), findsOneWidget);
    });
  });

  group('Talk', () {
    testWidgets('"End Discussion" follows the host role', (tester) async {
      final setup = await tester.pumpGameFlow(
        gameMeJson: _me(phase: 'discussion').build(),
      );
      expect(find.text('End Discussion'), findsOneWidget);

      setup.ws.addServerEvent(_handover());
      await _settle(tester);

      expect(find.text('End Discussion'), findsNothing);
      expect(find.text('Ben is hosting while you are away'), findsOneWidget);
    });
  });

  group('Results screen', () {
    Map<String, dynamic> results() => _resultsJson();

    testWidgets('"Play Again" moves from the old host to the new one', (
      tester,
    ) async {
      final setup = await tester.pumpGameFlow(
        gameMeJson: _me(phase: 'results').build(),
        extraOverrides: const [],
      );
      expect(find.text('Play Again'), findsNothing); // results not loaded yet
      setup.registerResults(resultsJson: results());
      setup.ws.addServerEvent(GameEvents.gameResults());
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await _settle(tester);
      await _settle(tester);
      expect(find.text('Play Again'), findsOneWidget);

      setup.ws.addServerEvent(_handover());
      await _settle(tester);

      expect(find.text('Play Again'), findsNothing);
      expect(
        find.text('Waiting for the host to start another game.'),
        findsOneWidget,
      );
    });

    testWidgets('the new host gets "Play Again" and loses the waiting line', (
      tester,
    ) async {
      final setup = await tester.pumpGameFlow(
        gameMeJson: _me(phase: 'results').build(),
        userId: 2,
        playerName: 'Ben',
      );
      setup.registerResults(resultsJson: results());
      setup.ws.addServerEvent(GameEvents.gameResults());
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await _settle(tester);
      await _settle(tester);
      expect(find.text('Play Again'), findsNothing);

      setup.ws.addServerEvent(_handover());
      await _settle(tester);

      expect(find.text('Play Again'), findsOneWidget);
      expect(
        find.text('Waiting for the host to start another game.'),
        findsNothing,
      );
    });
  });

  group('The owner left and ownership was transferred', () {
    test(
      'host_changed "transferred" makes the new owner the host for good',
      () async {
        final setup = GameTestSetup.create(
          gameMeJson: _me().build(),
          userId: 2,
        );
        addTearDown(setup.dispose);
        await setup.readGameState();

        setup.ws.addServerEvent(_transferred());

        expect(setup.currentState.isHost, isTrue);
        expect(setup.currentState.hostId, 2);
        expect(
          setup.currentState.hostNotice?.reason,
          HostChangeReason.transferred,
        );
      },
    );

    test('the next phase change clears the "is the host now" line', () async {
      final setup = GameTestSetup.create(gameMeJson: _me().build());
      addTearDown(setup.dispose);
      await setup.readGameState();

      setup.ws.addServerEvent(_transferred());
      setup.ws.addServerEvent(GameEvents.phaseChange(phase: 'discussion'));

      expect(setup.currentState.hostNotice, isNull);
    });

    testWidgets(
      'the new host reads "You are the host now" and gets Play Again',
      (tester) async {
        final setup = await tester.pumpGameFlow(
          gameMeJson: _me(phase: 'results').build(),
          userId: 2,
          playerName: 'Ben',
        );
        setup.registerResults(resultsJson: _resultsJson());
        setup.ws.addServerEvent(GameEvents.gameResults());
        await tester.runAsync(() => Future<void>.delayed(Duration.zero));
        await _settle(tester);
        await _settle(tester);
        expect(find.text('Play Again'), findsNothing);

        setup.ws.addServerEvent(_transferred());
        await _settle(tester);

        expect(find.text('You are the host now'), findsOneWidget);
        expect(find.text('Play Again'), findsOneWidget);
        await tester.pump(const Duration(seconds: 7));
        expect(find.text('You are the host now'), findsNothing);
        expect(find.text('Play Again'), findsOneWidget);
      },
    );

    testWidgets('a bystander reads "Ben is the host now" and has no Play '
        'Again', (tester) async {
      final setup = await tester.pumpGameFlow(
        gameMeJson: _me(phase: 'results').build(),
        userId: 3,
        playerName: 'Cleo',
      );
      setup.registerResults(resultsJson: _resultsJson());
      setup.ws.addServerEvent(GameEvents.gameResults());
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await _settle(tester);
      await _settle(tester);

      setup.ws.addServerEvent(_transferred());
      await _settle(tester);

      expect(find.text('Ben is the host now'), findsOneWidget);
      expect(find.text('Play Again'), findsNothing);
      await tester.pump(const Duration(seconds: 7));
    });
  });
}
