import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:midnight_village/core/api/authenticated_client.dart';
import 'package:midnight_village/core/host/host_change.dart';
import 'package:midnight_village/core/wakelock/wakelock_service.dart';
import 'package:midnight_village/design_system/tokens/app_tokens_provider.dart';
import '../../../design_system/test_helpers/midnight_village_theme.dart';
import 'package:midnight_village/design_system/skin/skin_theme.dart';
import 'package:midnight_village/design_system/skin/skins/shadow_paper.dart';
import 'package:midnight_village/features/auth/domain/auth_state.dart';
import 'package:midnight_village/features/auth/domain/user.dart';
import 'package:midnight_village/features/auth/presentation/auth_notifier.dart';
import 'package:midnight_village/features/game/data/game_service.dart';
import 'package:midnight_village/features/game/presentation/game_container_screen.dart';
import 'package:midnight_village/features/game/presentation/game_notifier.dart';

import '../../../helpers/contract/contract_samples.dart';
import '../../../helpers/fake_wakelock_service.dart';
import '../../../helpers/game_state_factory.dart';
import '../../../helpers/game_test_setup.dart';

const _gameId = 'test-game-id';
const _code = 'ABC123';

/// The table is gone (its last member left): the server answers 404, with
/// the body it sends for that endpoint.
void _meGone(GameTestSetup setup) => setup.registerGet(
  '/onuw/games/$_gameId/me/',
  ContractSamples.load('http/game/me_not_found'),
  statusCode: 404,
);

void _tableGone(GameTestSetup setup) => setup.registerGet(
  '/lobbies/$_code/',
  ContractSamples.load('http/lobby/not_found'),
  statusCode: 404,
);

void _postGone(GameTestSetup setup, String path) => setup.registerPost(
  path,
  data: {'detail': 'Lobby not found.'},
  statusCode: 404,
);

class _Pumped {
  _Pumped(this.setup, this.router);
  final GameTestSetup setup;
  final GoRouter router;
  String get location => router.state.uri.toString();
}

Future<_Pumped> _pump(
  WidgetTester tester, {
  required Map<String, dynamic> me,
  void Function(GameTestSetup setup)? beforePump,
}) async {
  final setup = GameTestSetup.create(gameMeJson: me);
  addTearDown(setup.dispose);
  setup
    ..registerResults()
    ..registerTable(code: _code);
  beforePump?.call(setup);
  final client = AuthenticatedClient.forTesting(dio: setup.http.dio);
  const theme = MidnightVillageTheme();
  final router = GoRouter(
    initialLocation: '/game/$_gameId?lobby=$_code',
    routes: [
      GoRoute(
        path: '/',
        builder: (_, _) => const Scaffold(body: Text('HOME SCREEN')),
      ),
      GoRoute(
        path: '/game/:gameId',
        builder: (_, state) => GameContainerScreen(
          gameId: state.pathParameters['gameId']!,
          lobbyCode: state.uri.queryParameters['lobby'],
        ),
      ),
    ],
  );
  await tester.pumpWidget(
    ProviderScope(
      overrides: [
        activeThemeProvider.overrideWithValue(theme),
        authProvider.overrideWithValue(
          AuthState.authenticated(User(id: 1, displayName: 'Ana')),
        ),
        authenticatedClientProvider.overrideWithValue(client),
        gameServiceProvider.overrideWithValue(GameService(client: client)),
        gameWebSocketProvider.overrideWith((ref, id) => null),
        gameWebSocketStreamProvider.overrideWith((ref, id) => setup.ws.stream),
        wakelockServiceProvider.overrideWithValue(FakeWakelockService()),
      ],
      child: MaterialApp.router(
        theme: skinTheme(shadowPaper),
        routerConfig: router,
      ),
    ),
  );
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  return _Pumped(setup, router);
}

Future<void> _settle(WidgetTester tester) async {
  for (var i = 0; i < 10; i++) {
    await tester.pump(const Duration(milliseconds: 100));
  }
}

Future<void> _tap(WidgetTester tester, String label) async {
  await tester.ensureVisible(find.text(label));
  await tester.pump();
  await tester.tap(find.text(label));
}

void main() {
  group('When the table is gone (404)', () {
    testWidgets('a refresh that gets 404 says so and goes home', (
      tester,
    ) async {
      final p = await _pump(
        tester,
        me: GameMeJsonBuilder().inPhase('results').build(),
      );
      expect(p.location, startsWith('/game/'));
      _meGone(p.setup);

      await tester.runAsync(
        () => ProviderScope.containerOf(
          tester.element(find.byType(GameContainerScreen)),
        ).read(gameProvider(_gameId).notifier).refreshState(),
      );
      await _settle(tester);

      expect(p.location, '/');
      expect(find.text('HOME SCREEN'), findsOneWidget);
      expect(find.text(kTableClosedMessage), findsOneWidget);
      expect(find.text('Failed to load game'), findsNothing);
    });

    testWidgets('a first load that gets 404 says so and goes home instead of '
        '"Failed to load game"', (tester) async {
      final p = await _pump(
        tester,
        me: GameMeJsonBuilder().build(),
        beforePump: _meGone,
      );
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await _settle(tester);

      expect(p.location, '/');
      expect(find.text(kTableClosedMessage), findsOneWidget);
    });

    testWidgets('Play Again that gets 404 says so and goes home', (
      tester,
    ) async {
      final p = await _pump(
        tester,
        me: GameMeJsonBuilder().inPhase('results').asHost().build(),
      );
      _postGone(p.setup, '/lobbies/$_code/play-again/');

      await _tap(tester, 'Play Again');
      await _settle(tester);

      expect(p.location, '/');
      expect(find.text(kTableClosedMessage), findsOneWidget);
    });

    testWidgets('Leave that gets 404 says so on the way home', (tester) async {
      final p = await _pump(
        tester,
        me: GameMeJsonBuilder().inPhase('results').build(),
      );
      _postGone(p.setup, '/lobbies/$_code/leave/');

      await _tap(tester, 'Leave');
      await _settle(tester);

      expect(p.location, '/');
      expect(find.text(kTableClosedMessage), findsOneWidget);
    });

    testWidgets('Leave that works goes home without the closed line', (
      tester,
    ) async {
      final p = await _pump(
        tester,
        me: GameMeJsonBuilder().inPhase('results').build(),
      );
      p.setup.registerPost('/lobbies/$_code/leave/');

      await _tap(tester, 'Leave');
      await _settle(tester);

      expect(p.location, '/');
      expect(find.text(kTableClosedMessage), findsNothing);
    });

    testWidgets('a 404 on the table check of an old results link closes it', (
      tester,
    ) async {
      final p = await _pump(
        tester,
        me: GameMeJsonBuilder().inPhase('results').build(),
        beforePump: _tableGone,
      );
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await _settle(tester);

      expect(p.location, '/');
      expect(find.text(kTableClosedMessage), findsOneWidget);
    });
  });
}
