import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:midnight_village/core/api/authenticated_client.dart';
import 'package:midnight_village/core/router/app_router.dart';
import 'package:midnight_village/core/router/routes.dart';
import 'package:midnight_village/design_system/tokens/firelit_gothic_theme.dart';
import 'package:midnight_village/design_system/tokens/app_tokens_provider.dart';
import 'package:midnight_village/features/auth/domain/auth_state.dart';
import 'package:midnight_village/features/auth/domain/user.dart';
import 'package:midnight_village/features/auth/presentation/auth_notifier.dart';
import 'package:mocktail/mocktail.dart';

import '../../helpers/contract/contract_samples.dart';

/// The running game the server reports for the player.
final _running = ContractSamples.map('http/game/current_game_active');

class _MockAuthenticatedClient extends Mock implements AuthenticatedClient {}

void main() {
  setUpAll(() {
    registerFallbackValue(RequestOptions(path: ''));
  });

  group('Route resolution', () {
    test('/lobby/:code resolves to LobbyRoute(code: ...)', () {
      const route = LobbyRoute(code: 'ABC123');
      expect(route.location, '/lobby/ABC123');
    });

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
    late _MockAuthenticatedClient mockClient;

    setUp(() {
      mockClient = _MockAuthenticatedClient();
    });

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
          authenticatedClientProvider.overrideWithValue(mockClient),
          activeThemeProvider.overrideWithValue(const FirelitGothicTheme()),
        ],
      );
      addTearDown(container.dispose);

      final router = container.read(appRouterProvider);

      await tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp.router(routerConfig: router),
        ),
      );
      await tester.pumpAndSettle();

      return router;
    }

    testWidgets(
      'unauthenticated user navigating to /lobby/:code is redirected to /',
      (tester) async {
        final router = await pumpRouterApp(
          tester,
          authState: const AuthState.unauthenticated(),
        );

        router.go('/lobby/ABC');
        await tester.pumpAndSettle();

        expect(router.routerDelegate.currentConfiguration.uri.path, '/');
      },
    );

    testWidgets(
      'unauthenticated user navigating to /game/:id is redirected to /',
      (tester) async {
        final router = await pumpRouterApp(
          tester,
          authState: const AuthState.unauthenticated(),
        );

        router.go('/game/some-game-id');
        await tester.pumpAndSettle();

        expect(router.routerDelegate.currentConfiguration.uri.path, '/');
      },
    );

    testWidgets('authenticated user at / with no active game stays on /', (
      tester,
    ) async {
      // No active game — backend returns {"game": null} with 200.
      when(
        () => mockClient.get<Map<String, dynamic>>('/onuw/me/current-game/'),
      ).thenAnswer(
        (_) async => Response<Map<String, dynamic>>(
          data: ContractSamples.map('http/game/current_game_none'),
          statusCode: 200,
          requestOptions: RequestOptions(path: '/onuw/me/current-game/'),
        ),
      );

      final router = await pumpRouterApp(
        tester,
        authState: AuthState.authenticated(User(id: 1, displayName: 'Alice')),
      );

      expect(router.routerDelegate.currentConfiguration.uri.path, '/');
    });

    testWidgets(
      'authenticated user at / stays on / when current-game API fails',
      (tester) async {
        // Network error — router should catch and not redirect.
        when(
          () => mockClient.get<Map<String, dynamic>>('/onuw/me/current-game/'),
        ).thenThrow(
          DioException(
            requestOptions: RequestOptions(path: '/onuw/me/current-game/'),
            type: DioExceptionType.connectionError,
          ),
        );

        final router = await pumpRouterApp(
          tester,
          authState: AuthState.authenticated(User(id: 1, displayName: 'Alice')),
        );

        expect(router.routerDelegate.currentConfiguration.uri.path, '/');
      },
    );

    testWidgets(
      'authenticated user at / with active game is redirected to /game/:id',
      (tester) async {
        when(
          () => mockClient.get<Map<String, dynamic>>('/onuw/me/current-game/'),
        ).thenAnswer(
          (_) async => Response<Map<String, dynamic>>(
            data: _running,
            statusCode: 200,
            requestOptions: RequestOptions(path: '/onuw/me/current-game/'),
          ),
        );

        final router = await pumpRouterApp(
          tester,
          authState: AuthState.authenticated(User(id: 1, displayName: 'Alice')),
        );

        expect(
          router.routerDelegate.currentConfiguration.uri.path,
          '/game/${_running['game_id']}',
        );
      },
    );

    testWidgets('the redirect into the active game carries its table code', (
      tester,
    ) async {
      when(
        () => mockClient.get<Map<String, dynamic>>('/onuw/me/current-game/'),
      ).thenAnswer(
        (_) async => Response<Map<String, dynamic>>(
          data: _running,
          statusCode: 200,
          requestOptions: RequestOptions(path: '/onuw/me/current-game/'),
        ),
      );

      final router = await pumpRouterApp(
        tester,
        authState: AuthState.authenticated(User(id: 1, displayName: 'Alice')),
      );

      final uri = router.routerDelegate.currentConfiguration.uri;
      expect(uri.toString(), '/game/${_running['game_id']}');
    });

    testWidgets(
      'a player who left a finished game is not sent back into it from /',
      (tester) async {
        Response<Map<String, dynamic>> answer(Map<String, dynamic> data) =>
            Response<Map<String, dynamic>>(
              data: data,
              statusCode: 200,
              requestOptions: RequestOptions(path: '/onuw/me/current-game/'),
            );
        when(
          () => mockClient.get<Map<String, dynamic>>('/onuw/me/current-game/'),
        ).thenAnswer((_) async => answer(_running));
        final router = await pumpRouterApp(
          tester,
          authState: AuthState.authenticated(User(id: 1, displayName: 'Alice')),
        );
        expect(
          router.routerDelegate.currentConfiguration.uri.path,
          '/game/${_running['game_id']}',
        );

        // The game is over; the server no longer lists it as active.
        when(
          () => mockClient.get<Map<String, dynamic>>('/onuw/me/current-game/'),
        ).thenAnswer(
          (_) async =>
              answer(ContractSamples.map('http/game/current_game_none')),
        );
        router.go('/');
        await tester.pumpAndSettle();

        expect(router.routerDelegate.currentConfiguration.uri.path, '/');
      },
    );
  });
}
