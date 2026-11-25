import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design_system/copy/copy.dart';
import '../../../../design_system/feel/haptics.dart';
import '../../../../design_system/layout/space.dart';
import '../../../../design_system/night/night_pick.dart';
import '../../../../design_system/primitives/fit_line.dart';
import '../../../../design_system/primitives/notice.dart';
import '../../../../design_system/primitives/primary_button.dart';
import '../../../../design_system/primitives/screen_frame.dart';
import '../../../../design_system/primitives/sliced_art.dart';
import '../../../../design_system/primitives/square_foot.dart';
import '../../../../design_system/primitives/square_sky.dart';
import '../../../../design_system/skin/dress.dart';
import '../../../../design_system/skin/ground.dart';
import '../../../../design_system/skin/skin.dart';
import '../../../../design_system/teach/learned_store.dart';
import '../../../../design_system/teach/teach_once.dart';
import '../../data/stage_requests.dart';
import '../../domain/game_me.dart';
import '../live_game.dart';
import '../stage_seconds.dart';
import 'vote_rows.dart';

export 'vote_rows.dart';

/// 09 Vote, wired to the server: [VoteView] fed from `/me/` (with this
/// phone's taps on it), the clock counting to the stage's deadline
/// ([stageCountdown]: a second going by redraws the clock alone); a tap on a slip is a pick and "Lock in
/// {name}" the lock, both through the game's outbox (one lane, so a lock
/// goes after the picks before it). A restart opens on `/me/`'s own
/// `my_vote`, picked or locked. The first lock the server takes teaches the
/// slips' nudge away. The vote ends on the server (every lock, or its
/// deadline); this screen never decides it.
class VoteScreen extends ConsumerStatefulWidget {
  const VoteScreen({super.key, required this.game, required this.gameId});

  /// The game as the shell has it (`/me/` with this phone's taps on it).
  final LiveGame game;
  final String gameId;

  @override
  ConsumerState<VoteScreen> createState() => _VoteScreenState();
}

class _VoteScreenState extends ConsumerState<VoteScreen> {
  LiveGameNotifier get _notifier =>
      ref.read(liveGameProvider(widget.gameId).notifier);

  /// The server has this phone's lock: answered (taken, or a 409 that it
  /// was locked already), or `/me/` says so.
  static bool _lockTaken(LiveGame game) {
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
    ref.listen(liveGameProvider(widget.gameId), (_, next) {
      final game = next.value;
      if (game != null && _lockTaken(game)) {
        ref.read(learnedCuesProvider.notifier).learn(Cue.voteLock);
      }
    });
    final me = widget.game.me;
    return VoteView(
      me: me,
      clock: stageCountdown(_notifier, deadline: me.deadline),
      onPick: (id) => unawaited(_notifier.pickVote(id)),
      onLock: (id) => unawaited(_notifier.lockVote(id)),
      accepts: () => _notifier.voteDeclined == null,
      notSent: widget.game.unsent.contains(OutboxLane.vote),
      onTryAgain: () => unawaited(_notifier.retry(OutboxLane.vote)),
    );
  }
}

/// 09 Vote under the square's sky (Shadow paper; the first-time play spec,
/// 09): the vote's clock in 08's strip of night sky with the wall lantern;
/// on the board, "Who dies today?" and every player as a slip of paper in
/// seat order ([VoteRows], [VoteSlip]): those this phone may vote for are
/// buttons, its own is never listed.
/// None is picked until a tap; the pick lifts and wears the paper mark, a tap
/// on another moves it. On the cobbles the one plaque: "Pick a name" in the
/// kit's locked form while there is no pick (a tap nudges the slips),
/// "Lock in {name}" in amber, then "Locked"; under its words how many have
/// locked in (this phone's own lock counted at once), never who. Locking is
/// final: the pick turns dried-blood red with a seal stamped on its sigil
/// (owner, 22 November 2026: "red row and seal") and the other slips dim
/// (owner, 20 November 2026: a neighbour could read "Lock in Cleo" already;
/// a lock seen across the table is the point of the stamp). In a first vote
/// the slips nudge once, in a wave. The pick ticks and the lock knocks
/// ([OpenDay]: the vote is the day's, whatever its sky).
///
/// It takes plain data and callbacks: [me] is `/me/` with this phone's taps
/// on it (its own [GameMe.myVote]).
class VoteView extends StatefulWidget {
  const VoteView({
    super.key,
    required this.me,
    required this.clock,
    required this.onPick,
    required this.onLock,
    this.accepts = VoteRows.defaultAccepts,
    this.notSent = false,
    this.onTryAgain,
  });

  final GameMe me;

  /// What the clock counts down; null: the vote has no deadline (no number).
  final Countdown? clock;

  /// A slip tapped: pick that player.
  final ValueChanged<int> onPick;

  /// "Lock in {name}" tapped, with the player picked.
  final ValueChanged<int> onLock;

  /// Whether a tap would be taken now (the vote is on and not locked): a
  /// declined tap makes no tick and no knock.
  final bool Function() accepts;

  /// The last pick or lock got no answer: "Not sent." with [onTryAgain].
  final bool notSent;
  final VoidCallback? onTryAgain;

  /// The players this phone may vote for: exactly `/me/`'s `vote_targets`
  /// (the server sends it in every vote), in seat order. The phone holds no
  /// rule of its own.
  static List<NightSeat> votable(GameMe me) {
    final targets = me.voteTargets ?? const <int>[];
    return [
      for (final seat in me.seats)
        if (targets.contains(seat.id)) seat,
    ];
  }

  @override
  State<VoteView> createState() => _VoteViewState();
}

class _VoteViewState extends State<VoteView> {
  /// A tap on "Pick a name" nudges the slips again.
  final _replay = CueReplay();

  @override
  void dispose() {
    _replay.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final me = widget.me;
    final others = VoteView.votable(me);
    final vote = me.myVote;
    final locked = vote?.locked ?? false;
    final pick = others.where((s) => s.id == vote?.targetId).firstOrNull;
    final progress = me.progress;
    final count = progress == null
        ? null
        : VoteCopy.progress.fill({'d': progress.done, 'n': progress.needed});
    final type = context.skin.typography;
    return OpenDay(
      child: ScreenFrame(
        ground: GroundKind.night,
        dress: Dress.paper,
        bleed: true,
        topSlot: SquareSky(
          countdown: widget.clock,
          title: VoteCopy.headline,
          clock: SkyClock.vote,
        ),
        fitsHeight: true,
        minBodyHeight: context.skin.parts.squareLeastBody,
        body: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Expanded(
              child: BoardFrame(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    const SizedBox(height: Space.md),
                    // Drawn for the eye; the sky speaks it, once.
                    ExcludeSemantics(
                      child: FitWords(
                        VoteCopy.headline,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        style: type.screenTitle.copyWith(
                          color: context.ground.text,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Padding(
                        padding: const EdgeInsets.fromLTRB(
                          Space.md,
                          Space.xs,
                          Space.md,
                          Space.md,
                        ),
                        child: TeachOnce(
                          cue: Cue.voteLock,
                          replay: _replay,
                          builder: (context, teaching) => VoteRows(
                            seats: VoteView.votable(me),
                            practice: me.practiceIds,
                            pick: pick?.id,
                            locked: locked,
                            nudge: teaching && !locked,
                            onPick: widget.onPick,
                            accepts: widget.accepts,
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
            SquareFoot(
              notice: widget.notSent && widget.onTryAgain != null
                  ? Notice(
                      message: BannerCopy.notSent,
                      action: BannerCopy.tryAgain,
                      onAction: widget.onTryAgain,
                    )
                  : null,
              action: _plaque(count, pick, locked),
            ),
          ],
        ),
      ),
    );
  }

  /// The one plaque: what unlocks it, the lock, or that it is locked.
  Widget _plaque(String? count, NightSeat? pick, bool locked) {
    if (locked) {
      return PrimaryButton.done(label: VoteCopy.locked, detail: count);
    }
    if (pick == null) {
      return PrimaryButton.locked(
        label: VoteCopy.pickName,
        detail: count,
        onLockedTap: _replay.replay,
      );
    }
    // Under the frame (and [OpenDay]), where a knock is allowed.
    return Builder(
      builder: (context) => PrimaryButton(
        label: VoteCopy.lockIn.fill({'name': pick.name}),
        icon: Icons.lock_outline,
        detail: count,
        onPressed: () {
          // A light knock on the tap, not on the answer, and none for a tap
          // the phone declines.
          if (widget.accepts()) Haptics.light(context);
          widget.onLock(pick.id);
        },
      ),
    );
  }
}
