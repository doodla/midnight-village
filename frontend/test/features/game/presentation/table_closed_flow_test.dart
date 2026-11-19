import 'package:dio/dio.dart';
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

import '../../../helpers/fake_wakelock_service.dart';
import '../../../helpers/game_state_factory.dart';
import '../../../helpers/game_test_setup.dart';

const _gameId = 'test-game-id';
const _code = 'ABC123';

Map<String, dynamic> _resultsJson() => {
  'winning_teams': ['village'],
  'reason': 'The werewolf was found.',
  'center_cards': <String>[],
  'players': [
    for (final (i, n) in ['Ana', 'Ben', 'Cleo'].indexed)
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

/// Answers every request to a path ending in [suffix] with 404, ahead of the
/// mock that answers everything else.
void _gone(GameTestSetup setup, String suffix, {String? method}) {
  setup.http.dio.interceptors.insert(
    0,
    InterceptorsWrapper(
      onRequest: (options, handler) {
        if (options.path.endsWith(suffix) &&
            (method == null || options.method == method)) {
          handler.reject(
            DioException(
              requestOptions: options,
              response: Response(
                requestOptions: options,
                statusCode: 404,
                data: {'detail': 'gone'},
              ),
              type: DioExceptionType.badResponse,
            ),
          );
        } else {
          handler.next(options);
        }
      },
    ),
  );
}

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
  setup.registerResults(resultsJson: _resultsJson());
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
      _gone(p.setup, '/me/');

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
        beforePump: (s) => _gone(s, '/me/'),
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
      _gone(p.setup, '/play-again/', method: 'POST');

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
      _gone(p.setup, '/leave/', method: 'POST');

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
        beforePump: (s) => _gone(s, '/lobbies/$_code/'),
      );
      await tester.runAsync(() => Future<void>.delayed(Duration.zero));
      await _settle(tester);

      expect(p.location, '/');
      expect(find.text(kTableClosedMessage), findsOneWidget);
    });
  });
}
