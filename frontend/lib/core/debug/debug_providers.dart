import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../features/auth/presentation/auth_notifier.dart';
import '../../features/game/presentation/game_socket.dart';
import '../../features/game/presentation/live_game.dart';
import '../../features/game/presentation/table_screen.dart';
import '../../features/lobby/presentation/where_am_i_provider.dart';
import '../config/env.dart';
import 'debug_api_client.dart';
import 'debug_table_controller.dart';

part 'debug_providers.g.dart';

/// DEBUG-ONLY wiring for the debug toolbar (contract §D1/§D2/§D3).
///
/// Everything here is reachable only behind const [Env.isDev]; the toolbar
/// route and these providers are never built in prod.

/// The dev backend the TOOLBAR targets. The automated `test_e2e/` runners
/// target the harness backend via their own constants (its port is chosen
/// per run), NOT this — see `test_e2e/harness/harness_config.dart`.
const String _toolbarApiBaseUrl = String.fromEnvironment(
  'DEBUG_API_URL',
  defaultValue: 'http://localhost:8000/api',
);
const String _toolbarOrigin = String.fromEnvironment(
  'DEBUG_ORIGIN',
  defaultValue: 'http://localhost:8000',
);

/// The §D2 explicit-per-player-token client used by the toolbar.
@riverpod
DebugApiClient debugApiClient(Ref ref) {
  assert(Env.isDev, 'debugApiClient must never be built in prod');
  return DebugApiClient(baseUrl: _toolbarApiBaseUrl, origin: _toolbarOrigin);
}

/// The §D1 table controller, wired to the real auth notifier, the game's
/// socket providers (`game_socket.dart`) and the game's state.
///
/// `switchTo` adopts a session (no refresh) and invalidates
/// `gameWebSocketProvider`, `gameWebSocketStreamProvider` and
/// `gameConnectionStateProvider` so the prior player's socket is disposed and
/// the new player's attaches (exactly one live socket), and drops the
/// previous player's `/me/`, `/me/table/` and local steps.
@riverpod
DebugTableController debugTableController(Ref ref) {
  assert(Env.isDev, 'debugTableController must never be built in prod');
  return DebugTableController(
    client: ref.watch(debugApiClientProvider),
    adoptSession: (user, {required accessToken, required refreshToken}) => ref
        .read(authProvider.notifier)
        .adoptSession(
          user,
          accessToken: accessToken,
          refreshToken: refreshToken,
        ),
    invalidateGameProviders: (gameId) {
      ref
        ..invalidate(gameWebSocketProvider(gameId))
        ..invalidate(gameWebSocketStreamProvider(gameId))
        ..invalidate(gameConnectionStateProvider(gameId))
        ..invalidate(liveGameProvider(gameId))
        ..invalidate(myTableProvider)
        ..invalidate(localStepsProvider);
    },
  );
}
