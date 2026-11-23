import 'dart:math' as math;
import 'dart:ui';

import '../../../design_system/copy/copy.dart';
import '../../../design_system/models/game_result.dart';
import '../../../design_system/models/role.dart';
import '../../../design_system/skin/end_art.dart' show EndArt;
import 'end_banner.dart';
import 'end_board_cards.dart';
import 'end_board_metrics.dart';
import 'end_board_rows.dart';
import 'game_outcome.dart';
import 'outcome_view.dart';

export 'end_board_cards.dart';

// The end board's layout (docs/specs/frontend/end-board.md, section 3), pure:
// from the results body, who "you" are, the size of the screen and the words
// measured at the phone's text size, to where every card, tag, ribbon and seal
// lies, in the board's own coordinates (0,0 is its top left). Computed once:
// night faces, hidden tags and the reveal never move a card. Nothing here
// draws; `presentation/end/` does, from this plan.
//
// What it decides: the order (living winners, living losers, the dead), rows
// of two, a name too long for its slot alone on its row, sizes (a winner's
// portrait 90, a loser's 64; with five players or fewer each row grows up to
// 1.3 times while it keeps its cards and the board still fits; never
// smaller), the air above and below each row (a small group stands centred),
// the seeded tilt and how far it really leans, where each vote tag hangs (in
// two columns past three, when two fit), the Hunter's picks, the centre cards,
// whether the board scrolls (and then, that a card is cut by the bottom edge)
// and where it stands scrolled when it opens (the hanged in view).

/// The board for [viewerId] of [outcome] on a screen of [screen], its frame
/// beginning [boardTop] down the screen and its window [viewHeight] tall (to
/// the foot's top). [measure] sets a text at this phone's size; [nameLine] and
/// [roleLine] are how tall a line of a name and of a role are at it.
EndBoardPlan planEndBoard({
  required GameOutcome outcome,
  required int viewerId,
  required bool isHost,
  required String? hostName,
  required Size screen,
  required double boardTop,
  required double viewHeight,
  required EndMeasure measure,
  double nameLine = 17.6,
  double roleLine = 14.4,
}) {
  final seats = endSeatsOf(outcome);
  final banner = endBannerOf(outcome, viewerId);
  final deaths = deathsOf(seats);
  final nobody = deaths.nobody;
  final boardWidth = screen.width - EndMetrics.boardMargin;
  final view = math.max(0.0, viewHeight);
  final tagHeight = EndMetrics.tagHeightFor(nameLine);
  final slot = (boardWidth - 2 * EndMetrics.insetX) / 2 - 2 * EndMetrics.clear;

  // The order: living winners, living losers, then the dead.
  final living = [
    for (final s in seats)
      if (!s.died && s.won) s,
    for (final s in seats)
      if (!s.died && !s.won) s,
  ];
  final dead = deaths.all;
  // A single living card joins the dead in the last row, the dead on the left.
  if (living.length.isOdd && dead.isNotEmpty) dead.add(living.removeLast());
  final firstDead = living.length;
  final order = [...living, ...dead];

  // Who each Hunter took: the vote's dead Hunter whose vote was for them.
  final hunters = <(EndSeat, EndSeat)>[
    for (final chosen in deaths.chosen)
      for (final hunter in deaths.voted.where(
        (s) => s.plays == RoleId.hunter && s.votedFor == chosen.seat.id,
      ))
        (hunter, chosen),
  ];

  Iterable<EndSeat> votersOf(EndSeat s) =>
      seats.where((v) => v.votedFor == s.seat.id);
  bool tagged(EndSeat s) => nobody || s.diedBy == EliminationReason.vote;

  // A card with more than three tags beside one with none hangs its strand
  // across the whole row (set once the rows are known), unless the other is
  // the Hunter's pick.
  final wide = <int>{};
  SizedCard sized(int index, double growth) {
    final s = order[index];
    final isWide = wide.contains(index);
    return sizeCard(
      id: s.seat.id,
      pw:
          (s.won ? EndMetrics.winnerPortrait : EndMetrics.loserPortrait) *
          growth,
      name: s.seat.name,
      stripWords: [
        _roleWords(s.copied != null ? RoleId.doppelganger : s.now),
        if (s.moved) _roleWords(s.dealt),
      ],
      tagNames: tagged(s) ? [for (final v in votersOf(s)) v.seat.name] : [],
      dealt: s.moved,
      you: s.seat.id == viewerId,
      hanged: s.died,
      maxWidth: boardWidth - 2 * EndMetrics.insetX - 2 * EndMetrics.clear,
      header: EndMetrics.headerFor(nameLine),
      tagHeight: tagHeight,
      angle: EndMetrics.angleOf(s.seat.id, hanged: s.died),
      slot: isWide ? slot * 2 + 2 * EndMetrics.clear : slot,
      wideStrand: isWide,
      measure: measure,
    );
  }

  List<SizedCard> sizedAll(List<double> growths) => [
    for (var i = 0; i < order.length; i++) sized(i, growths[i]),
  ];

  // Sizes are fixed; with five or fewer each row grows as far as its own room
  // lets it (the first stops at the lantern), then all of them less until the
  // board fits its window. Never smaller.
  final growths = List.filled(order.length, 1.0);
  var cards = sizedAll(growths);
  final rows = packRows(cards, boardWidth, firstDead);
  for (final row in rows.rows) {
    // A card alone on its row has the row's width for its strand.
    if (row.length == 1 &&
        cards[row.first].tagNames.length > EndMetrics.tagsInOneColumn) {
      wide.add(row.first);
    }
    if (row.length != 2) continue;
    final [a, b] = row;
    // Not beside the Hunter's pick: the slip hangs between those two.
    if (row.any((i) => order[i].diedBy == EliminationReason.hunterChain)) {
      continue;
    }
    final many = cards[a].tagNames.length > EndMetrics.tagsInOneColumn;
    final manyB = cards[b].tagNames.length > EndMetrics.tagsInOneColumn;
    if (many && cards[b].tagNames.isEmpty) wide.add(a);
    if (manyB && cards[a].tagNames.isEmpty) wide.add(b);
  }
  if (wide.isNotEmpty) cards = sizedAll(growths);
  if (seats.length <= EndMetrics.growsUpTo) {
    final most = List.filled(order.length, 1.0);
    for (final row in rows.rows) {
      for (
        var g = EndMetrics.mostGrowth;
        g > 1 + 1e-9;
        g -= EndMetrics.growthStep
      ) {
        final trial = [...most];
        for (final i in row) {
          trial[i] = g;
        }
        final c = sizedAll(trial);
        if (_sameRows(packRows(c, boardWidth, firstDead).rows, rows.rows)) {
          for (final i in row) {
            most[i] = g;
          }
          break;
        }
      }
    }
    for (var k = 1.0; k > 1e-9; k -= 0.05) {
      final trial = [for (final g in most) 1 + (g - 1) * k];
      final c = sizedAll(trial);
      if (rowTopsOf(rows, c, boardWidth).contentHeight <= view) {
        growths.setAll(0, trial);
        cards = c;
        break;
      }
    }
  }
  final rowTops = rowTopsOf(rows, cards, boardWidth);

  final scrolls = rowTops.contentHeight > view + 0.01;
  final tops = [...rowTops.tops];
  var content = rowTops.contentHeight;
  if (scrolls) {
    content += cutByTheEdge(tops, rows, cards, view - EndMetrics.lip);
  } else {
    // Spare height is shared between the rows, up to a point; what is left
    // goes above and below, so a small group stands centred.
    final spare = view - content;
    final n = rows.rows.length;
    final each = math.min(spare / n, EndMetrics.mostSpare);
    final offset = (spare - each * (n - 1)) / 2;
    for (var r = 0; r < tops.length; r++) {
      tops[r] += each * r + offset;
    }
  }

  final lantern = Rect.fromLTWH(
    boardWidth - EndMetrics.lanternLeftFromRight,
    EndMetrics.lanternTop,
    EndMetrics.lanternSize.width,
    EndMetrics.lanternSize.height,
  );
  // The light is the centre of the lantern's panes.
  final light = Offset(
    lantern.left + EndArt.lanternLight.dx * lantern.width,
    lantern.top + EndArt.lanternLight.dy * lantern.height,
  );

  final placed = <EndCard>[];
  for (var r = 0; r < rows.rows.length; r++) {
    final row = rows.rows[r];
    final xs = rowPositions(rows, r, cards, boardWidth);
    for (var i = 0; i < row.length; i++) {
      final c = cards[row[i]];
      final s = order[row[i]];
      final top = tops[r] + EndMetrics.jitterOf(c.id);
      final rect = Rect.fromLTWH(xs.lefts[i], top, c.width, c.height);
      final lowest = [
        for (final j in row)
          tops[r] +
              EndMetrics.jitterOf(cards[j].id) +
              cards[j].height +
              cards[j].lean.height,
      ].fold(0.0, math.max);
      final tagList = _tags(
        voters: tagged(s) ? votersOf(s).toList() : const [],
        card: c,
        rect: rect,
        column: c.wideStrand ? spanOf(r, boardWidth) : xs.columns[i],
        from: c.wideStrand ? lowest : rect.bottom + c.lean.height,
        measure: measure,
      );
      placed.add(
        _card(
          s,
          c,
          r,
          rect,
          c.wideStrand ? spanOf(r, boardWidth) : xs.columns[i],
          tagList,
          roleLine: roleLine,
        ),
      );
    }
  }
  // Back in the order of [order] (rows are in it already, left to right).
  final byId = {for (final c in placed) c.id: c};
  final cardsInOrder = [for (final s in order) byId[s.seat.id]!];

  final picks = [
    for (final (hunter, chosen) in hunters)
      EndPick(
        hunterId: hunter.seat.id,
        pickId: chosen.seat.id,
        hunterName: hunter.seat.name,
        slip: placeSlip(
          from: byId[hunter.seat.id]!,
          to: byId[chosen.seat.id]!,
          all: cardsInOrder,
          boardWidth: boardWidth,
          width: measure(
            EndText.slip,
            EndCopy.picked.fill({'hunter': hunter.seat.name}),
          ),
        ),
      ),
  ];

  final boardHeight = scrolls ? content : view;
  return EndBoardPlan(
    banner: banner,
    cards: cardsInOrder,
    rows: [
      for (final row in rows.rows)
        [
          for (final i in row)
            cardsInOrder.indexWhere((c) => c.id == cards[i].id),
        ],
    ],
    picks: picks,
    centre: outcome.result.centerCards,
    foot: EndFoot(
      host: isHost,
      whatHappened: outcome.timeline != null,
      hostName: hostName,
    ),
    screen: screen,
    boardWidth: boardWidth,
    boardTop: boardTop,
    viewHeight: view,
    boardHeight: boardHeight,
    scrolls: scrolls,
    growth: growths.fold(1.0, math.max),
    lantern: lantern,
    light: light,
    nobodyHanged: nobody,
    initialScroll: scrolls ? _hangedInView(cardsInOrder, view, boardHeight) : 0,
  );
}

/// One card placed at [rect], with what is pinned to it.
EndCard _card(
  EndSeat s,
  SizedCard c,
  int row,
  Rect rect,
  Rect column,
  List<EndTag> tags, {
  required double roleLine,
}) {
  final dw = EndMetrics.dealtWidth(c.pw);
  final dh = dw * EndMetrics.dealtRatio;
  final rw = EndMetrics.ribbonWidth(c.pw);
  final rh = EndMetrics.ribbonHeight(rw);
  return EndCard(
    id: c.id,
    name: s.seat.name,
    token: s.seat.token,
    row: row,
    look: _lookOf(s),
    face: s.plays,
    strip: s.copied != null ? RoleId.doppelganger : s.now,
    dealt: c.dealt ? s.dealt : null,
    won: s.won,
    hanged: s.died,
    pickedByHunter: s.diedBy == EliminationReason.hunterChain,
    you: c.you,
    lit: s.won && !s.died,
    rect: rect,
    portraitWidth: c.pw,
    angle: EndMetrics.angleOf(c.id, hanged: s.died),
    column: column,
    tags: tags,
    pin: tags.isEmpty
        ? null
        : Rect.fromLTWH(
            rect.left + EndMetrics.pinIn,
            rect.bottom - EndMetrics.pinUp,
            EndMetrics.pin,
            EndMetrics.pin,
          ),
    dealtRect: c.dealt
        ? Rect.fromLTWH(
            rect.left - EndMetrics.dealtOutX * dw,
            rect.top - EndMetrics.dealtOutY * dh,
            dw,
            dh,
          )
        : null,
    ribbonRect: s.died
        ? Rect.fromLTWH(
            rect.right - rw * EndMetrics.ribbonInside,
            rect.top - rh * (1 - EndMetrics.ribbonInside),
            rw,
            rh,
          )
        : null,
    header: c.header,
    stripHeight: EndMetrics.stripFor(roleLine),
    sealRect: c.you
        ? Rect.fromLTWH(
            rect.right + EndMetrics.sealHang - EndMetrics.seal,
            math.max(
              rect.top +
                  rect.height * EndMetrics.sealDown -
                  EndMetrics.seal / 2,
              // Below the name, whatever the card's height.
              rect.top + c.header + 1,
            ),
            EndMetrics.seal,
            EndMetrics.seal,
          )
        : null,
  );
}

/// Where the board opens scrolled so the hanged are in view: their cards and
/// what hangs on them above the foot's lip, or, when they are taller than the
/// window, their tops just under the eave. 0 when they are in view already.
double _hangedInView(List<EndCard> cards, double view, double boardHeight) {
  final hanged = [
    for (final c in cards)
      if (c.hanged) c.reach,
  ];
  if (hanged.isEmpty) return 0;
  final top = hanged.map((r) => r.top).fold(double.infinity, math.min);
  final bottom = hanged.map((r) => r.bottom).fold(0.0, math.max);
  final seen = view - EndMetrics.lip;
  final want = math.min(
    bottom + EndMetrics.clear - seen,
    top - EndMetrics.clear,
  );
  return want.clamp(0.0, math.max(0.0, boardHeight - view)).toDouble();
}

/// The tags of [voters] under a card at [rect]: one under the other from the
/// pin, a little to the left each; past three, in as many columns as fit its
/// [column]. Each keeps inside the column, clear of the next.
List<EndTag> _tags({
  required List<EndSeat> voters,
  required SizedCard card,
  required Rect rect,
  required Rect column,
  required double from,
  required EndMeasure measure,
}) {
  final room = column.width - 2 * EndMetrics.clear;
  final widths = [
    for (final v in voters)
      math.min(EndMetrics.tagApron + measure(EndText.tag, v.seat.name), room),
  ];
  final columns = card.tagColumns;
  final perColumn = math.max(1, (voters.length / columns).ceil());
  final widest = widths.fold(0.0, math.max);
  final band = columns * widest + (columns - 1) * EndMetrics.tagGap;
  final first = from + EndMetrics.tagFirst;
  final lo = column.left + EndMetrics.clear;
  final hi = math.max(lo, column.right - EndMetrics.clear - band);
  final tags = <EndTag>[];
  for (var t = 0; t < voters.length; t++) {
    final col = t ~/ perColumn;
    final down = t % perColumn;
    final natural =
        rect.left +
        EndMetrics.tagRoom / 4 -
        (columns == 1 ? EndMetrics.tagStagger * t : 0);
    final left = math.min(
      natural.clamp(lo, hi).toDouble() + col * (widest + EndMetrics.tagGap),
      column.right - EndMetrics.clear - widths[t],
    );
    tags.add(
      EndTag(
        voterId: voters[t].seat.id,
        name: voters[t].seat.name,
        token: voters[t].seat.token,
        column: col,
        rect: Rect.fromLTWH(
          math.max(lo, left),
          first + (card.tagHeight + EndMetrics.tagGap) * down,
          widths[t],
          card.tagHeight,
        ),
      ),
    );
  }
  return tags;
}

/// The words on a role's strip.
String _roleWords(RoleId role) => role.displayName;

EndCardLook _lookOf(EndSeat s) => s.team == TeamId.werewolf
    ? (s.won ? EndCardLook.werewolfWon : EndCardLook.werewolfLost)
    : (s.won ? EndCardLook.winner : EndCardLook.loser);

/// The same cards stand together in both.
bool _sameRows(List<List<int>> a, List<List<int>> b) {
  if (a.length != b.length) return false;
  for (var i = 0; i < a.length; i++) {
    if (a[i].length != b[i].length) return false;
    for (var j = 0; j < a[i].length; j++) {
      if (a[i][j] != b[i][j]) return false;
    }
  }
  return true;
}
