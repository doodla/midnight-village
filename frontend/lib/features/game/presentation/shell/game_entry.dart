import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

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

/// Which night [gameId] runs, read once from its `/me/` (it never changes),
/// fetched until it is known.
@Riverpod(keepAlive: true, retry: retryForever)
Future<NightProtocol> gameProtocol(Ref ref, String gameId) =>
    ref.watch(gameServiceProvider).fetchNightProtocol(gameId);

/// The game route's screen: a game whose `/me/` has a `stage` (night
/// protocol 2) is played in the rebuilt [TableShell]; any other keeps the
/// old [GameContainerScreen], untouched.
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
    return switch (protocol.value) {
      NightProtocol.two => const TableShell(),
      NightProtocol.one => GameContainerScreen(gameId: gameId),
      null => ScreenFrame(
        ground: GroundKind.night,
        body: const SizedBox.shrink(),
        actions: [
          if (protocol.hasError) const Notice(message: BannerCopy.offline),
        ],
      ),
    };
  }
}
