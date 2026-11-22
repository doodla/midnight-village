import 'package:flutter/foundation.dart';
import 'package:go_router/go_router.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/auth/domain/auth_state.dart';
import '../../features/auth/presentation/auth_notifier.dart';
import '../../features/debug/presentation/debug_toolbar_screen.dart';
import '../config/env.dart';
import 'back_policy.dart';
import 'routes.dart';

part 'app_router.g.dart';

/// Application router with auth redirect guard.
///
/// Redirect rules:
/// - Unauthenticated users on `/game/*` are redirected to `/`.
/// - Nothing else: home (`/`) is the table's shell for a signed-in player,
///   which shows the game they are in from `/me/table/` with no extra
///   request (a "which game" look-up here cost a round trip before the
///   first screen, for a URL change only).
@Riverpod(keepAlive: true)
GoRouter appRouter(Ref ref) {
  // Bridge Riverpod auth state changes to GoRouter's refreshListenable so
  // the router re-evaluates its redirect whenever the user logs in or out.
  final notifier = _RouterChangeNotifier();
  ref.listen<AuthState>(authProvider, (_, _) {
    notifier.notify();
  });
  ref.onDispose(notifier.dispose);

  return GoRouter(
    routes: [
      ...$appRoutes,
      // DEBUG-ONLY developer toolbar. Registered only when const Env.isDev is
      // true, so the route (and DebugToolbarScreen) tree-shake out of prod.
      if (Env.isDev)
        GoRoute(
          path: '/debug',
          // Back returns to the app (its own page: the policy is here too).
          builder: (context, state) => BackPolicy(
            rule: BackRule.staysPut,
            child: BackHandler(
              onBack: () => context.go('/'),
              child: const DebugToolbarScreen(),
            ),
          ),
        ),
    ],
    debugLogDiagnostics: Env.isDev,
    refreshListenable: notifier,
    redirect: (context, state) {
      final authState = ref.read(authProvider);
      // While the saved account is read back, nothing moves.
      if (authState is AuthInitial || authState is AuthLoading) return null;
      // Redirect unauthenticated users away from protected routes.
      if (authState is! AuthAuthenticated &&
          state.uri.path.startsWith('/game/')) {
        return '/';
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
