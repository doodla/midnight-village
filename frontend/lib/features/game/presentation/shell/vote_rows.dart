import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';

import '../../../../design_system/copy/copy.dart';
import '../../../../design_system/feel/haptics.dart';
import '../../../../design_system/layout/space.dart';
import '../../../../design_system/night/night_pick.dart';
import '../../../../design_system/primitives/player_row.dart';
import '../../../../design_system/primitives/screen_frame.dart';
import '../../../../design_system/primitives/vote_slip.dart';
import '../../../../design_system/skin/skin.dart';
import '../../../../design_system/teach/cue_wave.dart';

/// The vote's slips ([VoteSlip]: this phone's own among them, in its seat,
/// never a choice), sized to the room they are given: [PlayerRowSize.grand]
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
    this.you,
    this.accepts = defaultAccepts,
  });

  /// Every tap is taken (a view with no one to decline it).
  static bool defaultAccepts() => true;

  final List<NightSeat> seats;

  /// The practice players among [seats], tagged "Practice".
  final Set<int> practice;

  /// This phone's own player among [seats]: shown, not a choice.
  final int? you;
  final int? pick;
  final bool locked;
  final bool nudge;
  final ValueChanged<int> onPick;

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
      // (Your own slip carries no tag: your seal is in the sigil's place.)
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
    final you = seat.id == widget.you;
    final row = VoteSlip(
      token: seat.token,
      name: seat.name,
      size: size,
      stretch: stretch,
      practice: practice.contains(seat.id),
      you: you,
      picked: mine,
      sealed: locked && mine,
      // Once locked, the others dim; this phone's own pick stays as it is.
      dimmed: locked && !mine,
      onTap: locked || you
          ? null
          : mine
          // The picked slip stays a button (it reads as selected); a tap on
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
      child: row,
    );
  }
}
