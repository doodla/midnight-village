import 'dart:math' as math;
import 'dart:ui';

import '../../../design_system/layout/space.dart' show Motion;
import 'end_board_cards.dart';
import 'end_board_metrics.dart';

// The reveal of the end board (docs/specs/frontend/end-board.md, section 8),
// as a timeline: from the board's plan to named beats, each with its start and
// its length, all from the motion tokens. Pure: the board's widgets read one
// clock and ask this where each piece is. Nothing here waits; the whole of it
// is skipped by a tap.
//
// The cards never change places: from the first frame each card lies face
// down in the slot the plan gives it (the board already scrolled where the
// settled board opens), every back with one portrait size ([EndReveal.backs]),
// and a card only ever moves out of its slot and back (the dead, one beat
// each) or rises where it lies (the winners, when nobody is hanged). Nothing
// is ever drawn smaller than it is: a back grows into its face as it turns.

/// What moves in a beat.
enum RevealBeat {
  /// Nothing moves: the face-down board is read.
  hold,

  /// The board dims while the dead are up ...
  dim,

  /// ... and comes back as the last of them goes down.
  undim,

  /// A hanged card leaves its slot for the middle of the window, big.
  lift,

  /// A card turns face up where it is (a hanged card on its way).
  turn,

  /// HANGED slams onto a dead card; a knock as it lands.
  stamp,

  /// The furled banner unrolls, once, its sentence whole.
  banner,

  /// A dead card goes back to its slot; its stamp lifts off.
  drop,

  /// The black ribbon is pinned on the hanged.
  ribbon,

  /// The three middle cards turn (with the last row).
  middle,

  /// The Hunter's twine and slip, once the one he took is back in its slot.
  pick,

  /// Nobody hanged: the winners rise together where they lie, turning ...
  rise,

  /// ... and settle back as the banner unrolls.
  lower,

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

/// The sizes the reveal adds to the board's: how big a dead card is in the
/// middle of the window, and how it is turned there.
abstract final class RevealMetrics {
  /// A dead card up is this share of the board's width (the mock's) ...
  static const bigWidthShare = 0.58;

  /// ... at most this share of the window's height ...
  static const bigHeightShare = 0.7;

  /// ... and clear of the window's sides by this.
  static const bigMargin = 24.0;

  /// The Hunter's pick lands smaller than the first death: it is the second.
  static const pickShare = 0.88;

  /// How far a dead card is turned at its biggest (the first one way, the
  /// next the other).
  static const bigTiltDegrees = 3.0;

  /// How far the winners rise when nobody is hanged, and how much larger.
  static const rise = 8.0;
  static const riseGrowth = 0.06;
}

/// The whole reveal of one board.
class EndReveal {
  const EndReveal({
    required this.spans,
    required this.total,
    required this.knocks,
    required this.thud,
    required this.scroll,
    required this.dead,
    required this.up,
    required this.big,
    required this.bigTurn,
    required this.backs,
    required this.backPortrait,
  });

  final List<RevealSpan> spans;

  /// When the last beat ends: the board is settled.
  final Duration total;

  /// The reveal's vibrations: one as each HANGED lands ([thud]), or one light
  /// one as the banner unrolls when nobody is hanged.
  final List<Duration> knocks;
  final bool thud;

  /// Where the board stands scrolled from the first frame to the last: where
  /// the settled board opens ([EndBoardPlan.initialScroll]), the dead in view.
  final double scroll;

  /// The dead, in the order their beats come (the vote's, then the Hunter's
  /// picks), by player id.
  final List<int> dead;

  /// A dead card's twin in its slot: the card with its art filling it (as
  /// wide as the card, the portrait as wide as the paper lets it), centred
  /// on the card. Board coordinates, untilted. By player id.
  final Map<int, Rect> up;

  /// Where each dead card's twin is at its biggest ([up] grown), and how far
  /// it is turned there (radians). By player id.
  final Map<int, Rect> big;
  final Map<int, double> bigTurn;

  /// Every card's back as it lies face down: one portrait size for all, as
  /// wide as its name needs, centred on the card. By player id.
  final Map<int, Rect> backs;
  final double backPortrait;

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

  bool get anyHanged => dead.isNotEmpty;

  /// Whether the dead card [id] is out of its slot at [t] (its twin is
  /// drawn): from its lift to the end of its drop.
  bool isUp(int id, Duration t) {
    final lift = of(RevealBeat.lift, card: id);
    final drop = of(RevealBeat.drop, card: id);
    return lift != null && drop != null && t >= lift.start && t < drop.end;
  }
}

/// The reveal of [plan].
EndReveal revealOf(EndBoardPlan plan) {
  final spans = <RevealSpan>[];
  // Every death, a beat each: the vote's, then the Hunter's picks (the
  // plan's order, which is the order they died).
  final dead = [
    for (final c in plan.cards)
      if (c.hanged && !c.pickedByHunter) c,
    for (final c in plan.cards)
      if (c.hanged && c.pickedByHunter) c,
  ];
  final knocks = <Duration>[];

  // The held beat: the face-down board, read. Short: the vote has just been
  // seen, and the stamp is the moment.
  const hold = RevealSpan(RevealBeat.hold, Duration.zero, Motion.reveal);
  spans.add(hold);

  var turnsFrom = hold.end;
  var settledFrom = hold.end;
  var poolFrom = hold.end;
  if (dead.isNotEmpty) {
    spans.add(RevealSpan(RevealBeat.dim, hold.end, Motion.quick));
    var from = hold.end;
    late RevealSpan lastDrop;
    for (final (i, c) in dead.indexed) {
      final first = i == 0;
      // Up out of its slot, big, turning face up on the way.
      final lift = RevealSpan(RevealBeat.lift, from, Motion.settle, card: c.id);
      spans
        ..add(lift)
        ..add(
          RevealSpan(
            RevealBeat.turn,
            lift.end - Motion.quick,
            Motion.quick,
            card: c.id,
          ),
        );
      // The face seen whole for a moment, then the stamp, and the knock as it
      // lands; the banner unrolls with the first.
      final stamp = RevealSpan(
        RevealBeat.stamp,
        lift.end + (first ? Motion.quick : Motion.press),
        Motion.press,
        card: c.id,
      );
      spans.add(stamp);
      knocks.add(stamp.end);
      if (first) {
        spans.add(RevealSpan(RevealBeat.banner, stamp.start, Motion.scene));
      }
      // Held, then back down to its slot, where the ribbon is pinned on.
      final drop = RevealSpan(
        RevealBeat.drop,
        stamp.end + (first ? Motion.reveal : Motion.settle),
        Motion.settle,
        card: c.id,
      );
      spans
        ..add(drop)
        ..add(
          RevealSpan(RevealBeat.ribbon, drop.end, Motion.press, card: c.id),
        );
      if (c.pickedByHunter) {
        spans.add(
          RevealSpan(RevealBeat.pick, drop.end, Motion.settle, card: c.id),
        );
      }
      lastDrop = drop;
      // The next death once this one is back in its slot.
      from = drop.end;
    }
    spans.add(RevealSpan(RevealBeat.undim, lastDrop.start, lastDrop.length));
    turnsFrom = lastDrop.start;
    settledFrom = lastDrop.end + Motion.press;
    poolFrom = settledFrom;
  }

  // Nobody hanged: the winners rise together where they lie, turning face up
  // in the lantern's light, then settle as the banner unrolls (a light knock).
  final rising = {
    if (dead.isEmpty)
      for (final c in plan.cards)
        if (c.won) c.id,
  };
  if (dead.isEmpty) {
    final banner = RevealSpan(
      RevealBeat.banner,
      hold.end +
          (rising.isEmpty ? Duration.zero : Motion.settle + Motion.quick),
      Motion.scene,
    );
    if (rising.isNotEmpty) {
      spans
        ..add(RevealSpan(RevealBeat.rise, hold.end, Motion.settle))
        ..add(RevealSpan(RevealBeat.lower, banner.start, Motion.settle));
      for (final id in rising) {
        spans.add(
          RevealSpan(RevealBeat.turn, hold.end, Motion.quick, card: id),
        );
      }
      settledFrom = banner.start + Motion.settle;
    }
    spans.add(banner);
    knocks.add(banner.start);
    turnsFrom = banner.start;
  }

  // Row by row, every card not yet face up turns where it lies; the middle
  // cards with the last row.
  final turned = {for (final c in dead) c.id, ...rising};
  final turningRows = plan.rows
      .where((row) => row.any((i) => !turned.contains(plan.cards[i].id)))
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
        if (!turned.contains(plan.cards[i].id)) plan.cards[i],
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

  // The board settles: the dealt cards and seals come out, the pool comes on
  // (with the winners' rise when nobody is hanged), the tags arrive.
  spans
    ..add(RevealSpan(RevealBeat.grow, settledFrom, Motion.settle))
    ..add(RevealSpan(RevealBeat.pool, poolFrom, Motion.settle))
    ..add(RevealSpan(RevealBeat.tags, settledFrom, Motion.settle));

  final scroll = plan.scrolls ? plan.initialScroll : 0.0;
  final backPortrait = plan.cards
      .map((c) => c.portraitWidth)
      .fold(double.infinity, math.min);
  final up = {for (final c in dead) c.id: upOf(c)};
  return EndReveal(
    spans: spans,
    total: _latest([for (final s in spans) s.end]),
    knocks: knocks,
    thud: dead.isNotEmpty,
    scroll: scroll,
    dead: [for (final c in dead) c.id],
    up: up,
    big: _bigOf(plan, dead, up, scroll),
    bigTurn: {
      for (final (i, c) in dead.indexed)
        c.id:
            (i.isEven ? -1 : 1) * RevealMetrics.bigTiltDegrees * math.pi / 180,
    },
    backs: {for (final c in plan.cards) c.id: backOf(c, backPortrait)},
    backPortrait: backPortrait,
  );
}

/// The back of [c] face down, with a portrait [portrait] wide: as wide as the
/// portrait and its paper, or the name and its room, centred on the card.
/// Never wider or taller than the card.
Rect backOf(EndCard c, double portrait) {
  final width = math.min(
    c.rect.width,
    math.max(portrait + 2 * EndMetrics.portraitInset, c.nameWidth),
  );
  final height = math.min(
    c.rect.height,
    EndMetrics.cardHeight(portrait, header: c.header),
  );
  return Rect.fromCenter(center: c.rect.center, width: width, height: height);
}

/// A dead card's twin in its slot: as wide as the card, its portrait as wide
/// as the paper lets it, so the art fills the card.
Rect upOf(EndCard c) => Rect.fromCenter(
  center: c.rect.center,
  width: c.rect.width,
  height: EndMetrics.cardHeight(
    c.rect.width - 2 * EndMetrics.portraitInset,
    header: c.header,
  ),
);

/// The most rows the cascade of turns gives a full [Motion.stagger] each.
const _cascadeRows = 5;

Duration _latest(Iterable<Duration> times) =>
    times.fold(Duration.zero, (a, b) => b > a ? b : a);

/// Each dead card alone in the middle of the window (as it stands scrolled
/// to [scroll]), a set share of the board wide (the Hunter's pick a little
/// smaller), no taller than a share of the window; never smaller than it is.
Map<int, Rect> _bigOf(
  EndBoardPlan plan,
  List<EndCard> dead,
  Map<int, Rect> up,
  double scroll,
) {
  final room = Rect.fromLTWH(
    0,
    scroll,
    plan.boardWidth,
    plan.seenAtTop,
  ).deflate(RevealMetrics.bigMargin);
  final wide = math.min(
    RevealMetrics.bigWidthShare * plan.boardWidth,
    room.width,
  );
  return {
    for (final c in dead)
      c.id: () {
        final box = up[c.id]!;
        final share = c.pickedByHunter ? RevealMetrics.pickShare : 1.0;
        final fits = math.min(
          wide / box.width,
          RevealMetrics.bigHeightShare * room.height / box.height,
        );
        final scale = math.max(1.0, fits * share);
        return Rect.fromCenter(
          center: room.center,
          width: box.width * scale,
          height: box.height * scale,
        );
      }(),
  };
}
