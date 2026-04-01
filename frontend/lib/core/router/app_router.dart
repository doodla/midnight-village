import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/auth/domain/auth_state.dart';
import '../../features/auth/presentation/auth_notifier.dart';
import '../config/env.dart';
import 'routes.dart';

part 'app_router.g.dart';

/// Application router with auth redirect guard.
///
/// Redirect rules:
/// - Unauthenticated users on `/lobby/*` or `/game/*` are redirected to `/`.
/// - Authenticated users at `/` with an active game are redirected to
///   `/game/:id` (result is cached; cache is cleared on auth state changes).
@Riverpod(keepAlive: true)
GoRouter appRouter(Ref ref) {
  String? cachedActiveGameId;

  // Bridge Riverpod auth state changes to GoRouter's refreshListenable so
  // the router re-evaluates its redirect whenever the user logs in or out.
  final notifier = _RouterChangeNotifier();
  ref.listen<AuthState>(authProvider, (_, _) {
    cachedActiveGameId = null; // Clear cached game on auth change.
    notifier.notify();
  });
  ref.onDispose(notifier.dispose);

  return GoRouter(
    routes: $appRoutes,
    debugLogDiagnostics: Env.isDev,
    refreshListenable: notifier,
    redirect: (context, state) async {
      final authState = ref.read(authProvider);
      final path = state.uri.path;
      final isAuthenticated = authState is AuthAuthenticated;

      // While auth is still loading, don't redirect — wait for resolution.
      if (authState is AuthInitial || authState is AuthLoading) {
        return null;
      }

      // Redirect unauthenticated users away from protected routes.
      if (!isAuthenticated) {
        if (path.startsWith('/lobby/') || path.startsWith('/game/')) {
          return '/';
        }
        return null;
      }

      // Authenticated user navigating to home — check for an active game.
      if (path == '/') {
        if (cachedActiveGameId != null) {
          return '/game/$cachedActiveGameId';
        }
        try {
          final client = ref.read(authenticatedClientProvider);
          final response = await client.get<Map<String, dynamic>>(
            '/onuw/me/current-game/',
          );
          final data = response.data;
          if (data is Map<String, dynamic>) {
            final gameId = data['id']?.toString();
            if (gameId != null) {
              cachedActiveGameId = gameId;
              return '/game/$gameId';
            }
          }
        } catch (_) {
          // No active game or network error — remain on home.
        }
      }

      return null;
    },
  );
}

/// [ChangeNotifier] that bridges Riverpod auth state changes to
/// GoRouter's [refreshListenable].
///
/// Notified when auth state changes so GoRouter re-evaluates its redirect.
class _RouterChangeNotifier extends ChangeNotifier {
  void notify() => notifyListeners();
}
