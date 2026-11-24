import 'dart:math' as math;
import 'dart:ui';

import 'end_board_cards.dart';
import 'end_board_metrics.dart';

// What happened, on a board that scrolls (docs/specs/frontend/end-board.md,
// section 8): where the board stands for a step, so every card the step is
// about is whole in the window before it plays. Pure: from the plan alone,
// so the board and its tests agree.

/// How far from the window's edges a card of the step is kept.
const nightClear = EndMetrics.clear + EndMetrics.clear;

/// Where the board stands for a step about the cards of [players], in the
/// board's frame (its scroll), and the cards lifted from their seats for the
/// step because they cannot be in view with the first of them ([docked]: by
/// how far each is moved). The step's cards are centred in the window;
/// where they cannot all be in it together, the first (the one who acted)
/// stands at the window's edge away from the others, and each other card is
/// lifted to the window's opposite edge, in front, for the step (or the
/// first place in the window clear of the step's other cards, and of the
/// other players' names where one is). [deal]: the
/// board as near its top as it can stand with the cards in view ("you", as
/// the night begins).
({double scroll, Map<int, Offset> docked}) nightViewOf(
  EndBoardPlan plan,
  List<int> players, {
  bool deal = false,
}) {
  if (!plan.scrolls || players.isEmpty) return (scroll: 0, docked: const {});
  final seen = plan.viewHeight - EndMetrics.lip;
  final most = nightMostScroll(plan);
  Rect bounds(int id) {
    final c = plan.card(id);
    final seal = c.sealRect;
    return seal == null ? c.leaned : c.leaned.expandToInclude(seal);
  }

  final rects = {for (final id in players) id: bounds(id)};
  final top = rects.values.map((r) => r.top).reduce(math.min);
  final bottom = rects.values.map((r) => r.bottom).reduce(math.max);
  if (bottom - top + 2 * nightClear <= seen) {
    final scroll = deal
        ? bottom + nightClear - seen
        : (top + bottom) / 2 - seen / 2;
    return (scroll: scroll.clamp(0.0, most), docked: const {});
  }
  final first = rects[players.first]!;
  final others = [
    for (final MapEntry(:key, :value) in rects.entries)
      if (key != players.first) value,
  ];
  final below = others.every((r) => r.center.dy >= first.center.dy);
  final above = others.every((r) => r.center.dy <= first.center.dy);
  final scroll =
      (below
              ? first.top - nightClear
              : above
              ? first.bottom + nightClear - seen
              : (first.top + first.bottom) / 2 - seen / 2)
          .clamp(0.0, most);
  final placed = [first];
  final docked = <int, Offset>{};
  // The names of the cards the step is not about: a card lifted over them
  // leaves them clear where it can.
  final names = [
    for (final c in plan.cards)
      if (!rects.containsKey(c.id)) nightNameOf(c),
  ];
  for (final MapEntry(key: id, value: r) in rects.entries) {
    if (id == players.first) continue;
    var dy = 0.0;
    if (r.top < scroll + nightClear) {
      dy = scroll + nightClear - r.top;
    } else if (r.bottom > scroll + seen - nightClear) {
      dy = scroll + seen - nightClear - r.bottom;
    }
    final edge = r.shift(Offset(0, dy));
    // Where it would lie on a card of the step: the first place in the
    // window, on the board, clear of them (its own edge first, then the
    // other, then the middle; its own column first, then the sides).
    bool free(Rect c) =>
        c.left >= EndMetrics.clear &&
        c.right <= plan.boardWidth - EndMetrics.clear &&
        c.top >= scroll + nightClear - 0.5 &&
        c.bottom <= scroll + seen - nightClear + 0.5 &&
        !placed.any((p) => p.inflate(EndMetrics.clear).overlaps(c));
    final w = r.width, h = r.height;
    final spots = [
      for (final y in [
        edge.top,
        if (dy >= 0) scroll + seen - nightClear - h else scroll + nightClear,
        scroll + (seen - h) / 2,
      ])
        for (final x in [
          r.left,
          EndMetrics.clear,
          plan.boardWidth - EndMetrics.clear - w,
          (plan.boardWidth - w) / 2,
        ])
          Rect.fromLTWH(x, y, w, h),
    ].where(free);
    final at =
        spots
            .where((c) => !names.any((n) => n.deflate(0.5).overlaps(c)))
            .firstOrNull ??
        spots.firstOrNull;
    if (at == null) {
      return (
        scroll: scroll,
        docked: _flowed(
          plan,
          {for (final id in rects.keys) id: plan.card(id).rect},
          scroll: scroll,
          seen: seen,
        ),
      );
    }
    placed.add(at);
    if (at != r) docked[id] = at.topLeft - r.topLeft;
  }
  return (scroll: scroll, docked: docked);
}

/// Every card of the step lifted into the window together, where even
/// lifting the others leaves no room beside the first: in rows across the
/// board, the first first, a little apart, the rows centred in the window;
/// lifted level ([nightLevel]), so each takes only its own height.
Map<int, Offset> _flowed(
  EndBoardPlan plan,
  Map<int, Rect> rects, {
  required double scroll,
  required double seen,
}) {
  // Close: this is the smallest window (a short phone at large text).
  const gap = EndMetrics.clear / 3;
  final rows = <List<int>>[[]];
  var x = gap;
  for (final MapEntry(key: id, value: r) in rects.entries) {
    if (rows.last.isNotEmpty && x + r.width + gap > plan.boardWidth) {
      rows.add([]);
      x = gap;
    }
    rows.last.add(id);
    x += r.width + gap;
  }
  double heightOf(List<int> row) =>
      row.map((id) => rects[id]!.height).reduce(math.max);
  final total =
      rows.map(heightOf).fold(0.0, (a, b) => a + b) + gap * (rows.length - 1);
  var y = scroll + math.max(gap, (seen - total) / 2);
  final docked = <int, Offset>{};
  for (final row in rows) {
    final width =
        row.map((id) => rects[id]!.width).fold(0.0, (a, b) => a + b) +
        gap * (row.length - 1);
    var left = (plan.boardWidth - width) / 2;
    for (final id in row) {
      final r = rects[id]!;
      docked[id] = Offset(left, y) - r.topLeft;
      left += r.width + gap;
    }
    y += heightOf(row) + gap;
  }
  return docked;
}

/// How far the board may scroll at night: far enough that its lowest card
/// stands whole above the foot's lip.
double nightMostScroll(EndBoardPlan plan) {
  final day = math.max(0.0, plan.boardHeight - plan.viewHeight);
  final lowest = plan.cards.map((c) => c.leaned.bottom).fold(0.0, math.max);
  final seen = plan.viewHeight - EndMetrics.lip;
  return math.max(day, lowest + nightClear - seen);
}

/// The room a board that scrolls takes under its foot at night, so its
/// lowest card can stand above the lip.
double nightRoomOf(EndBoardPlan plan) => plan.scrolls
    ? nightMostScroll(plan) - math.max(0.0, plan.boardHeight - plan.viewHeight)
    : 0;

/// A card lifted into the window for a step is drawn level (no tilt): all
/// of the step's cards were lifted together ([nightViewOf]'s last resort).
bool nightLevel(Map<int, Offset> docked, int players) =>
    docked.length == players && players > 1;

/// Where a middle card the step is about lies for the step: lifted onto the
/// board beside the card of the one who acted ([actor], as it lies for the
/// step), so its thread is short and stays on the board (never down over
/// the board's lip to the foot). Clear of every card and seal ([taken], as
/// they lie) and of the frame's edges, in the window the board stands at
/// ([scroll]); the first of: right of the actor, left, below, above, then
/// the free place in the window nearest the actor, the line to it crossing
/// nothing. Where no place is clear
/// of every card, it is lifted in front of the cards the step is not about,
/// as the fit pass lifts a card ([nightViewOf]): clear of the step's own
/// cards and seals ([step]) and of every player's name ([names]: a name is
/// never covered); where that leaves no room, over the picture of a step's
/// player card ([under]), still clear of every name; only where even that leaves none, clear of
/// the step's own cards alone.
Rect nightMiddleAt(
  EndBoardPlan plan, {
  required Rect actor,
  required Size size,
  required List<Rect> taken,
  List<Rect> step = const [],
  List<Rect> names = const [],
  List<Rect> under = const [],
  double scroll = 0,
}) => _middleAt(
  plan,
  actor: actor,
  size: size,
  taken: taken,
  step: step,
  names: names,
  under: under,
  scroll: scroll,
  clear: false,
)!;

/// Where [nightMiddleAt] puts a card, only where it leaves every card it is
/// not lifted over, every seal and every player's name clear: null where no
/// such place is in the window (the step's middle cards stay in the foot).
Rect? nightMiddleClearAt(
  EndBoardPlan plan, {
  required Rect actor,
  required Size size,
  required List<Rect> taken,
  List<Rect> step = const [],
  List<Rect> names = const [],
  List<Rect> under = const [],
  double scroll = 0,
}) => _middleAt(
  plan,
  actor: actor,
  size: size,
  taken: taken,
  step: step,
  names: names,
  under: under,
  scroll: scroll,
  clear: true,
);

Rect? _middleAt(
  EndBoardPlan plan, {
  required Rect actor,
  required Size size,
  required List<Rect> taken,
  required List<Rect> step,
  required List<Rect> names,
  required List<Rect> under,
  required double scroll,
  required bool clear,
}) {
  const gap = EndMetrics.clear;
  final seen = math.min(plan.boardHeight, plan.viewHeight - EndMetrics.lip);
  final window = Rect.fromLTRB(
    gap,
    scroll + gap,
    plan.boardWidth - gap,
    scroll + seen - gap,
  );
  // Room for the thread and its two ends between the actor and the card
  // (less, where the window is small).
  var room = EndMetrics.clear * 6;
  var clearOf = taken;
  var mustReach = true;
  // The names kept clear of in this tier: to the hair, a name's band being
  // all a card lifted over the others must leave.
  var named = const <Rect>[];
  // A thread can run to it: the line between the two crosses nothing.
  bool reaches(Rect r) {
    const steps = 32;
    for (var i = 1; i < steps; i++) {
      final p = Offset.lerp(actor.center, r.center, i / steps)!;
      if (actor.contains(p) || r.contains(p)) continue;
      if (clearOf.any((t) => t.inflate(gap / 2).contains(p))) return false;
    }
    return true;
  }

  bool free(Rect r) =>
      window.inflate(0.5).contains(r.topLeft) &&
      window.inflate(0.5).contains(r.bottomRight) &&
      !actor.inflate(room - 0.5).overlaps(r) &&
      !clearOf.any((t) => t.inflate(gap).overlaps(r)) &&
      !named.any((n) => n.deflate(0.5).overlaps(r)) &&
      (!mustReach || reaches(r));
  final w = size.width, h = size.height;
  List<Rect> beside() => [
    Rect.fromLTWH(actor.right + room, actor.center.dy - h / 2, w, h),
    Rect.fromLTWH(actor.left - room - w, actor.center.dy - h / 2, w, h),
    Rect.fromLTWH(actor.center.dx - w / 2, actor.bottom + room, w, h),
    Rect.fromLTWH(actor.center.dx - w / 2, actor.top - room - h, w, h),
  ];
  Rect slide(Rect r) {
    // Slid into the window along its side, if it is only a little out.
    final dy = r.top < window.top
        ? window.top - r.top
        : math.min(0.0, window.bottom - r.bottom);
    final dx = r.left < window.left
        ? window.left - r.left
        : math.min(0.0, window.right - r.right);
    return r.shift(Offset(dx, dy));
  }

  const stride = EndMetrics.clear / 2;
  for (final (tier, keepNames, least, reach) in [
    (taken, false, room, true),
    (step, true, room, true),
    (step, true, EndMetrics.clear * 3, true),
    (step, true, EndMetrics.clear, true),
    (step, true, EndMetrics.clear, false),
    // No room off the step's cards: over the picture of a step's card it
    // may lie on ([under]), still clear of every name.
    (
      [
        for (final t in step)
          if (!under.contains(t)) t,
      ],
      true,
      EndMetrics.clear,
      false,
    ),
    // Over a name: never where it must leave every name clear.
    if (!clear) ...[
      (step, false, room, true),
      (step, false, EndMetrics.clear * 3, true),
      (step, false, EndMetrics.clear, false),
    ],
  ]) {
    clearOf = tier;
    named = keepNames ? names : const [];
    room = least;
    mustReach = reach;
    for (final r in beside().map(slide)) {
      if (free(r)) return r;
    }
    Rect? best;
    for (var y = window.top; y + h <= window.bottom + 0.5; y += stride) {
      for (var x = window.left; x + w <= window.right + 0.5; x += stride) {
        final r = Rect.fromLTWH(x, y, w, h);
        if (!free(r)) continue;
        if (best == null ||
            (r.center - actor.center).distance <
                (best.center - actor.center).distance) {
          best = r;
        }
      }
    }
    if (best != null) return best;
  }
  return clear ? null : slide(beside().first);
}

/// Where [card]'s name is drawn as the card lies ([lift]: its offset for the
/// step): the room its letters have ([EndCard.nameText]), turned with the
/// card about its middle, as a box. What a card lifted for the step keeps
/// clear of ([nightMiddleAt]'s names, [nightViewOf]).
Rect nightNameOf(EndCard card, [Offset lift = Offset.zero]) {
  final r = card.rect, letters = card.nameText;
  final d = letters.center - r.center;
  final cos = math.cos(card.angle), sin = math.sin(card.angle);
  final turned =
      r.center + Offset(d.dx * cos - d.dy * sin, d.dx * sin + d.dy * cos);
  return EndMetrics.leaned(
    Rect.fromCenter(
      center: turned,
      width: letters.width,
      height: letters.height,
    ),
    card.angle,
  ).shift(lift);
}
