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
