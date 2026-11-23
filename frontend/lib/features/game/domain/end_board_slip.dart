import 'dart:math' as math;
import 'dart:ui';

import 'end_board.dart';
import 'end_board_metrics.dart';

// Where the Hunter's slip hangs (docs/specs/frontend/end-board.md, section 2,
// "The Hunter's pick"), once every card is placed: it costs the board no
// height. Pure arithmetic on rectangles.

/// The Hunter's slip: hung between [from] and [to] under the twine, where
/// it covers no card's name, tag, seal, ribbon or pin.
Rect placeSlip({
  required EndCard from,
  required EndCard to,
  required List<EndCard> all,
  required double boardWidth,
  required double width,
}) {
  final w = width + EndMetrics.slipRoom;
  const h = EndMetrics.slipHeight;
  final a = from.rect, b = to.rect;
  Offset centre;
  if (from.row == to.row) {
    final left = a.left < b.left ? a : b;
    final right = a.left < b.left ? b : a;
    centre = Offset(
      (left.right + right.left) / 2,
      math.min(a.top, b.top) + from.rect.height * 0.62,
    );
  } else {
    centre = Offset(
      (a.center.dx + b.center.dx) / 2,
      (a.center.dy + b.center.dy) / 2,
    );
  }
  bool clean(Rect s) {
    for (final c in all) {
      if (s.overlaps(c.nameText.inflate(2))) return false;
      // Nor the role on its strip, across the portrait's foot.
      final strip = Rect.fromLTWH(
        c.rect.left,
        c.rect.top +
            c.header +
            EndMetrics.portraitHeight(c.portraitWidth) -
            c.stripHeight,
        c.rect.width,
        c.stripHeight,
      );
      if (s.overlaps(strip.inflate(2))) return false;
      // No card but the two it hangs between.
      if (c.id != from.id && c.id != to.id && s.overlaps(c.leaned)) {
        return false;
      }
      for (final part in [
        c.sealRect,
        c.ribbonDrawn,
        c.pin,
        ...c.tags.map((t) => t.rect),
      ]) {
        if (part != null && s.overlaps(part.inflate(2))) return false;
      }
    }
    return true;
  }

  // Anywhere between the two cards (their boxes and what lies between, a
  // little round them), nearest the middle first: it stays on their twine.
  final between = a.expandToInclude(b).inflate(EndMetrics.slipReach);
  final tries = <Offset>[
    for (var y = between.top; y <= between.bottom; y += 4)
      for (var x = between.left; x <= between.right; x += 8)
        Offset(x, y) - centre,
  ]..sort((p, q) => p.distanceSquared.compareTo(q.distanceSquared));
  // How much of the cards' faces it covers: least wins, then the nearest to
  // the middle between the two (it hangs between them, not on one).
  double covered(Rect s) {
    var area = 0.0;
    for (final c in all) {
      final over = s.intersect(c.leaned);
      if (over.width > 0 && over.height > 0) area += over.width * over.height;
    }
    return area;
  }

  Rect? best;
  var least = double.infinity;
  for (final t in tries) {
    final s = Rect.fromCenter(center: centre + t, width: w, height: h);
    if (s.left < EndMetrics.insetX ||
        s.right > boardWidth - EndMetrics.insetX) {
      continue;
    }
    if (!clean(s)) continue;
    final area = covered(s);
    if (area < least - 1) {
      least = area;
      best = s;
      if (area == 0) break;
    }
  }
  return best ?? Rect.fromCenter(center: centre, width: w, height: h);
}

/// The hard rule (spec 1 and 2), on a whole board: no card lies on another;
/// what hangs on a card (its dealt card, ribbon, seal, pin and tags) covers no
/// other card and no other card's tag, and a tag, seal or ribbon not its own
/// card's name; the Hunter's slip covers no name, tag, seal or ribbon and no
/// card but the two it hangs between. A step of `EndFit` that breaks it is
/// not taken.
bool coversNothing(EndBoardPlan plan) {
  final cards = plan.cards;
  for (final a in cards) {
    final hung = [
      a.dealtRect,
      a.ribbonRect,
      a.sealRect,
      a.pin,
      ...a.tags.map((t) => t.rect),
    ].nonNulls;
    for (final t in [a.ribbonRect, a.sealRect, ...a.tags.map((t) => t.rect)]) {
      if (t != null && t.overlaps(a.nameText)) return false;
    }
    for (final b in cards) {
      if (a.id == b.id) continue;
      if (a.leaned.overlaps(b.leaned.deflate(1))) return false;
      if (hung.any((h) => h.overlaps(b.leaned))) return false;
      for (final t in a.tags) {
        if (b.tags.any((u) => t.rect.overlaps(u.rect))) return false;
      }
    }
  }
  for (final pick in plan.picks) {
    final s = pick.slip;
    for (final c in cards) {
      if (s.overlaps(c.nameText)) return false;
      if (c.tags.any((t) => s.overlaps(t.rect))) return false;
      for (final part in [c.sealRect, c.ribbonDrawn]) {
        if (part != null && s.overlaps(part)) return false;
      }
      if (c.id != pick.hunterId &&
          c.id != pick.pickId &&
          s.overlaps(c.leaned)) {
        return false;
      }
    }
  }
  return true;
}
