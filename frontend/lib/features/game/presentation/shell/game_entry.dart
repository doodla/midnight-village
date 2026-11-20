import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../../core/api/api_exception.dart';
import '../../../../core/config/env.dart';
import '../../../../core/healing/healing.dart';
import '../../../../design_system/copy/copy.dart';
import '../../../../design_system/primitives/notice.dart';
import '../../../../design_system/primitives/screen_frame.dart';
import '../../../../design_system/skin/ground.dart';
import '../../data/game_service.dart';
import '../../domain/night_protocol.dart';
import '../game_container_screen.dart';
import 'table_shell.dart';

part 'game_entry.g.dart';

/// Whether [error] is the server saying no (not in this game, the game is
/// gone, a broken answer) rather than the phone failing to reach it.
bool refusedByServer(Object error) => switch (error) {
  NetworkException() || ServerException() || RateLimitException() => false,
  UnhandledHttpException(:final statusCode) => statusCode < 500,
  ApiException() => true,
  _ => false,
};

/// Fetched again until it succeeds while the phone cannot reach the server
/// ([retryForever]); a refusal is final.
Duration? _retryUnlessRefused(int count, Object error) =>
    refusedByServer(error) ? null : retryForever(count, error);

/// Which night [gameId] runs, read once from its `/me/` (it never changes).
@Riverpod(keepAlive: true, retry: _retryUnlessRefused)
Future<NightProtocol> gameProtocol(Ref ref, String gameId) =>
    ref.watch(gameServiceProvider).fetchNightProtocol(gameId);

/// The game route's screen: a game whose `/me/` has a `stage` (night
/// protocol 2) is played in the rebuilt [TableShell]; any other keeps the
/// old [GameContainerScreen], untouched.
///
/// - While the one `/me/` that decides is out: the night's ground, nothing
///   on it (for a protocol-1 game in a dev build, that fetch is all it adds
///   before the old screen).
/// - Unreachable server: "One moment", and the fetch is made again until it
///   answers.
/// - The server refuses (not in this game, the game is gone): the old
///   screen, whose own error path says so and goes home. Never an endless
///   "One moment".
///
/// The rebuilt shell still shows placeholders for the screens not rebuilt,
/// so it is reached only in a dev build ([Env.isDev], a const: a release
/// build has no protocol check and no shell), and only a protocol-2 table
/// reaches it, which only the `/debug` toolbar creates. Remove the
/// [Env.isDev] gate when the last placeholder is gone.
class GameEntry extends ConsumerWidget {
  const GameEntry({super.key, required this.gameId});

  final String gameId;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    if (!Env.isDev) return GameContainerScreen(gameId: gameId);
    final protocol = ref.watch(gameProtocolProvider(gameId));
    final error = protocol.error;
    if (protocol.value == null && error != null && refusedByServer(error)) {
      return GameContainerScreen(gameId: gameId);
    }
    return switch (protocol.value) {
      NightProtocol.two => const TableShell(),
      NightProtocol.one => GameContainerScreen(gameId: gameId),
      null => ScreenFrame(
        ground: GroundKind.night,
        body: const SizedBox.shrink(),
        actions: [if (error != null) const Notice(message: BannerCopy.offline)],
      ),
    };
  }
}
