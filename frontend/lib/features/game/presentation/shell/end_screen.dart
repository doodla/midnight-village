import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/requests/player_request.dart';
import '../../../../design_system/primitives/pending.dart';
import '../../../../design_system/skin/ground.dart';
import '../../../../design_system/teach/learned_store.dart';
import '../../../lobby/domain/where_am_i.dart';
import '../../../lobby/presentation/where_am_i_provider.dart';
import '../end/end_board_view.dart';
import '../live_game.dart';
import '../table_screen.dart';
import 'count_screen.dart' show EndWaiting;

/// Which games' end boards this device has shown in this run, and which it
/// saw being played: the reveal plays once per game result per device
/// session, and only for a phone that was in the game when the results came
/// (the phase change to `results`). Nothing is kept on the device: a phone
/// that opens or restarts in the results gets the settled board.
class EndRevealLatch {
  final _played = <String>{};
  final _shown = <String>{};

  /// This phone is at [gameId]'s night, talk or vote.
  void inPlay(String gameId) => _played.add(gameId);

  /// Whether [gameId]'s end board plays its reveal: the first time it is
  /// shown in this run, to a phone that saw the game played. Asked once per
  /// board; every later board of the same game is settled.
  bool take(String gameId) => _shown.add(gameId) && _played.contains(gameId);
}

/// The one [EndRevealLatch] of this run.
final endRevealLatchProvider = Provider<EndRevealLatch>(
  (ref) => EndRevealLatch(),
);

/// The end board (`docs/specs/frontend/end-board.md`), wired to the game: the
/// results body ([LiveGame.outcome], fetched again until it loads) drawn by
/// [EndBoardView] for this phone ([GameMe.playerId]) and its place at the
/// table (host or not, from `/me/`).
///
/// - The reveal plays once per result on this device, and only when the
///   results came while this phone was in the game ([EndRevealLatch]).
/// - Host: "Play again" takes the table back to waiting (every phone then goes
///   to 02, by `/me/table/`); "Edit deck" does that and opens 03 on this
///   phone. Guest: "Leave" (to 01), and who deals next while the host is at
///   the table.
/// - A request is a [Pending]: the tapped control is busy until the screen it
///   leads to is up; one that fails says so on one line, with "Try again"
///   when no answer came.
/// - "What happened"'s first-time cue is the learned cue [Cue.endStep].
/// - Until the results arrive: the night's ground, and "One moment" while
///   their fetch is failing ([EndWaiting]).
class EndScreen extends ConsumerStatefulWidget {
  const EndScreen({super.key, required this.gameId, required this.game});

  final String gameId;

  /// The game as the shell has it; null while its first `/me/` loads.
  final LiveGame? game;

  @override
  ConsumerState<EndScreen> createState() => _EndScreenState();
}

class _EndScreenState extends ConsumerState<EndScreen> {
  final _pending = Pending();
  EndAct? _act;

  /// Whether this board plays its reveal: asked of the latch once, the first
  /// time the results are here.
  bool? _reveal;

  @override
  void initState() {
    super.initState();
    _pending.addListener(_changed);
  }

  void _changed() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _pending.dispose();
    super.dispose();
  }

  /// A request that leads to another screen: busy until `/me/table/` names
  /// it, and not live again in between. Read before the table moves on (this
  /// screen goes with it), so the container, not the widget's ref.
  void _run(EndAct act) {
    if (_pending.busy) return;
    _act = act;
    final container = ProviderScope.containerOf(context, listen: false);
    final notifier = ref.read(liveGameProvider(widget.gameId).notifier);
    unawaited(
      _pending.run(
        switch (act) {
          EndAct.playAgain || EndAct.editDeck => notifier.playAgain,
          EndAct.leave => notifier.leaveTable,
        },
        settle: (again) async {
          if (again) container.invalidate(myTableProvider);
          if (!await readAnsweredIn(container, myTableProvider)) return false;
          final at = container.read(myTableProvider).value;
          if (act == EndAct.editDeck &&
              at != null &&
              at.status == TableStatus.waiting) {
            container.read(localStepsProvider.notifier).openDeck(at);
          }
          return true;
        },
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final outcome = game?.outcome;
    if (game == null || outcome == null) {
      return EndWaiting(
        ground: GroundKind.night,
        failing: game?.outcomeFailing ?? false,
      );
    }
    final me = game.me;
    final reveal = _reveal ??= ref
        .read(endRevealLatchProvider)
        .take(widget.gameId);
    final busy = _pending.busy ? _act : null;
    return EndBoardView(
      outcome: outcome,
      viewerId: me.playerId,
      isHost: me.isHost,
      // The host's name from the table; none when it is not there (then
      // nothing is said about who deals).
      hostName: me.seats.where((s) => s.id == me.hostId).firstOrNull?.name,
      reveal: reveal,
      stepTaught: ref.watch(learnedCuesProvider).contains(Cue.endStep),
      onStepTaught: () =>
          unawaited(ref.read(learnedCuesProvider.notifier).learn(Cue.endStep)),
      busy: busy,
      failure: _pending.failure,
      onTryAgain: () => unawaited(_pending.retry()),
      onPlayAgain: () => _run(EndAct.playAgain),
      onEditDeck: () => _run(EndAct.editDeck),
      onLeave: () => _run(EndAct.leave),
    );
  }
}
