import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:midnight_village/core/api/api_client.dart';
import 'package:midnight_village/core/api/authenticated_client.dart';
import 'package:midnight_village/core/router/app_router.dart';
import 'package:midnight_village/core/router/routes.dart';
import 'package:midnight_village/core/wakelock/wakelock_service.dart';
import 'package:midnight_village/design_system/skin/skin_choice.dart';
import 'package:midnight_village/features/auth/domain/auth_state.dart';
import 'package:midnight_village/features/auth/domain/user.dart';
import 'package:midnight_village/features/auth/presentation/auth_notifier.dart';
import 'package:midnight_village/features/game/presentation/game_socket.dart';
import 'package:midnight_village/features/lobby/data/home_service.dart';

import '../../helpers/contract/contract_samples.dart';
import '../../helpers/fake_wakelock_service.dart';
import '../../helpers/mock_http_client.dart';
import '../../helpers/mock_websocket.dart';

/// The running game the server reports for the player.
final _running = ContractSamples.map('http/game/current_game_active');

/// Lets the redirect run and the screen it opens build. The game screen
/// animates for as long as it is open, so this does not wait for it to settle.
Future<void> _settle(WidgetTester tester) async {
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 500));
}

void main() {
  group('Route resolution', () {
    test('/game/:gameId resolves to GameRoute(gameId: ...)', () {
      const route = GameRoute(gameId: '550e8400-uuid');
      expect(route.location, '/game/550e8400-uuid');
    });

    test('/ resolves to HomeRoute', () {
      const route = HomeRoute();
      expect(route.location, '/');
    });
  });

  group('Auth redirect guard', () {
    late MockHttpClient http;

    setUp(() {
      http = MockHttpClient()
        // Home (01 at no table) reads where the player sits, the online
        // count and the last game.
        ..answer(
          'GET',
          '/me/table/',
          ContractSamples.load('http/lobby/my_table_none'),
        )
        ..answer(
          'GET',
          '/stats/online/',
          ContractSamples.load('http/core/online_stats'),
        )
        ..answer(
          'GET',
          '/onuw/me/recent-games/',
          ContractSamples.load('http/game/recent_games_none'),
        );
    });

    /// The server's answer to "what game am I in" (recorded [sample]).
    void currentGame(String sample, {int status = 200}) => http.answer(
      'GET',
      '/onuw/me/current-game/',
      ContractSamples.load(sample),
      status: status,
    );

    /// Creates a [ProviderContainer] and pumps a [MaterialApp.router] backed
    /// by [appRouterProvider].
    ///
    /// Returns the [GoRouter] so callers can navigate and inspect state.
    /// The container is disposed via [addTearDown].
    Future<GoRouter> pumpRouterApp(
      WidgetTester tester, {
      required AuthState authState,
    }) async {
      final container = ProviderContainer(
        overrides: [
          authProvider.overrideWithValue(authState),
          authenticatedClientProvider.overrideWithValue(
            AuthenticatedClient.forTesting(dio: http.dio),
          ),
          homeServiceProvider.overrideWithValue(
            HomeService(client: ApiClient(dio: http.dio)),
          ),
          // The table's shell the game link opens: no real socket or
          // wakelock (it shows what `/me/table/` says: 01 here).
          gameWebSocketProvider.overrideWith((ref, gameId) => null),
          gameWebSocketStreamProvider.overrideWith(
            (ref, gameId) => MockWebSocketChannel().stream,
          ),
          wakelockServiceProvider.overrideWithValue(FakeWakelockService()),
        ],
      );
      addTearDown(container.dispose);

      final router = container.read(appRouterProvider);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          // The app's theme: the game route's first frame is drawn from
          // the skin's primitives.
          child: MaterialApp.router(
            theme: container.read(appThemeProvider),
            routerConfig: router,
          ),
        ),
      );
      await _settle(tester);

      return router;
    }

    String location(GoRouter router) =>
        router.routerDelegate.currentConfiguration.uri.toString();

    testWidgets(
      'unauthenticated user navigating to /game/:id is redirected to /',
      (tester) async {
        final router = await pumpRouterApp(
          tester,
          authState: const AuthState.unauthenticated(),
        );

        router.go('/game/some-game-id');
        await tester.pumpAndSettle();

        expect(location(router), '/');
      },
    );

    testWidgets('authenticated user at / with no active game stays on /', (
      tester,
    ) async {
      currentGame('http/game/current_game_none');

      final router = await pumpRouterApp(
        tester,
        authState: AuthState.authenticated(User(id: 1, displayName: 'Alice')),
      );

      expect(location(router), '/');

      // Close home (01) and let its timers run out.
      await tester.pumpWidget(const SizedBox());
      await tester.pump(const Duration(seconds: 1));
    });

    testWidgets(
      'authenticated user at / stays on / when the look-up is refused',
      (tester) async {
        // The access token expired: the router does not redirect.
        currentGame('http/auth/token_expired', status: 401);

        final router = await pumpRouterApp(
          tester,
          authState: AuthState.authenticated(User(id: 1, displayName: 'Alice')),
        );

        expect(location(router), '/');

        // Close home (01) and let its timers run out.
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 1));
      },
    );

    testWidgets(
      'authenticated user at / with active game is redirected to /game/:id',
      (tester) async {
        currentGame('http/game/current_game_active');

        final router = await pumpRouterApp(
          tester,
          authState: AuthState.authenticated(User(id: 1, displayName: 'Alice')),
        );

        expect(location(router), '/game/${_running['game_id']}');

        // Close the game screen and let its timers run out.
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 1));
      },
    );

    testWidgets(
      'a player who left a finished game is not sent back into it from /',
      (tester) async {
        currentGame('http/game/current_game_active');
        final router = await pumpRouterApp(
          tester,
          authState: AuthState.authenticated(User(id: 1, displayName: 'Alice')),
        );
        expect(location(router), '/game/${_running['game_id']}');

        // The game is over; the server no longer lists it as active.
        currentGame('http/game/current_game_none');
        router.go('/');
        await _settle(tester);

        expect(location(router), '/');

        // Let the closed game screen's timers run out.
        await tester.pumpWidget(const SizedBox());
        await tester.pump(const Duration(seconds: 1));
      },
    );
  });
}
