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
/// first place in the window clear of the step's other cards). [deal]: the
/// board as near its top as it can stand with the cards in view ("you", as
/// the night begins).
({double scroll, Map<int, Offset> docked, bool open}) nightViewOf(
  EndBoardPlan plan,
  List<int> players, {
  bool deal = false,
}) {
  if (!plan.scrolls || players.isEmpty) {
    return (scroll: 0, docked: const {}, open: false);
  }
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
    return (scroll: scroll.clamp(0.0, most), docked: const {}, open: false);
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
  // Every other piece on the board: a lifted card lies over empty board.
  final board = [
    plan.lantern,
    for (final c in plan.cards)
      if (!rects.containsKey(c.id)) bounds(c.id),
  ];
  final docked = <int, Offset>{};
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
        !placed.any((p) => p.inflate(EndMetrics.clear).overlaps(c)) &&
        !board.any((p) => p.inflate(EndMetrics.clear / 2).overlaps(c));
    final w = r.width, h = r.height;
    final at = [
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
    ].where(free).firstOrNull;
    // No empty board in the window for it: the step opens the board
    // ([nightOpeningOf]).
    if (at == null) return (scroll: scroll, docked: const {}, open: true);
    placed.add(at);
    if (at != r) docked[id] = at.topLeft - r.topLeft;
  }
  return (scroll: scroll, docked: docked, open: false);
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

/// Where a middle card the step is about lies for the step: lifted onto the
/// board beside the card of the one who acted ([actor], as it lies for the
/// step), so its thread is short and stays on the board (never down over
/// the board's lip to the foot). Clear of every card and seal ([taken], as
/// they lie) and of the frame's edges, in the window the board stands at
/// ([scroll]); the first of: right of the actor, left, below, above, then
/// the free place in the window nearest the actor, the line to it crossing
/// nothing. Where no place in the window is clear of every card (it lies
/// over empty board only), null: the step opens the board
/// ([nightOpeningOf]).
Rect? nightMiddleAt(
  EndBoardPlan plan, {
  required Rect actor,
  required Size size,
  required List<Rect> taken,
  double scroll = 0,
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
  // A thread can run to it: the line between the two crosses nothing.
  bool reaches(Rect r) {
    const steps = 32;
    for (var i = 1; i < steps; i++) {
      final p = Offset.lerp(actor.center, r.center, i / steps)!;
      if (actor.contains(p) || r.contains(p)) continue;
      if (taken.any((t) => t.inflate(gap / 2).contains(p))) return false;
    }
    return true;
  }

  var mustReach = true;
  bool free(Rect r) =>
      window.inflate(0.5).contains(r.topLeft) &&
      window.inflate(0.5).contains(r.bottomRight) &&
      !actor.inflate(room - 0.5).overlaps(r) &&
      !taken.any((t) => t.inflate(gap).overlaps(r)) &&
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
  for (final (least, reach) in [
    (room, true),
    (EndMetrics.clear * 3, true),
    (EndMetrics.clear * 2, false),
  ]) {
    mustReach = reach;
    room = least;
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
  return null;
}

/// A step that has no empty board in the window for the cards it lifts
/// opens the board: every piece below the one who acted ([actor]) slides
/// down by `height`, and the step's other cards ([players], and [middles]
/// middle cards of [middleSize]) lie in the room opened under it, in rows
/// centred on it, a thread's room apart. Where the one who acted and that
/// room cannot be in the window together (a short phone at large text),
/// the one who acted is lifted into the room too, first in its row, so the
/// step's cards lie side by side. Nothing lies on anything; the board
/// scrolls to show the step's cards together.
({
  double height,
  Map<int, Offset> docked,
  Offset lantern,
  List<Rect> middles,
  double scroll,
})
nightOpeningOf(
  EndBoardPlan plan, {
  required int actor,
  required List<int> players,
  required int middles,
  required Size middleSize,
}) {
  const gap = EndMetrics.clear;
  // Room between two of the step's cards for a thread and its two ends.
  const room = EndMetrics.clear * 6;
  final seen = plan.viewHeight - EndMetrics.lip;
  Rect whole(EndCard c) {
    final seal = c.sealRect;
    return seal == null ? c.leaned : c.leaned.expandToInclude(seal);
  }

  final a = whole(plan.card(actor));
  bool below(Rect r) => r.center.dy > a.center.dy;
  final others = [
    for (final id in players)
      if (id != actor) id,
  ];
  final rest = [
    for (final c in plan.cards)
      if (c.id != actor && !others.contains(c.id)) c,
  ];
  final above = [
    for (final c in rest)
      if (!below(whole(c))) whole(c),
    if (!below(plan.lantern)) plan.lantern,
  ];
  final sliding = [
    for (final c in rest)
      if (below(whole(c))) whole(c),
    if (below(plan.lantern)) plan.lantern,
  ];

  // The lifted pieces in rows across the board, from [top], centred on the
  // actor.
  List<Rect> rows(List<Size> sizes, double top) {
    final placed = <Rect>[];
    var y = top;
    var i = 0;
    while (i < sizes.length) {
      var j = i;
      var width = 0.0, height = 0.0;
      while (j < sizes.length &&
          (j == i ||
              width + room + sizes[j].width <= plan.boardWidth - gap * 2)) {
        width += (j == i ? 0 : room) + sizes[j].width;
        height = math.max(height, sizes[j].height);
        j++;
      }
      var x = (a.center.dx - width / 2)
          .clamp(gap, math.max(gap, plan.boardWidth - gap - width))
          .toDouble();
      for (var k = i; k < j; k++) {
        placed.add(Rect.fromLTWH(x, y, sizes[k].width, sizes[k].height));
        x += sizes[k].width + room;
      }
      y += height + room;
      i = j;
    }
    return placed;
  }

  final sizes = [
    for (final id in others) plan.card(id).leaned.size,
    for (var i = 0; i < middles; i++) middleSize,
  ];
  final highest = above.isEmpty
      ? a.top - gap
      : above.map((r) => r.bottom).reduce(math.max);
  var lifting = others;
  var placed = rows(sizes, math.max(highest + gap, a.bottom + room));
  var from = a.top;
  double bottomOf(List<Rect> rs) => rs.map((r) => r.bottom).reduce(math.max);
  if (placed.isEmpty || bottomOf(placed) - from + 2 * nightClear > seen) {
    // Side by side: the one who acted is lifted into the room too.
    lifting = [actor, ...others];
    final top = math.max(highest + gap, a.top);
    placed = rows([plan.card(actor).leaned.size, ...sizes], top);
    from = top;
  }
  final bottom = bottomOf(placed);
  final first = sliding.isEmpty
      ? double.infinity
      : sliding.map((r) => r.top).reduce(math.min);
  // Nothing below to slide: room enough under the board to scroll to it.
  final height = sliding.isEmpty
      ? math.max(0.0, bottom + nightClear - seen - nightMostScroll(plan))
      : math.max(0.0, bottom + gap - first);
  final docked = <int, Offset>{
    for (final c in rest)
      if (below(whole(c)) && height > 0) c.id: Offset(0, height),
    for (final (k, id) in lifting.indexed)
      id: placed[k].topLeft - plan.card(id).leaned.topLeft,
  };
  final start = from - nightClear, end = bottom + nightClear;
  final scroll = end - start <= seen ? (start + end) / 2 - seen / 2 : start;
  return (
    height: height,
    docked: docked,
    lantern: below(plan.lantern) ? Offset(0, height) : Offset.zero,
    middles: placed.sublist(lifting.length),
    scroll: scroll.clamp(0.0, nightMostScroll(plan) + height),
  );
}
