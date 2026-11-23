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
      for (final part in [
        c.sealRect,
        c.ribbonRect,
        c.pin,
        ...c.tags.map((t) => t.rect),
      ]) {
        if (part != null && s.overlaps(part.inflate(2))) return false;
      }
    }
    return true;
  }

  final tries = <Offset>[
    for (var dy = -90.0; dy <= 90; dy += 4)
      for (var dx = -80.0; dx <= 80; dx += 8) Offset(dx, dy),
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
