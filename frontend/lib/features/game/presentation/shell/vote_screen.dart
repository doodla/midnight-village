import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design_system/copy/copy.dart';
import '../../../../design_system/feel/haptics.dart';
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
        accepts: () => _notifier.voteDeclined == null,
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
/// {name}", or "Pick a name" while there is no pick. Locking is final: the button
/// says "Locked", the pick stays lifted and outlined with a seal stamped on
/// its token ([LockedFill.bloodFill] also turns its paper dried-blood red),
/// and the other rows dim (owner, 20 November 2026: a neighbour could read
/// "Lock in Cleo" already; hiding it only costs the player the sight of
/// their own choice; a lock that is seen across the table is the point of
/// the stamp). In a first vote the rows nudge once, in a wave.
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
    this.accepts = VoteRows.defaultAccepts,
    this.lockedFill = LockedFill.standard,
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

  /// Whether a tap would be taken now (the vote is on and not locked): a
  /// declined tap makes no tick and no knock.
  final bool Function() accepts;

  /// What the lock does to the pick's row (the owner's choice).
  final LockedFill lockedFill;

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
          lockedFill: lockedFill,
          accepts: accepts,
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
          // Under the frame's ground (the day's), where a knock is allowed.
          Builder(
            builder: (context) => PrimaryButton(
              label: VoteCopy.lockIn.fill({'name': pick.name}),
              icon: Icons.lock_outline,
              onPressed: () {
                // A light knock on the tap, not on the answer, and none for
                // a tap the phone declines.
                if (accepts()) Haptics.light(context);
                onLock(pick.id);
              },
            ),
          ),
      ],
    );
  }
}

/// The vote's rows, sized to the room they are given: [PlayerRowSize.grand]
/// or [PlayerRowSize.large] with [Space.md] between when every row fits,
/// else [PlayerRowSize.compact] with [Space.sm], else the compact rows
/// scrolling ([FadingScroll]). Each row's height is measured from its name at
/// the text size (a name wraps to two lines before it is set smaller). A
/// lifted row keeps its place in the column, so the gaps stay even.
///
/// What room is left is shared between the rows by one rule: a row grows by
/// at most [maxStretch] of its size's height and never past [maxRowHeight];
/// the rest of the room stays above and below the rows, which stand in the
/// middle of it, so two rows are never two slabs.
class VoteRows extends StatefulWidget {
  const VoteRows({
    super.key,
    required this.seats,
    required this.pick,
    required this.locked,
    required this.nudge,
    required this.onPick,
    this.practice = const {},
    this.lockedFill = LockedFill.standard,
    this.accepts = defaultAccepts,
  });

  /// Every tap is taken (a view with no one to decline it).
  static bool defaultAccepts() => true;

  final List<NightSeat> seats;

  /// The practice players among [seats], tagged "Practice".
  final Set<int> practice;
  final int? pick;
  final bool locked;
  final bool nudge;
  final ValueChanged<int> onPick;

  /// What the lock does to the pick's row.
  final LockedFill lockedFill;

  /// Whether a tap would be taken now; a declined tap ticks nothing.
  final bool Function() accepts;

  /// Every size, tallest first, with the gap it is set at.
  static const sizes = [
    (PlayerRowSize.grand, Space.md),
    (PlayerRowSize.large, Space.md),
    (PlayerRowSize.compact, Space.sm),
  ];

  /// How many names have been measured, ever (a test reads it: the screen's
  /// timer must not make the rows measure their names again).
  @visibleForTesting
  static var measured = 0;

  /// The height [seats] take at [size] with [gap] between, [width] wide.
  static double heightOf(
    BuildContext context,
    List<NightSeat> seats,
    PlayerRowSize size,
    double gap,
    double width, {
    Set<int> practice = const {},
    double stretch = 0,
  }) {
    final skin = context.skin;
    final scaler = MediaQuery.textScalerOf(context);
    final style = size.nameStyle(skin.typography);
    final nameRoom =
        width - Space.sm - size.token.size - size.gap - size.endPadding;
    var total = 0.0;
    for (final seat in seats) {
      // A practice player's tag sits on the name's line: measured as one
      // more word in the name's face (wider than the tag's own).
      final tagged = practice.contains(seat.id);
      measured++;
      final painter = TextPainter(
        text: TextSpan(
          text: tagged ? '${seat.name} ${TableCopy.practice}' : seat.name,
          style: style,
        ),
        textDirection: TextDirection.ltr,
        textScaler: scaler,
        maxLines: 2,
      )..layout(maxWidth: math.max(1, nameRoom));
      final content = math.max(size.token.size, painter.height);
      painter.dispose();
      total += math.max(size.height + stretch, content + 2 * Space.xxs) + _lift;
    }
    return total + (gap - _lift) * math.max(0, seats.length - 1);
  }

  /// The room each row keeps above it for the lift, lifted or not, so the
  /// gaps between the papers stay even; it is taken out of the gap, so the
  /// papers are still [sizes]' gap apart.
  static const _lift = Space.xs;

  /// The most a row grows to fill the room, as a share of its own size's
  /// height.
  static const maxStretch = 0.3;

  /// The tallest a row is made to stand: [PlayerRowSize.grand] 88 and a
  /// little.
  static const maxRowHeight = 96.0;

  @override
  State<VoteRows> createState() => _VoteRowsState();
}

/// How [VoteRows] lays its rows out.
typedef _Layout = ({PlayerRowSize size, double gap, bool fits, double stretch});

class _VoteRowsState extends State<VoteRows> {
  /// What [_layout] was measured for: the names (and who is practice), the
  /// room and the text scale. The screen rebuilds every second for its
  /// timer; the names are measured again only when one of these changes.
  (List<String>, Set<int>, Size, TextScaler)? _measured;
  late _Layout _layout;

  _Layout _layoutFor(BuildContext context, Size room) {
    final seats = widget.seats;
    final practice = widget.practice;
    final key = (
      [for (final seat in seats) seat.name],
      {...practice},
      room,
      MediaQuery.textScalerOf(context),
    );
    final last = _measured;
    if (last != null &&
        listEquals(last.$1, key.$1) &&
        setEquals(last.$2, key.$2) &&
        last.$3 == key.$3 &&
        last.$4 == key.$4) {
      return _layout;
    }
    double height(PlayerRowSize size, double gap, [double stretch = 0]) =>
        VoteRows.heightOf(
          context,
          seats,
          size,
          gap,
          room.width,
          practice: practice,
          stretch: stretch,
        );
    final (size, gap) = VoteRows.sizes.firstWhere(
      (s) => height(s.$1, s.$2) <= room.height,
      orElse: () => VoteRows.sizes.last,
    );
    final fits = height(size, gap) <= room.height;
    // What the room still holds is shared out between the rows, so a table
    // of few fills the screen instead of leaving the foot empty.
    final spare = room.height - height(size, gap);
    var stretch = !fits || seats.isEmpty
        ? 0.0
        : math.max(
            0.0,
            math.min(
              spare / seats.length,
              math.min(
                size.height * VoteRows.maxStretch,
                VoteRows.maxRowHeight - size.height,
              ),
            ),
          );
    // A row whose name wraps is already taller than its size: take back
    // what that leaves too little room for.
    while (stretch > 0 && height(size, gap, stretch) > room.height) {
      stretch = math.max(0, stretch - 2);
    }
    _measured = key;
    return _layout = (size: size, gap: gap, fits: fits, stretch: stretch);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, room) {
      final (:size, :gap, :fits, :stretch) = _layoutFor(context, room.biggest);
      final column = Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: gap - VoteRows._lift,
        children: [
          for (final (i, seat) in widget.seats.indexed)
            CueWave(
              play: widget.nudge,
              index: i,
              distance: CueWave.rowNudge,
              child: _row(context, seat, size, stretch),
            ),
        ],
      );
      return Align(
        alignment: fits ? Alignment.center : Alignment.topCenter,
        child: fits ? column : FadingScroll(child: column),
      );
    },
  );

  Widget _row(
    BuildContext context,
    NightSeat seat,
    PlayerRowSize size,
    double stretch,
  ) {
    final (pick, locked, practice) = (
      widget.pick,
      widget.locked,
      widget.practice,
    );
    final mine = seat.id == pick;
    final lifted = mine;
    final row = PlayerRow(
      token: seat.token,
      name: seat.name,
      size: size,
      stretch: stretch,
      practice: practice.contains(seat.id),
      picked: lifted,
      sealed: locked && mine,
      lockedFill: widget.lockedFill,
      // Once locked, the others dim; this phone's own pick stays as it is.
      dimmed: locked && !mine,
      onTap: locked
          ? null
          : mine
          // The picked row stays a button (it reads as selected); a tap on
          // it changes nothing.
          ? () {}
          : () {
              // A tick each time the pick moves; none for a tap the phone
              // declines.
              if (widget.accepts()) Haptics.tick(context);
              widget.onPick(seat.id);
            },
    );
    // The room a lift needs sits above every row (lifted or not), so the
    // gaps stay even and a pick rises into it ([PlayerRow] moves the paper).
    return Padding(
      padding: const EdgeInsets.only(top: VoteRows._lift),
      // Always wrapped, so the row keeps its state (and its colour tween and
      // its stamp) when the lock arrives.
      child: Semantics(selected: locked && mine ? true : null, child: row),
    );
  }
}
