import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design_system/copy/copy.dart';
import '../../../../design_system/layout/space.dart';
import '../../../../design_system/night/night_pick.dart';
import '../../../../design_system/primitives/band.dart';
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
import '../live_game.dart';
import '../stage_seconds.dart';

/// 09 Vote, wired to the server: [VoteView] fed from `/me/` (with this
/// phone's taps on it), the bar and its number from the stage's deadline
/// ([StageSeconds], [StageShare]); a tap on a row is a pick and "Lock in
/// {name}" the lock, both through the game's outbox (one lane, so a lock
/// goes after the picks before it). A restart opens on `/me/`'s own
/// `my_vote`, picked or locked. The first lock the server takes teaches the
/// rows' nudge away. The vote ends on the server (every lock, or its
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
    return StageSeconds(
      gameId: widget.gameId,
      deadline: me.deadline,
      builder: (context, seconds) => VoteView(
        me: me,
        secondsLeft: seconds,
        remaining: StageShare.left(
          startedAt: me.stageStartedAt,
          deadline: me.deadline,
          secondsLeft: seconds,
        ),
        onPick: (id) => unawaited(_notifier.pickVote(id)),
        onLock: (id) => unawaited(_notifier.lockVote(id)),
        notSent: widget.game.unsent.contains(OutboxLane.vote),
        onTryAgain: () => unawaited(_notifier.retry(OutboxLane.vote)),
      ),
    );
  }
}

/// 09 Vote as drawn (first-time play spec, section 3): the vote's number and
/// "Who dies today?" on a strip of night, its bar along the foot; the
/// players this phone may vote for as rows, none picked until a tap; the
/// pick lifts and takes the selection's outline, a tap on another row moves
/// it; how many have locked in, as plain pips (this phone's own lock
/// counted at once), never who; then the one amber action, "Lock in
/// {name}", or "Pick a name" while there is no pick. Locking is final and
/// says so only by the button, "Locked": the pick stays lifted and outlined
/// and the other rows dim (owner, 20 November 2026: a neighbour could read
/// "Lock in Cleo" already; hiding it only costs the player the sight of
/// their own choice). In a first vote the rows nudge once, in a wave.
///
/// The rows are sized to the room ([VoteRows]): the vote's tall rows when
/// they all fit, the table's compact ones when only those do, and the
/// compact ones scrolling, with the fade below them, where nothing fits.
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

  /// How much of the vote is left, 0 to 1; null when the server does not
  /// say when it started (the bar unlit).
  final double? remaining;

  /// A row tapped: pick that player.
  final ValueChanged<int> onPick;

  /// "Lock in {name}" tapped, with the player picked.
  final ValueChanged<int> onLock;

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
  Widget build(BuildContext context) {
    final others = votable(me);
    final vote = me.myVote;
    final locked = vote?.locked ?? false;
    final pick = others.where((s) => s.id == vote?.targetId).firstOrNull;
    final progress = me.progress;
    return ScreenFrame(
      ground: GroundKind.day,
      fitsHeight: true,
      topSlot: TimerBand.bar(
        secondsLeft: secondsLeft,
        remaining: remaining,
        title: VoteCopy.headline,
      ),
      body: TeachOnce(
        cue: Cue.voteLock,
        builder: (context, teaching) => VoteRows(
          seats: others,
          practice: me.practiceIds,
          pick: pick?.id,
          locked: locked,
          nudge: teaching && !locked,
          onPick: onPick,
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
}

/// The vote's rows, sized to the room they are given: [PlayerRowSize.large]
/// with [Space.md] between when every row fits, else
/// [PlayerRowSize.compact] with [Space.sm], else the compact rows scrolling
/// ([FadingScroll]). Each row's height is measured from its name at the
/// text size (a name wraps to two lines before it is set smaller). A
/// lifted row keeps its place in the column, so the gaps stay even.
class VoteRows extends StatelessWidget {
  const VoteRows({
    super.key,
    required this.seats,
    required this.pick,
    required this.locked,
    required this.nudge,
    required this.onPick,
    this.practice = const {},
  });

  final List<NightSeat> seats;

  /// The practice players among [seats], tagged "Practice".
  final Set<int> practice;
  final int? pick;
  final bool locked;
  final bool nudge;
  final ValueChanged<int> onPick;

  /// Every size, tallest first, with the gap it is set at.
  static const sizes = [
    (PlayerRowSize.large, Space.md),
    (PlayerRowSize.compact, Space.sm),
  ];

  /// The height [seats] take at [size] with [gap] between, [width] wide.
  static double heightOf(
    BuildContext context,
    List<NightSeat> seats,
    PlayerRowSize size,
    double gap,
    double width, {
    Set<int> practice = const {},
  }) {
    final skin = context.skin;
    final scaler = MediaQuery.textScalerOf(context);
    final style = size.nameStyle(skin.typography);
    final nameRoom =
        width - Space.sm - size.token.size - size.gap - size.endPadding;
    var total = 0.0;
    for (final seat in seats) {
      // A practice player's tag goes beside the name or under it: measured
      // as one more word in the name's face (wider than the tag's own).
      final tagged = practice.contains(seat.id);
      final painter = TextPainter(
        text: TextSpan(
          text: tagged ? '${seat.name} ${TableCopy.practice}' : seat.name,
          style: style,
        ),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
        maxLines: tagged ? 3 : 2,
      )..layout(maxWidth: math.max(1, nameRoom));
      final content = math.max(size.token.size, painter.height);
      painter.dispose();
      total += math.max(size.height, content + 2 * Space.xxs) + _lift;
    }
    return total + (gap - _lift) * math.max(0, seats.length - 1);
  }

  /// The room each row keeps for the lift (above when lifted, else below),
  /// so the gaps between the papers stay even; it is taken out of the gap,
  /// so the papers are still [sizes]' gap apart.
  static const _lift = Space.xs;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, room) {
      double height(PlayerRowSize size, double gap) => heightOf(
        context,
        seats,
        size,
        gap,
        room.maxWidth,
        practice: practice,
      );
      final (size, gap) = sizes.firstWhere(
        (s) => height(s.$1, s.$2) <= room.maxHeight,
        orElse: () => sizes.last,
      );
      final fits = height(size, gap) <= room.maxHeight;
      final column = Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: gap - _lift,
        children: [
          for (final (i, seat) in seats.indexed)
            CueWave(
              play: nudge,
              index: i,
              distance: CueWave.rowNudge,
              child: _row(seat, size),
            ),
        ],
      );
      return Align(
        alignment: Alignment.topCenter,
        child: fits ? column : FadingScroll(child: column),
      );
    },
  );

  Widget _row(NightSeat seat, PlayerRowSize size) {
    final mine = seat.id == pick;
    final lifted = mine;
    final row = PlayerRow(
      token: seat.token,
      name: seat.name,
      size: size,
      practice: practice.contains(seat.id),
      picked: lifted,
      // Once locked, the others dim; this phone's own pick stays as it is.
      dimmed: locked && !mine,
      onTap: locked
          ? null
          : mine
          // The picked row stays a button (it reads as selected); a tap on
          // it changes nothing.
          ? () {}
          : () => onPick(seat.id),
    );
    return AnimatedPadding(
      duration: Motion.quick,
      curve: Motion.curve,
      // The lift draws the row up by the same room it keeps above.
      padding: EdgeInsets.only(
        top: lifted ? _lift : 0,
        bottom: lifted ? 0 : _lift,
      ),
      child: locked && mine ? Semantics(selected: true, child: row) : row,
    );
  }
}
