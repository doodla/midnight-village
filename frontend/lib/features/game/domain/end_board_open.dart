import 'dart:math' as math;
import 'dart:ui';

import 'end_board_cards.dart';
import 'end_board_metrics.dart';

// Where a board that scrolls opens (docs/specs/frontend/end-board.md, section
// 3, rule 9), once every card is placed. Pure arithmetic on rectangles.

/// The scroll a board that scrolls opens at. Opened down the board at all,
/// the eave cuts a card, at least [EndMetrics.cutLeast] of it showing, as the
/// lip cuts one below: more above. Within that, the most it can show whole
/// above the foot's lip: the hanged and the viewer's own card; else the
/// hanged with what hangs on them; else the hanged's cards (their tags going
/// under the lip); else the vote's dead (the Hunter's pick further down). 0
/// when they are in view at the top.
double openingOf(
  List<EndCard> cards,
  int viewerId,
  double view,
  double boardHeight,
) {
  final hanged = [
    for (final c in cards)
      if (c.hanged) c,
  ];
  if (hanged.isEmpty) return 0;
  final seen = view - EndMetrics.lip;
  final most = math.max(0.0, boardHeight - view);
  // The scrolls that show [boxes] whole: from [lo] to [hi].
  ({double lo, double hi}) range(Iterable<Rect> boxes) => (
    lo:
        boxes.map((r) => r.bottom).fold(0.0, math.max) +
        EndMetrics.clear -
        seen,
    hi:
        boxes.map((r) => r.top).fold(double.infinity, math.min) -
        EndMetrics.clear,
  );
  final you = [
    for (final c in cards)
      if (c.id == viewerId)
        c.sealRect == null ? c.leaned : c.leaned.expandToInclude(c.sealRect!),
  ];
  // The least scroll from [from] to [to] (the most, [last]) at which the eave
  // cuts a card, enough of it showing to read as a card.
  double? cutFrom(double from, double to, {bool last = false}) {
    double? best;
    for (final c in cards) {
      final a = math.max(from, c.leaned.top + 2);
      final b = math.min(to, c.leaned.bottom - EndMetrics.cutLeast);
      if (a > b) continue;
      final s = last ? b : a;
      if (best == null || (last ? s > best : s < best)) best = s;
    }
    return best;
  }

  // What to show, most first: the hanged with all that hangs on them and you;
  // the hanged with all that hangs on them; the hanged's cards; the vote's
  // dead with their tags; the vote's dead's cards.
  final voted = hanged.where((c) => !c.pickedByHunter);
  final ranges = [
    range([...hanged.map((c) => c.reach), ...you]),
    range(hanged.map((c) => c.reach)),
    range(hanged.map((c) => c.leaned)),
    range(voted.map((c) => c.reach)),
    range(voted.map((c) => c.leaned)),
  ];
  for (final (:lo, :hi) in ranges) {
    final from = math.max(0.0, lo), to = math.min(hi, most);
    if (from > to + 1e-9) continue;
    // In view at the top: nothing above.
    if (from <= 0) return 0;
    if (cutFrom(from, to) case final s?) return s;
  }
  // Nothing shows them whole with a card cut above: the vote's first dead as
  // high as a cut lets them stand (or the top).
  final first = voted.isEmpty ? hanged.first : voted.first;
  final to = math.min(first.leaned.top - EndMetrics.clear, most);
  return cutFrom(0, to, last: true) ?? 0;
}
