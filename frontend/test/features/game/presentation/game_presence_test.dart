import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/features/game/domain/game_session_state.dart';
import 'package:midnight_village/features/game/presentation/away_notice.dart';
import 'package:midnight_village/features/game/presentation/game_notifier.dart';

import '../../../helpers/game_events.dart';
import '../../../helpers/game_state_factory.dart';
import '../../../helpers/game_test_setup.dart';

const _gameId = 'test-game-id';

bool _connected(GameSessionState s, int id) =>
    s.players.firstWhere((p) => p.playerId == id).connected;

Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
}

void main() {
  group('Presence in game state', () {
    test('everyone counts as connected when the server says nothing', () async {
      final setup = GameTestSetup.create();
      addTearDown(setup.dispose);

      final state = await setup.readGameState();

      expect(state.players.every((p) => p.connected), isTrue);
      expect(state.hasAwayPlayers, isFalse);
    });

    test('reads connected from the player list', () async {
      final setup = GameTestSetup.create();
      addTearDown(setup.dispose);
      setup.registerPresence({1: true, 2: false, 3: true});

      final state = await setup.readGameState();

      expect(_connected(state, 2), isFalse);
      expect(_connected(state, 1), isTrue);
      expect(state.awayPlayers.map((p) => p.displayName), ['Bob']);
    });

    test('reads connected from /me/ players when they carry it', () async {
      final setup = GameTestSetup.create(
        gameMeJson: GameMeJsonBuilder().withPlayersAway({3}).build(),
      );
      addTearDown(setup.dispose);

      final state = await setup.readGameState();

      expect(_connected(state, 3), isFalse);
    });

    test('a player list that cannot be fetched leaves everyone connected', () {
      // No /players/ route is mocked: the call fails and is ignored.
      final setup = GameTestSetup.create();
      addTearDown(setup.dispose);

      expect(
        setup.readGameState().then((s) => s.hasAwayPlayers),
        completion(isFalse),
      );
    });

    test('player_presence updates one player and nothing else', () async {
      final setup = GameTestSetup.create();
      addTearDown(setup.dispose);
      await setup.readGameState();

      setup.ws.addServerEvent(
        GameEvents.playerPresence(playerId: 2, connected: false),
      );
      expect(_connected(setup.currentState, 2), isFalse);
      expect(_connected(setup.currentState, 1), isTrue);
      expect(_connected(setup.currentState, 3), isTrue);

      setup.ws.addServerEvent(
        GameEvents.playerPresence(playerId: 2, connected: true),
      );
      expect(_connected(setup.currentState, 2), isTrue);
    });

    test(
      'player_presence for an unknown player or a bad payload is ignored',
      () async {
        final setup = GameTestSetup.create();
        addTearDown(setup.dispose);
        final before = await setup.readGameState();

        setup.ws.addServerEvent(
          GameEvents.playerPresence(playerId: 99, connected: false),
        );
        setup.ws.addServerEvent({'type': 'player_presence', 'player_id': 2});

        expect(setup.currentState.players, before.players);
      },
    );

    test('a refresh after reconnecting reads presence again', () async {
      final setup = GameTestSetup.create();
      addTearDown(setup.dispose);
      await setup.readGameState();
      setup.registerPresence({1: true, 2: true, 3: false});

      await setup.container.read(gameProvider(_gameId).notifier).refreshState();

      expect(_connected(setup.currentState, 3), isFalse);
    });
  });

  group('AwayNotice sentence', () {
    test('names one, two or several players', () {
      expect(AwayNotice.sentence(['Mira']), 'Waiting for Mira to reconnect');
      expect(
        AwayNotice.sentence(['Mira', 'Tom']),
        'Waiting for Mira and Tom to reconnect',
      );
      expect(
        AwayNotice.sentence(['Mira', 'Tom', 'Sam']),
        'Waiting for Mira, Tom and Sam to reconnect',
      );
    });
  });

  group('Night waiting screen', () {
    testWidgets('names the player who is away, for a non-host', (tester) async {
      await tester.pumpGameFlow(
        gameMeJson: GameMeJsonBuilder().withPlayersAway({2}).build(),
      );

      expect(find.text('Waiting for Bob to reconnect'), findsOneWidget);
      expect(find.text('Continue without them'), findsNothing);
    });

    testWidgets('shows nothing extra when everyone is connected', (
      tester,
    ) async {
      await tester.pumpGameFlow(
        gameMeJson: GameMeJsonBuilder().asHost().build(),
      );

      expect(find.textContaining('reconnect'), findsNothing);
      expect(find.text('Continue without them'), findsNothing);
    });

    testWidgets('the host gets "Continue without them" and it advances the '
        'night', (tester) async {
      final setup = await tester.pumpGameFlow(
        gameMeJson: GameMeJsonBuilder().asHost().withPlayersAway({3}).build(),
      );
      setup.registerPost('/onuw/games/$_gameId/advance-wave/');

      expect(find.text('Waiting for Charlie to reconnect'), findsOneWidget);
      await tester.tap(find.text('Continue without them'));
      await _settle(tester);

      expect(
        setup.http.requests.where(
          (r) => r.method == 'POST' && r.path.endsWith('/advance-wave/'),
        ),
        hasLength(1),
      );
    });

    testWidgets('says so in plain words when the host\'s call fails', (
      tester,
    ) async {
      // /advance-wave/ is not mocked, so the call is rejected.
      await tester.pumpGameFlow(
        gameMeJson: GameMeJsonBuilder().asHost().withPlayersAway({3}).build(),
      );

      await tester.tap(find.text('Continue without them'));
      await _settle(tester);

      expect(find.text('That did not work. Try again.'), findsOneWidget);
    });

    testWidgets('follows player_presence events as they arrive', (
      tester,
    ) async {
      final setup = await tester.pumpGameFlow(
        gameMeJson: GameMeJsonBuilder().asHost().build(),
      );
      expect(find.textContaining('reconnect'), findsNothing);

      setup.ws.addServerEvent(
        GameEvents.playerPresence(playerId: 2, connected: false),
      );
      await _settle(tester);
      expect(find.text('Waiting for Bob to reconnect'), findsOneWidget);
      expect(find.text('Continue without them'), findsOneWidget);

      setup.ws.addServerEvent(
        GameEvents.playerPresence(playerId: 3, connected: false),
      );
      await _settle(tester);
      expect(
        find.text('Waiting for Bob and Charlie to reconnect'),
        findsOneWidget,
      );

      setup.ws.addServerEvent(
        GameEvents.playerPresence(playerId: 2, connected: true),
      );
      setup.ws.addServerEvent(
        GameEvents.playerPresence(playerId: 3, connected: true),
      );
      await _settle(tester);
      expect(find.textContaining('reconnect'), findsNothing);
      expect(find.text('Continue without them'), findsNothing);
    });
  });

  group('Vote screen', () {
    GameMeJsonBuilder voting() => GameMeJsonBuilder().inPhase('voting');

    testWidgets(
      'marks the player who is away and says who the game waits for',
      (tester) async {
        await tester.pumpGameFlow(
          gameMeJson: voting().withPlayersAway({2}).build(),
        );

        expect(find.text('away'), findsOneWidget);
        expect(find.text('Waiting for Bob to reconnect'), findsOneWidget);
        expect(find.text('Reveal votes now'), findsNothing);
      },
    );

    testWidgets('an away player who has already voted is marked but not '
        'waited for', (tester) async {
      await tester.pumpGameFlow(
        gameMeJson: voting().withPlayersAway({2}).withPlayersHavingVoted({
          2: true,
        }).build(),
      );

      expect(find.text('away'), findsOneWidget);
      expect(find.textContaining('Waiting for'), findsNothing);
    });

    testWidgets('only the host gets "Reveal votes now", and it reveals', (
      tester,
    ) async {
      final setup = await tester.pumpGameFlow(
        gameMeJson: voting().asHost().withPlayersAway({3}).build(),
      );
      setup.registerPost('/onuw/games/$_gameId/reveal-votes/');

      await tester.tap(find.text('Reveal votes now'));
      await _settle(tester);

      expect(
        setup.http.requests.where(
          (r) => r.method == 'POST' && r.path.endsWith('/reveal-votes/'),
        ),
        hasLength(1),
      );
    });

    testWidgets('no control for the host while everyone is connected', (
      tester,
    ) async {
      await tester.pumpGameFlow(gameMeJson: voting().asHost().build());

      expect(find.text('Reveal votes now'), findsNothing);
      expect(find.text('away'), findsNothing);
    });

    testWidgets('scrolls instead of overflowing on a short phone with the host '
        'control and two dropped players', (tester) async {
      tester.view.physicalSize = const Size(400 * 3, 560 * 3);
      tester.view.devicePixelRatio = 3.0;
      addTearDown(() {
        tester.view.resetPhysicalSize();
        tester.view.resetDevicePixelRatio();
        tester.platformDispatcher.clearAllTestValues();
      });

      await tester.pumpGameFlow(
        gameMeJson: voting().asHost().withPlayersAway({2, 3}).build(),
      );

      expect(find.text('Reveal votes now'), findsOneWidget);
    });

    testWidgets('the mark follows a presence event', (tester) async {
      final setup = await tester.pumpGameFlow(gameMeJson: voting().build());
      expect(find.text('away'), findsNothing);

      setup.ws.addServerEvent(
        GameEvents.playerPresence(playerId: 3, connected: false),
      );
      await _settle(tester);

      expect(find.text('away'), findsOneWidget);
    });
  });

  group('Talk', () {
    testWidgets('shows nothing about presence', (tester) async {
      await tester.pumpGameFlow(
        gameMeJson: GameMeJsonBuilder()
            .inPhase('discussion')
            .asHost()
            .withPlayersAway({2})
            .build(),
      );

      expect(find.textContaining('reconnect'), findsNothing);
      expect(find.text('away'), findsNothing);
      expect(find.text('Continue without them'), findsNothing);
      expect(find.text('Reveal votes now'), findsNothing);
    });
  });
}
