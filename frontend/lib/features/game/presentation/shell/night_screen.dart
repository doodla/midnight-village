import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design_system/copy/copy.dart';
import '../../../../design_system/layout/space.dart';
import '../../../../design_system/night/night_board.dart';
import '../../../../design_system/primitives/fit_line.dart';
import '../../../../design_system/primitives/screen_frame.dart';
import '../../../../design_system/primitives/world_timer.dart';
import '../../../../design_system/skin/ground.dart';
import '../../../../design_system/skin/skin.dart';
import '../live_game.dart';
import '../stage_seconds.dart';

/// The night (06), wired to the server: [NightBoard] fed from `/me/` (the
/// seats, this phone's prompt, the face of "You", the seconds left by the
/// server's deadline) and its Choose sent through the game's outbox
/// ([LiveGameNotifier.choose], answered as the board reads it,
/// [TapOutcome.forBoard]). The board itself shows "Chosen" on the tap, arms
/// the Doppelganger's follow-up when `/me/` brings it (a new turn), and
/// shows "Not sent." with "Try again" only when no answer came.
///
/// While this game's `/me/` has not loaded (a cold start in the night), or
/// shows no open window, this is 05: the sleeping village and the candle
/// (first-time play spec, section 7: 05 shows only while `/me/` loads).
class NightScreen extends ConsumerWidget {
  const NightScreen({super.key, required this.gameId, required this.game});

  final String gameId;

  /// The game as the shell has it; null while its first `/me/` loads.
  final LiveGame? game;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final me = game?.me;
    final prompt = me?.prompt;
    if (me == null || !me.inWindow || prompt == null) {
      return NightWaitScreen(
        gameId: gameId,
        deadline: me?.inWindow ?? false ? me!.deadline : null,
      );
    }
    final notifier = ref.read(liveGameProvider(gameId).notifier);
    return StageSeconds(
      gameId: gameId,
      deadline: me.deadline,
      builder: (context, seconds) => NightBoard(
        seats: me.seats,
        selfId: me.playerId,
        prompt: prompt,
        face: me.report.you(prompt),
        // An untimed window (a debug setting): the candle alone.
        secondsLeft: seconds,
        onChoose: (stage, picks) async =>
            (await notifier.choose(stage, picks)).forBoard,
      ),
    );
  }
}

/// 05: the village sleeps, the candle, nothing to do. The number shows only
/// when the server's deadline is known; while `/me/` loads there is none.
class NightWaitScreen extends StatelessWidget {
  const NightWaitScreen({super.key, required this.gameId, this.deadline});

  final String gameId;
  final DateTime? deadline;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return ScreenFrame(
      ground: GroundKind.night,
      topArt: skin.art.sleepingVillage,
      body: SizedBox(
        width: double.infinity,
        child: Column(
          spacing: Space.lgPlus,
          children: [
            Semantics(
              header: true,
              child: FitLine(
                CommonCopy.nightTitle,
                style: skin.typography.screenTitle,
              ),
            ),
            if (deadline == null)
              const WorldTimer.candle(secondsLeft: null)
            else
              StageSeconds(
                gameId: gameId,
                deadline: deadline,
                builder: (context, seconds) =>
                    WorldTimer.candle(secondsLeft: seconds),
              ),
          ],
        ),
      ),
    );
  }
}
