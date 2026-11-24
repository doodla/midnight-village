import 'dart:math' as math;
import 'dart:ui';

import 'end_board_metrics.dart';

part 'end_board_card_size.dart';

// The packing under `planEndBoard` (docs/specs/frontend/end-board.md, section
// 3, rules 2, 3, 5 and 9): what a card needs, which cards share a row, how
// high each row stands, and how a board of six or fewer closes up. Pure
// arithmetic on numbers and rectangles.

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

/// [slides] moves a card (by its index) along its slot, to the right
/// (`EndFit.slide`).
RowPlace rowPositions(
  Rows rows,
  int r,
  List<SizedCard> cards,
  double boardWidth, {
  Map<int, double> slides = const {},
}) {
  final at = _centred(rows, r, cards, boardWidth);
  final row = rows.rows[r];
  if (!row.any(slides.containsKey)) return at;
  return RowPlace([
    for (var i = 0; i < row.length; i++) at.lefts[i] + (slides[row[i]] ?? 0),
  ], at.columns);
}

RowPlace _centred(Rows rows, int r, List<SizedCard> cards, double boardWidth) {
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

/// Air above a row: each card keeps [EndFit.gap] under whatever stands above
/// it, and what it holds up (its dealt card at the top left, its ribbon at the
/// top right) keeps [EndFit.hangClear] under whatever stands above that, not
/// under the whole row: a ribbon beside an empty corner needs no room. Under
/// a row: room for the longest strand of tags in it. With [EndFit.slide] a
/// card's foot is only as wide as the card (what it holds up and its seal
/// never reach it), and a hanged card slides along its slot, as far as the
/// card beside it and the board's edge let it, while that brings its row up;
/// each slide is written into [slides].
RowTops rowTopsOf(
  Rows rows,
  List<SizedCard> cards,
  double boardWidth, {
  EndFit fit = EndFit.loose,
  Map<int, double>? slides,
}) {
  final slid = slides ?? <int, double>{};
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

  // How high the row [row] may stand with its cards at [at].
  double topOf(List<int> row, RowPlace at) {
    var top = tops.isEmpty ? 0.0 : tops.last + 1;
    for (var i = 0; i < row.length; i++) {
      final c = cards[row[i]];
      final left = at.lefts[i], right = left + c.width;
      final lean = c.lean;
      top = math.max(
        top,
        floorUnder(left - lean.width, right + lean.width) +
            fit.gap +
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
              fit.hangClear +
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
              fit.hangClear +
              lean.height,
        );
      }
    }
    return top;
  }

  for (var r = 0; r < rows.rows.length; r++) {
    final row = rows.rows[r];
    var at = rowPositions(rows, r, cards, boardWidth);
    var top = topOf(row, at);
    if (fit.slide && row.any((i) => cards[i].hanged)) {
      // Each hanged card as far right as it may go: the card beside it keeps
      // its gap, its ribbon stays on the board.
      final most = [
        for (var i = 0; i < row.length; i++)
          if (!cards[row[i]].hanged)
            0.0
          else
            math.max(
              0.0,
              math.min(
                boardWidth -
                    EndMetrics.clear -
                    (at.lefts[i] +
                        cards[row[i]].width +
                        cards[row[i]].reachRight +
                        cards[row[i]].lean.width),
                i + 1 < row.length
                    ? at.lefts[i + 1] -
                          (at.lefts[i] + cards[row[i]].width) -
                          _needGap(cards[row[i]], cards[row[i + 1]])
                    : double.infinity,
              ),
            ),
      ];
      // The least slides that bring the row highest.
      var best = (top, 0.0, [for (final _ in row) 0.0]);
      void tryAt(List<double> dx) {
        final moved = RowPlace([
          for (var i = 0; i < row.length; i++) at.lefts[i] + dx[i],
        ], at.columns);
        final t = topOf(row, moved);
        final cost = dx.fold(0.0, (a, b) => a + b);
        if (t < best.$1 - 0.01 || (t < best.$1 + 0.01 && cost < best.$2)) {
          best = (t, cost, [...dx]);
        }
      }

      for (var d0 = 0.0; d0 <= most[0] + 1e-9; d0 += 1) {
        if (row.length == 1) {
          tryAt([d0]);
          continue;
        }
        for (var d1 = 0.0; d1 <= most[1] + 1e-9; d1 += 1) {
          tryAt([d0, d1]);
        }
      }
      for (var i = 0; i < row.length; i++) {
        if (best.$3[i] > 0) slid[row[i]] = best.$3[i];
      }
      at = rowPositions(rows, r, cards, boardWidth, slides: slid);
      top = best.$1;
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
        left - (fit.slide ? 0 : c.reachLeft) - c.lean.width,
        right + (fit.slide ? 0 : c.reachRight) + c.lean.width,
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

void _swap(List<int> q, int i, int j) {
  final t = q[i];
  q[i] = q[j];
  q[j] = t;
}
