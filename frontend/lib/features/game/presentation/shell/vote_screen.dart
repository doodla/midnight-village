import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design_system/copy/copy.dart';
import '../../../../design_system/layout/space.dart';
import '../../../../design_system/night/night_pick.dart';
import '../../../../design_system/primitives/band.dart';
import '../../../../design_system/primitives/fit_line.dart';
import '../../../../design_system/primitives/notice.dart';
import '../../../../design_system/primitives/player_row.dart';
import '../../../../design_system/primitives/primary_button.dart';
import '../../../../design_system/primitives/progress_pips.dart';
import '../../../../design_system/primitives/screen_frame.dart';
import '../../../../design_system/skin/ground.dart';
import '../../../../design_system/skin/skin.dart';
import '../../../../design_system/teach/cue_wave.dart';
import '../../../../design_system/teach/learned_store.dart';
import '../../../../design_system/teach/teach_once.dart';
import '../../data/stage_requests.dart';
import '../../domain/game_me.dart';
import '../protocol_two_game.dart';
import '../stage_seconds.dart';

/// 09 Vote, wired to the server: [VoteView] fed from `/me/` (with this
/// phone's taps on it), the bar and its number from the stage's deadline
/// ([StageSeconds]); a tap on a row is a pick and "Lock in {name}" the lock,
/// both through the game's outbox (one lane, so a lock goes after the picks
/// before it). A restart opens on `/me/`'s own `my_vote`, picked or locked.
/// The first lock the server takes teaches the rows' nudge away. The vote
/// ends on the server (every lock, or its deadline); this screen never
/// decides it.
class VoteScreen extends ConsumerStatefulWidget {
  const VoteScreen({super.key, required this.game, required this.gameId});

  /// The game as the shell has it (`/me/` with this phone's taps on it).
  final ProtocolTwoGame game;
  final String gameId;

  @override
  ConsumerState<VoteScreen> createState() => _VoteScreenState();
}

class _VoteScreenState extends ConsumerState<VoteScreen> {
  final _share = StageShare();

  ProtocolTwoGameNotifier get _notifier =>
      ref.read(protocolTwoGameProvider(widget.gameId).notifier);

  /// The server has this phone's lock: answered (taken, or a 409 that it
  /// was locked already), or `/me/` says so.
  static bool _lockTaken(ProtocolTwoGame game) {
    final item = game.outbox.current(OutboxLane.vote);
    final answered =
        item?.leg == Leg.confirming &&
        item!.request is VoteRequest &&
        (item.request as VoteRequest).lock;
    return answered || (game.server.myVote?.locked ?? false);
  }

  @override
  Widget build(BuildContext context) {
    // The first lock the server takes teaches the rows' nudge away (a lock
    // can wait behind a pick, so it is read from the game, not the tap).
    ref.listen(protocolTwoGameProvider(widget.gameId), (_, next) {
      final game = next.value;
      if (game != null && _lockTaken(game)) {
        ref.read(learnedCuesProvider.notifier).learn(Cue.voteLock);
      }
    });
    final me = widget.game.me;
    return StageSeconds(
      gameId: widget.gameId,
      deadline: me.deadline,
      builder: (context, seconds) => VoteView(
        me: me,
        secondsLeft: seconds,
        remaining: _share.left(me.stage, seconds),
        onPick: (id) => unawaited(_notifier.pickVote(id)),
        onLock: (id) => unawaited(_notifier.lockVote(id)),
        notSent: widget.game.unsent.contains(OutboxLane.vote),
        onTryAgain: () => unawaited(_notifier.retry(OutboxLane.vote)),
      ),
    );
  }
}

/// 09 Vote as drawn (first-time play spec, section 3): the vote's number and
/// its bar on a strip of night; "Who dies today?"; every other player as a
/// row (this phone's own is never listed: the server refuses a vote for
/// yourself), none picked until a tap; the pick lifts and takes the
/// selection's outline, a tap on another row moves it; how many have locked
/// in, as plain pips, never who; then the one amber action, "Lock in
/// {name}", or "Pick a name" while there is no pick. Locking is final, and
/// says so only by the button: "Locked", and every row dims the same, the
/// pick no longer shown. In a first vote the rows nudge once, in a wave.
///
/// It takes plain data and callbacks: [me] is `/me/` with this phone's taps
/// on it (its own [GameMe.myVote]).
class VoteView extends StatelessWidget {
  const VoteView({
    super.key,
    required this.me,
    required this.secondsLeft,
    required this.remaining,
    required this.onPick,
    required this.onLock,
    this.notSent = false,
    this.onTryAgain,
  });

  final GameMe me;

  /// Null: the vote has no deadline (no number, the bar unlit).
  final int? secondsLeft;

  /// How much of the vote is left, 0 to 1.
  final double remaining;

  /// A row tapped: pick that player.
  final ValueChanged<int> onPick;

  /// "Lock in {name}" tapped, with the player picked.
  final ValueChanged<int> onLock;

  /// The last pick or lock got no answer: "Not sent." with [onTryAgain].
  final bool notSent;
  final VoidCallback? onTryAgain;

  /// The most other players shown in the vote's tall rows.
  static const largeRowsUpTo = 6;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final others = [
      for (final seat in me.seats)
        if (seat.id != me.playerId) seat,
    ];
    final vote = me.myVote;
    final locked = vote?.locked ?? false;
    final pick = others.where((s) => s.id == vote?.targetId).firstOrNull;
    final progress = me.progress;
    // Up to six others, the vote's tall rows; more, the table's, so a table
    // of ten shows nearly every name without scrolling.
    final size = others.length > largeRowsUpTo
        ? PlayerRowSize.compact
        : PlayerRowSize.large;
    return ScreenFrame(
      ground: GroundKind.day,
      topSlot: TimerBand.bar(secondsLeft: secondsLeft, remaining: remaining),
      body: TeachOnce(
        cue: Cue.voteLock,
        builder: (context, teaching) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: size == PlayerRowSize.compact ? Space.sm : Space.md,
          children: [
            Semantics(
              header: true,
              child: FitWords(
                VoteCopy.headline,
                style: skin.typography.screenTitle,
              ),
            ),
            for (final (i, seat) in others.indexed)
              CueWave(
                play: teaching && !locked,
                index: i,
                distance: CueWave.rowNudge,
                child: _row(
                  seat,
                  size,
                  picked: !locked && seat == pick,
                  locked: locked,
                ),
              ),
          ],
        ),
      ),
      actions: [
        if (notSent && onTryAgain != null)
          Notice(
            message: BannerCopy.notSent,
            action: BannerCopy.tryAgain,
            onAction: onTryAgain,
          ),
        if (progress != null)
          ProgressPips(
            done: progress.done,
            total: progress.needed,
            label: VoteCopy.progress.fill({
              'd': progress.done,
              'n': progress.needed,
            }),
          ),
        if (locked)
          const PrimaryButton.done(label: VoteCopy.locked)
        else if (pick == null)
          const PrimaryButton(label: VoteCopy.pickName, onPressed: null)
        else
          PrimaryButton(
            label: VoteCopy.lockIn.fill({'name': pick.name}),
            icon: Icons.lock_outline,
            onPressed: () => onLock(pick.id),
          ),
      ],
    );
  }

  Widget _row(
    NightSeat seat,
    PlayerRowSize size, {
    required bool picked,
    required bool locked,
  }) => PlayerRow(
    token: seat.token,
    name: seat.name,
    size: size,
    picked: picked,
    dimmed: locked,
    // The picked row stays a button (it reads as selected); a tap on it
    // changes nothing.
    onTap: locked ? null : (picked ? () {} : () => onPick(seat.id)),
  );
}
