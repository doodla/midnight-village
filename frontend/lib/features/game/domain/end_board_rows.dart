import 'dart:math' as math;
import 'dart:ui';

import 'end_board.dart';
import 'end_board_metrics.dart';

// The packing under `planEndBoard` (docs/specs/frontend/end-board.md, section
// 3, rules 2, 3 and 5): what a
// card needs, which cards share a row, how high each row stands, and where the
// Hunter's slip hangs. Pure arithmetic on numbers and rectangles.

/// A card before it is placed: its size and what it needs round it.
class SizedCard {
  const SizedCard({
    required this.id,
    required this.pw,
    required this.width,
    required this.height,
    required this.tagNames,
    required this.tagWidth,
    required this.dealt,
    required this.you,
    required this.hanged,
    required this.reachLeft,
    required this.reachRight,
    required this.above,
    required this.header,
    required this.lean,
    required this.tagHeight,
    required this.tagColumns,
    required this.wideStrand,
  });

  final int id;

  /// The portrait's width.
  final double pw;
  final double width;
  final double height;
  final List<String> tagNames;

  /// The widest tag of its strand (0 with none).
  final double tagWidth;
  final bool dealt;
  final bool you;
  final bool hanged;

  /// What sticks out of it to the left (the dealt card) and right (the seal,
  /// the ribbon).
  final double reachLeft;
  final double reachRight;

  /// Air it needs above its row: for its dealt card and its ribbon.
  final double above;

  /// The name's header: as tall as the name is at this text size.
  final double header;

  /// How far the card, turned by its own tilt, reaches out of its upright box
  /// across and down (the same up).
  final Size lean;

  /// How tall each of its tags is, and in how many columns they hang.
  final double tagHeight;
  final int tagColumns;

  /// Its strand hangs across the whole row (the other card in it has none),
  /// from under the lower of the two.
  final bool wideStrand;

  bool get hasTags => tagNames.isNotEmpty;

  /// The room it needs across the board: the card, or its strand of tags.
  double get need => math.max(
    width + 2 * lean.width,
    wideStrand
        ? tagWidth
        : tagWidth * tagColumns + EndMetrics.tagGap * (tagColumns - 1),
  );

  /// How far it reaches under its upright bottom: its lean, then its strand.
  double get under =>
      lean.height +
      EndMetrics.strand(tagNames.length, tagHeight, columns: tagColumns);
}

/// A card sized: the width is the largest of the portrait plus 8, the name plus
/// 20, and the wider role plus 18 (and 28 more with tags, to clear the pin),
/// never more than [maxWidth] (the name is then set smaller, never cut).
SizedCard sizeCard({
  required int id,
  required double pw,
  required String name,
  required List<String> stripWords,
  required List<String> tagNames,
  required bool dealt,
  required bool you,
  required bool hanged,
  required double maxWidth,
  required double header,
  required double tagHeight,
  required double angle,
  required double slot,
  required EndMeasure measure,
  bool wideStrand = false,
}) {
  final role = stripWords
      .map((w) => measure(EndText.role, w))
      .fold(0.0, math.max);
  final width = math
      .max(
        pw + 2 * EndMetrics.portraitInset,
        math.max(
          measure(EndText.name, name) + EndMetrics.nameRoom,
          role +
              EndMetrics.roleRoom +
              (tagNames.isEmpty ? 0 : EndMetrics.tagRoom),
        ),
      )
      .clamp(0.0, maxWidth)
      .toDouble();
  final dw = EndMetrics.dealtWidth(pw);
  final rw = EndMetrics.ribbonWidth(pw);
  final rh = EndMetrics.ribbonHeight(rw);
  final dealtUp = EndMetrics.dealtOutY * dw * EndMetrics.dealtRatio;
  final ribbonUp = rh * (1 - EndMetrics.ribbonInside);
  final height = EndMetrics.cardHeight(pw, header: header);
  final lean = EndMetrics.leanOf(Size(width, height), angle);
  final tagWidth = tagNames
      .map((n) => EndMetrics.tagApron + measure(EndText.tag, n))
      .fold(0.0, math.max);
  // More than three tags hang in as many columns as fit the room (two in a
  // card's own slot, up to three across a row), so a strand stays short.
  var columns = 1;
  if (tagNames.length > EndMetrics.tagsInOneColumn) {
    for (var k = EndMetrics.mostTagColumns; k > 1; k--) {
      if (k * tagWidth + (k - 1) * EndMetrics.tagGap <=
          slot - 2 * EndMetrics.clear) {
        columns = k;
        break;
      }
    }
  }
  return SizedCard(
    id: id,
    pw: pw,
    width: width,
    height: height,
    header: header,
    lean: lean,
    tagHeight: tagHeight,
    tagColumns: columns,
    wideStrand: wideStrand && columns > 1,
    tagNames: tagNames,
    tagWidth: tagWidth,
    dealt: dealt,
    you: you,
    hanged: hanged,
    reachLeft: dealt ? EndMetrics.dealtOutX * dw : 0,
    reachRight: math.max(
      // Room for the seal on every card, so no card moves with who is looking.
      EndMetrics.sealHang,
      hanged ? rw * (1 - EndMetrics.ribbonInside) : 0,
    ),
    above:
        lean.height +
        math.max(
          dealt
              ? math.max(EndMetrics.gapDealt, dealtUp + EndMetrics.hangClear)
              : EndMetrics.gap,
          hanged ? ribbonUp + EndMetrics.hangClear : 0,
        ),
  );
}

/// The rows: indexes into the cards, left to right.
class Rows {
  const Rows(this.rows);

  final List<List<int>> rows;
}

/// Where a row's room lies across the board: the first row stops at the
/// lantern.
Rect spanOf(int row, double boardWidth) => Rect.fromLTRB(
  EndMetrics.insetX,
  0,
  row == 0
      ? boardWidth - EndMetrics.firstRowFromRight
      : boardWidth - EndMetrics.insetX,
  0,
);

/// [cards] in rows of two. [firstDead] is where the dead begin (they start a
/// row of their own). A card that does not fit its slot takes a row alone; in
/// the first row, beside the lantern, it swaps with a narrower card after it.
Rows packRows(List<SizedCard> cards, double boardWidth, int firstDead) {
  final rows = <List<int>>[];

  bool fits(int i, double room) => cards[i].need + 2 * EndMetrics.clear <= room;

  // Two cards in a row of [span]: can they stand apart enough for what sticks
  // out of them, each at least [clear] from its slot's edge?
  bool pairOk(int a, int b, double span) {
    final half = span / 2;
    if (!fits(a, half) || !fits(b, half)) return false;
    final ca = cards[a], cb = cards[b];
    final gap = (half - ca.width) / 2 + (half - cb.width) / 2;
    // Two strands side by side keep clear of each other.
    if (ca.hasTags && cb.hasTags) {
      final strands = (half - ca.need) / 2 + (half - cb.need) / 2;
      if (strands < EndMetrics.clear) return false;
    }
    final slack =
        math.max(0.0, (half - ca.width) / 2 - EndMetrics.clear) +
        math.max(0.0, (half - cb.width) / 2 - EndMetrics.clear);
    return gap + slack >= _needGap(ca, cb);
  }

  void pack(List<int> from) {
    final q = [...from];
    while (q.isNotEmpty) {
      final r = rows.length;
      final span = spanOf(r, boardWidth).width;
      if (!fits(q[0], span / 2)) {
        if (r == 0) {
          final j = q.indexWhere((i) => fits(i, span / 2), 1);
          if (j > 0) {
            _swap(q, 0, j);
            continue;
          }
        }
        rows.add([q.removeAt(0)]);
        continue;
      }
      if (q.length == 1) {
        rows.add([q.removeAt(0)]);
        break;
      }
      if (!pairOk(q[0], q[1], span)) {
        if (r == 0) {
          final j = q.indexWhere((i) => pairOk(q[0], i, span), 2);
          if (j >= 2) {
            _swap(q, 1, j);
            continue;
          }
        }
        rows.add([q.removeAt(0)]);
        continue;
      }
      rows.add([q.removeAt(0), q.removeAt(0)]);
    }
  }

  pack([for (var i = 0; i < firstDead && i < cards.length; i++) i]);
  pack([for (var i = firstDead; i < cards.length; i++) i]);
  return Rows(rows);
}

double _needGap(SizedCard a, SizedCard b) =>
    a.reachRight + b.reachLeft + a.lean.width + b.lean.width + EndMetrics.clear;

/// A row's cards across the board: where each card's left lies and the column
/// (slot) it keeps its strand in.
class RowPlace {
  const RowPlace(this.lefts, this.columns);

  final List<double> lefts;
  final List<Rect> columns;
}

RowPlace rowPositions(
  Rows rows,
  int r,
  List<SizedCard> cards,
  double boardWidth,
) {
  final row = rows.rows[r];
  final span = spanOf(r, boardWidth);
  if (row.length == 1) {
    final c = cards[row[0]];
    return RowPlace([span.center.dx - c.width / 2], [span]);
  }
  final half = span.width / 2;
  final colA = Rect.fromLTWH(span.left, 0, half, 0);
  final colB = Rect.fromLTWH(span.left + half, 0, half, 0);
  final a = cards[row[0]], b = cards[row[1]];
  var la = colA.center.dx - a.width / 2;
  var lb = colB.center.dx - b.width / 2;
  final gap = lb - (la + a.width);
  final deficit = _needGap(a, b) - gap;
  if (deficit > 0) {
    final roomA = math.max(0.0, la - (colA.left + EndMetrics.clear));
    final roomB = math.max(0.0, colB.right - EndMetrics.clear - (lb + b.width));
    final sa = math.min(deficit / 2, roomA);
    final sb = math.min(deficit - sa, roomB);
    la -= math.min(roomA, sa + math.max(0.0, deficit - sa - sb));
    lb += sb;
  }
  return RowPlace([la, lb], [colA, colB]);
}

/// Where each row's cards begin (their top, before the jitter) and how tall
/// the whole board's content is.
class RowTops {
  const RowTops(this.tops, this.heights, this.contentHeight);

  final List<double> tops;

  /// The tallest card of each row.
  final List<double> heights;
  final double contentHeight;
}

/// Air above a row: each card keeps [EndMetrics.gap] under whatever stands
/// above it, and what it holds up (its dealt card at the top left, its ribbon
/// at the top right) keeps [EndMetrics.hangClear] under whatever stands above
/// that, not under the whole row: a ribbon beside an empty corner needs no
/// room. Under a row: room for the longest strand of tags in it.
RowTops rowTopsOf(Rows rows, List<SizedCard> cards, double boardWidth) {
  final tops = <double>[];
  final heights = <double>[];
  // What stands on the board so far: its width across and how low it reaches.
  final floors = <(double, double, double)>[
    (0, boardWidth, EndMetrics.insetTop - EndMetrics.gap),
    // The lantern hangs from the top right.
    (
      boardWidth - EndMetrics.lanternLeftFromRight + 8,
      boardWidth,
      EndMetrics.lanternTop + EndMetrics.lanternSize.height,
    ),
  ];
  double floorUnder(double from, double to) {
    var low = 0.0;
    for (final (a, b, bottom) in floors) {
      if (a < to + EndMetrics.clear && b > from - EndMetrics.clear) {
        low = math.max(low, bottom);
      }
    }
    return low;
  }

  for (var r = 0; r < rows.rows.length; r++) {
    final row = rows.rows[r];
    final at = rowPositions(rows, r, cards, boardWidth);
    var top = tops.isEmpty ? 0.0 : tops.last + 1;
    for (var i = 0; i < row.length; i++) {
      final c = cards[row[i]];
      final left = at.lefts[i], right = left + c.width;
      final lean = c.lean;
      top = math.max(
        top,
        floorUnder(left - lean.width, right + lean.width) +
            EndMetrics.gap +
            lean.height,
      );
      if (c.dealt) {
        final dw = EndMetrics.dealtWidth(c.pw);
        final up = EndMetrics.dealtOutY * dw * EndMetrics.dealtRatio;
        top = math.max(
          top,
          floorUnder(
                left - EndMetrics.dealtOutX * dw - lean.width,
                left + (1 - EndMetrics.dealtOutX) * dw,
              ) +
              up +
              EndMetrics.hangClear +
              lean.height,
        );
      }
      if (c.hanged) {
        final rw = EndMetrics.ribbonWidth(c.pw);
        final up = EndMetrics.ribbonHeight(rw) * (1 - EndMetrics.ribbonInside);
        top = math.max(
          top,
          floorUnder(
                right - EndMetrics.ribbonInside * rw,
                right + (1 - EndMetrics.ribbonInside) * rw + lean.width,
              ) +
              up +
              EndMetrics.hangClear +
              lean.height,
        );
      }
    }
    tops.add(top);
    heights.add(row.map((i) => cards[i].height).fold(0.0, math.max));
    // A wide strand hangs from under the row's lowest card.
    final body = row
        .map((i) => cards[i].height + cards[i].lean.height)
        .fold(0.0, math.max);
    for (var i = 0; i < row.length; i++) {
      final c = cards[row[i]];
      final left = at.lefts[i], right = left + c.width;
      floors.add((
        left - c.reachLeft - c.lean.width,
        right + c.reachRight + c.lean.width,
        top + c.height + c.lean.height,
      ));
      if (c.hasTags) {
        final column = c.wideStrand ? spanOf(r, boardWidth) : at.columns[i];
        floors.add((
          column.left,
          column.right,
          top +
              (c.wideStrand
                  ? body + c.under - c.lean.height
                  : c.height + c.under),
        ));
      }
    }
  }
  final bottom = floors.map((f) => f.$3).fold(0.0, math.max);
  // The last row's cards may sit lower by their jitter.
  return RowTops(
    tops,
    heights,
    bottom + EndMetrics.jitter + EndMetrics.insetBottom,
  );
}

/// When the board scrolls, the bottom edge must cut a card (not fall between
/// two rows), so it says "more below" without words: the first row that is not
/// whole above [seen] is moved down until the edge cuts it. Moves [tops] and
/// returns how much taller the board became.
double cutByTheEdge(
  List<double> tops,
  Rows rows,
  List<SizedCard> cards,
  double seen,
) {
  double card(int r) =>
      rows.rows[r].map((i) => cards[i].height).fold(0.0, math.max);
  double extent(int r) => rows.rows[r]
      .map((i) => cards[i].height + cards[i].under)
      .fold(0.0, math.max);
  bool cuts(double top, double height) =>
      top < seen - EndMetrics.clear - 2 && top + height > seen + 4;
  // A card of the row, or a tag of its strands, lies across the edge.
  bool straddles(int r) {
    for (final i in rows.rows[r]) {
      final c = cards[i];
      if (cuts(tops[r], c.height)) return true;
      final rowsOfTags = (c.tagNames.length / c.tagColumns).ceil();
      for (var t = 0; t < rowsOfTags; t++) {
        final top =
            tops[r] +
            c.height +
            c.lean.height +
            EndMetrics.tagFirst +
            (c.tagHeight + EndMetrics.tagGap) * t;
        if (cuts(top, c.tagHeight)) return true;
      }
    }
    return false;
  }

  for (var r = 0; r < tops.length; r++) {
    if (tops[r] + extent(r) <= seen - EndMetrics.clear) continue;
    if (straddles(r)) return 0;
    // Row r is not cut: either it begins under the edge (the row before is the
    // one to cut) or the edge falls between its card and its tags.
    final k = tops[r] + EndMetrics.clear >= seen && r > 0 ? r - 1 : r;
    final extra = seen - EndMetrics.cutShows * card(k) - tops[k];
    if (extra <= 0) return 0;
    for (var i = k; i < tops.length; i++) {
      tops[i] += extra;
    }
    return extra;
  }
  return 0;
}

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

void _swap(List<int> q, int i, int j) {
  final t = q[i];
  q[i] = q[j];
  q[j] = t;
}
