import 'dart:math' as math;
import 'dart:ui';

import '../../../design_system/layout/space.dart' show Motion;
import 'end_board_cards.dart';

// The reveal of the end board (docs/specs/frontend/end-board.md, section 8),
// as a timeline: from the board's plan to named beats, each with its start and
// its length, all from the motion tokens. Pure: the board's widgets read one
// clock and ask this where each piece is. Nothing here waits; the whole of it
// is skipped by a tap.
//
// The cards never change places: from the first frame each card lies face
// down in the slot the plan gives it, every one at the losers' size, and a
// card only ever moves out of its slot and back (the hanged) or grows where
// it lies (the winners).

/// What moves in a beat.
enum RevealBeat {
  /// Nothing moves: the face-down board is read.
  hold,

  /// The board scrolls to the hanged (a board taller than its window).
  scroll,

  /// The cards that are not hanged dim.
  dim,

  /// A hanged card leaves its slot for the middle of the window, big.
  lift,

  /// A card turns face up where it is (a hanged card on its way).
  turn,

  /// HANGED slams onto the hanged cards; the knock as it lands.
  stamp,

  /// The banner unrolls, its sentence whole.
  banner,

  /// The hanged go back to their slots; the stamp lifts off; the dim lifts.
  drop,

  /// The black ribbon is pinned on the hanged.
  ribbon,

  /// The three middle cards turn (with the last row).
  middle,

  /// The Hunter's twine and slip, and the ribbon on the one he took.
  pick,

  /// The winners grow to their size; the dealt cards come out behind.
  grow,

  /// The lantern's pool comes on.
  pool,

  /// The tags arrive on their twine.
  tags,
}

/// One beat: [kind] from [start] for [length]; about one card ([card]) or one
/// row ([row]) when it says so.
class RevealSpan {
  const RevealSpan(this.kind, this.start, this.length, {this.card, this.row});

  final RevealBeat kind;
  final Duration start;
  final Duration length;
  final int? card;
  final int? row;

  Duration get end => start + length;

  /// How far along it is at [t]: 0 before, 1 after, linear between.
  double at(Duration t) {
    if (t <= start) return 0;
    if (t >= end || length == Duration.zero) return 1;
    return (t - start).inMicroseconds / length.inMicroseconds;
  }

  @override
  String toString() =>
      '${kind.name}${card == null ? '' : ' #$card'}'
      '${row == null ? '' : ' row $row'} '
      '${start.inMilliseconds}+${length.inMilliseconds}';
}

/// The sizes the reveal adds to the board's: how big the hanged are in the
/// middle of the window.
abstract final class RevealMetrics {
  /// One hanged card is at most this share of the window's width ...
  static const bigWidthShare = 0.62;

  /// ... and of its height.
  static const bigHeightShare = 0.7;

  /// Clear of the window's sides.
  static const bigMargin = 24.0;

  /// Between hanged cards side by side.
  static const bigGap = 12.0;
}

/// The whole reveal of one board.
class EndReveal {
  const EndReveal({
    required this.spans,
    required this.total,
    required this.knockAt,
    required this.thud,
    required this.scrollFrom,
    required this.scrollTo,
    required this.big,
    required this.startScale,
  });

  final List<RevealSpan> spans;

  /// When the last beat ends: the board is settled.
  final Duration total;

  /// The reveal's one vibration: as HANGED lands ([thud]), or as the banner
  /// unrolls when nobody is hanged (a light one).
  final Duration knockAt;
  final bool thud;

  /// Where the board stands scrolled at the start and from the [RevealBeat.scroll]
  /// beat on (the settled board's [EndBoardPlan.initialScroll]).
  final double scrollFrom;
  final double scrollTo;

  /// Where each hanged card is at its biggest, in the board's coordinates
  /// (untilted), by player id.
  final Map<int, Rect> big;

  /// Each card's size at the start, a share of its own: every card at one
  /// size, face down. By player id.
  final Map<int, double> startScale;

  /// The beats of [kind] (about [card] or [row] when given).
  Iterable<RevealSpan> all(RevealBeat kind, {int? card, int? row}) =>
      spans.where(
        (s) =>
            s.kind == kind &&
            (card == null || s.card == card) &&
            (row == null || s.row == row),
      );

  /// The one beat of [kind], or null when there is none.
  RevealSpan? of(RevealBeat kind, {int? card, int? row}) =>
      all(kind, card: card, row: row).firstOrNull;

  /// How far [kind] is at [t] (1 when there is no such beat: it is done).
  double at(RevealBeat kind, Duration t, {int? card, int? row}) =>
      of(kind, card: card, row: row)?.at(t) ?? 1;

  /// The turn of the card [id].
  RevealSpan turnOf(int id) => of(RevealBeat.turn, card: id)!;

  bool get anyHanged => big.isNotEmpty;
}

/// The reveal of [plan].
EndReveal revealOf(EndBoardPlan plan) {
  final spans = <RevealSpan>[];
  // The vote's dead (a card's `hanged` is any death; the Hunter's pick is
  // told after, on its twine).
  final hanged = [
    for (final c in plan.cards)
      if (c.hanged && !c.pickedByHunter) c,
  ];
  final scrollTo = plan.scrolls ? plan.initialScroll : 0.0;

  // The held beat: the face-down board, read. Short: the vote has just been
  // seen, and the stamp is the moment.
  const hold = RevealSpan(RevealBeat.hold, Duration.zero, Motion.reveal);
  spans.add(hold);
  if (scrollTo > 0) {
    spans.add(
      RevealSpan(RevealBeat.scroll, hold.end - Motion.settle, Motion.settle),
    );
  }

  var turnsFrom = hold.end;
  Duration? knockAt;
  var settledFrom = hold.end;
  if (hanged.isNotEmpty) {
    spans.add(RevealSpan(RevealBeat.dim, hold.end, Motion.quick));
    for (final c in hanged) {
      spans
        ..add(RevealSpan(RevealBeat.lift, hold.end, Motion.settle, card: c.id))
        // It turns on the way, and lands face up as it arrives.
        ..add(
          RevealSpan(
            RevealBeat.turn,
            hold.end + Motion.settle - Motion.quick,
            Motion.quick,
            card: c.id,
          ),
        );
    }
    // The face is seen whole for a moment, then the stamp slams.
    final stamp = RevealSpan(
      RevealBeat.stamp,
      hold.end + Motion.settle + Motion.quick,
      Motion.press,
    );
    knockAt = stamp.end;
    spans
      ..add(stamp)
      ..add(RevealSpan(RevealBeat.banner, stamp.start, Motion.settle));
    final drop = RevealSpan(
      RevealBeat.drop,
      stamp.end + Motion.reveal,
      Motion.settle,
    );
    spans.add(drop);
    for (final c in hanged) {
      spans.add(
        RevealSpan(RevealBeat.ribbon, drop.end, Motion.press, card: c.id),
      );
    }
    turnsFrom = drop.start;
    settledFrom = drop.end + Motion.press;
  }

  // Row by row, every card not yet face up turns where it lies; the middle
  // cards with the last row.
  final hangedIds = {for (final c in hanged) c.id};
  final turningRows = plan.rows
      .where((row) => row.any((i) => !hangedIds.contains(plan.cards[i].id)))
      .length;
  // A tall board (long names, a row each) closes its rows up: the cascade is
  // never longer than five rows' worth.
  final stagger = turningRows <= _cascadeRows
      ? Motion.stagger
      : Motion.stagger * ((_cascadeRows - 1) / (turningRows - 1));
  var k = 0;
  RevealSpan? lastTurn;
  for (final (r, row) in plan.rows.indexed) {
    final turning = [
      for (final i in row)
        if (!hangedIds.contains(plan.cards[i].id)) plan.cards[i],
    ];
    if (turning.isEmpty) continue;
    final start = turnsFrom + stagger * k++;
    for (final c in turning) {
      lastTurn = RevealSpan(
        RevealBeat.turn,
        start,
        Motion.quick,
        card: c.id,
        row: r,
      );
      spans.add(lastTurn);
    }
  }
  final middleAt = lastTurn?.start ?? turnsFrom;
  spans.add(RevealSpan(RevealBeat.middle, middleAt, Motion.quick));
  final turnsEnd = middleAt + Motion.quick;
  if (turnsEnd > settledFrom) settledFrom = turnsEnd;

  // The Hunter's picks, one after the other, each once its two cards are up.
  var pickFrom = settledFrom;
  for (final p in plan.picks) {
    final start = _latest([
      pickFrom,
      for (final s in spans)
        if (s.kind == RevealBeat.turn && s.card == p.pickId) s.end,
    ]);
    final pick = RevealSpan(
      RevealBeat.pick,
      start,
      Motion.settle,
      card: p.pickId,
    );
    spans.add(pick);
    pickFrom = pick.end;
  }

  // The board settles: the winners grow, the pool comes on, the tags arrive.
  spans
    ..add(RevealSpan(RevealBeat.grow, settledFrom, Motion.settle))
    ..add(RevealSpan(RevealBeat.pool, settledFrom, Motion.settle))
    ..add(RevealSpan(RevealBeat.tags, settledFrom, Motion.settle));
  if (hanged.isEmpty) {
    // Nobody hanged: the banner unrolls as the tags tie on, with the light
    // knock.
    spans.add(RevealSpan(RevealBeat.banner, settledFrom, Motion.settle));
    knockAt = settledFrom;
  }

  final least = plan.cards
      .map((c) => c.portraitWidth)
      .fold(double.infinity, math.min);
  return EndReveal(
    spans: spans,
    total: _latest([for (final s in spans) s.end]),
    knockAt: knockAt!,
    thud: hanged.isNotEmpty,
    scrollFrom: 0,
    scrollTo: scrollTo,
    big: _bigOf(plan, hanged, scrollTo),
    startScale: {
      for (final c in plan.cards) c.id: math.min(1, least / c.portraitWidth),
    },
  );
}

/// The most rows the cascade of turns gives a full [Motion.stagger] each.
const _cascadeRows = 5;

Duration _latest(Iterable<Duration> times) =>
    times.fold(Duration.zero, (a, b) => b > a ? b : a);

/// The hanged side by side in the middle of the window (as it stands
/// scrolled to [scroll]), as big as fits; never smaller than they are.
Map<int, Rect> _bigOf(EndBoardPlan plan, List<EndCard> hanged, double scroll) {
  if (hanged.isEmpty) return const {};
  final room = Rect.fromLTWH(
    0,
    scroll,
    plan.boardWidth,
    plan.seenAtTop,
  ).deflate(RevealMetrics.bigMargin);
  final widths = hanged.fold(0.0, (a, c) => a + c.rect.width);
  final widest = hanged.map((c) => c.rect.width).fold(0.0, math.max);
  final tallest = hanged.map((c) => c.rect.height).fold(0.0, math.max);
  final gaps = RevealMetrics.bigGap * (hanged.length - 1);
  final scale = math.max(
    1.0,
    [
      RevealMetrics.bigWidthShare * room.width / widest,
      (room.width - gaps) / widths,
      RevealMetrics.bigHeightShare * room.height / tallest,
    ].reduce(math.min),
  );
  final across = widths * scale + gaps;
  var x = room.center.dx - across / 2;
  return {
    for (final c in hanged)
      c.id: () {
        final r = Rect.fromLTWH(
          x,
          room.center.dy - c.rect.height * scale / 2,
          c.rect.width * scale,
          c.rect.height * scale,
        );
        x += r.width + RevealMetrics.bigGap;
        return r;
      }(),
  };
}
