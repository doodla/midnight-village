import 'dart:math' as math;
import 'dart:ui';

import '../../../design_system/models/game_result.dart';
import '../../../design_system/models/role.dart';
import '../../../design_system/skin/art_set.dart' show TokenId;
import 'end_banner.dart';
import 'end_board_metrics.dart';
import 'end_board_rows.dart';
import 'game_outcome.dart';
import 'outcome_view.dart';

// The end board's layout (the end-board SPEC, section 3), pure: from the
// results body, who "you" are and the size of the screen, to where every card,
// tag, ribbon and seal lies, in the board's own coordinates (0,0 is its top
// left). Computed once: night faces, hidden tags and the reveal never move a
// card. Nothing here draws; `presentation/end/` does, from this plan.
//
// What it decides: the order (living winners, living losers, the dead), rows
// of two, a name too long for its slot alone on its row, sizes (a winner's
// portrait 90, a loser's 64; up to 1.3 times with five players or fewer while
// it still fits; never smaller), the air above and below each row, the
// seeded tilt, where each vote tag hangs, the Hunter's pick, the centre cards,
// the banner's sentences, and whether the board scrolls (and then, that a
// card is cut by the bottom edge).

/// Which paper a card is cut from.
enum EndCardLook { winner, loser, werewolfWon, werewolfLost }

/// A vote tag: [voterId] voted for the card it hangs under.
class EndTag {
  const EndTag({
    required this.voterId,
    required this.name,
    required this.token,
    required this.rect,
  });

  final int voterId;
  final String name;
  final TokenId? token;
  final Rect rect;
}

/// One player's card on the board.
class EndCard {
  const EndCard({
    required this.id,
    required this.name,
    required this.token,
    required this.row,
    required this.look,
    required this.face,
    required this.strip,
    required this.dealt,
    required this.won,
    required this.hanged,
    required this.pickedByHunter,
    required this.you,
    required this.lit,
    required this.rect,
    required this.portraitWidth,
    required this.angle,
    required this.column,
    required this.tags,
    required this.pin,
    required this.dealtRect,
    required this.ribbonRect,
    required this.sealRect,
    required this.header,
    required this.stripHeight,
  });

  final int id;
  final String name;
  final TokenId? token;
  final int row;
  final EndCardLook look;

  /// The portrait: the final role, or the role a Doppelganger copied.
  final RoleId face;

  /// The role on the strip: the final role; "Doppelganger" for a Doppelganger.
  final RoleId strip;

  /// The role dealt, when it is not the one at the end.
  final RoleId? dealt;
  final bool won;

  /// Dead (by the vote or by the Hunter): the ribbon.
  final bool hanged;
  final bool pickedByHunter;
  final bool you;

  /// A living winner: in the lantern's pool.
  final bool lit;

  /// The card, upright, jitter included.
  final Rect rect;
  final double portraitWidth;
  final double angle;

  /// The room across the board the card and its strand have: its slot.
  final Rect column;
  final List<EndTag> tags;
  final Rect? pin;
  final Rect? dealtRect;
  final Rect? ribbonRect;
  final Rect? sealRect;

  /// How tall the name's header and the role's strip are on this phone.
  final double header;
  final double stripHeight;

  Rect get nameRect => Rect.fromLTWH(rect.left, rect.top, rect.width, header);

  /// Where the name's letters lie: the header less its room each side. A
  /// ribbon pinned to the corner may lie over the header's end, never this.
  Rect get nameText => Rect.fromLTWH(
    rect.left + EndMetrics.nameRoom / 2,
    rect.top,
    math.max(0.0, rect.width - EndMetrics.nameRoom),
    header,
  );

  Rect get portrait => Rect.fromLTWH(
    rect.left + (rect.width - portraitWidth) / 2,
    rect.top + header,
    portraitWidth,
    EndMetrics.portraitHeight(portraitWidth),
  );

  /// The card as it lies tilted, as a box.
  Rect get leaned => rect.inflate(EndMetrics.tiltReach);

  /// Everything of this card: the card, what is pinned to it and its strand.
  Rect get reach {
    var r = leaned;
    for (final part in [dealtRect, ribbonRect, sealRect, pin]) {
      if (part != null) r = r.expandToInclude(part);
    }
    for (final tag in tags) {
      r = r.expandToInclude(tag.rect);
    }
    return r;
  }
}

/// The Hunter's second death: a red twine from [hunter] to [pick] and a slip
/// hung under it.
class EndPick {
  const EndPick({
    required this.hunterId,
    required this.pickId,
    required this.hunterName,
    required this.slip,
  });

  final int hunterId;
  final int pickId;
  final String hunterName;
  final Rect slip;
}

/// The foot, by who this phone is.
class EndFoot {
  const EndFoot({
    required this.host,
    required this.whatHappened,
    required this.hostName,
  });

  /// The host: "Edit deck" and "Play again"; a guest: "Leave".
  final bool host;

  /// There is a night to replay (the results carry its timeline).
  final bool whatHappened;

  /// A guest's "{host} deals next.": null when the host is not at the table.
  final String? hostName;
}

/// The whole settled board for one phone.
class EndBoardPlan {
  const EndBoardPlan({
    required this.banner,
    required this.bannerLines,
    required this.cards,
    required this.rows,
    required this.pick,
    required this.centre,
    required this.foot,
    required this.screen,
    required this.boardWidth,
    required this.boardTop,
    required this.viewHeight,
    required this.boardHeight,
    required this.scrolls,
    required this.growth,
    required this.lantern,
    required this.light,
    required this.nobodyHanged,
  });

  final EndBanner banner;
  final int bannerLines;

  /// In the order they are laid out: the living winners, the living losers,
  /// the dead (the vote's, then the Hunter's pick).
  final List<EndCard> cards;

  /// Indexes into [cards], a row each, left to right.
  final List<List<int>> rows;
  final EndPick? pick;

  /// The three cards nobody held, as they ended.
  final List<RoleId> centre;
  final EndFoot foot;
  final Size screen;
  final double boardWidth;

  /// Where the board's top lies on the screen.
  final double boardTop;

  /// The height of the board's window: from [boardTop] to the foot's top.
  final double viewHeight;

  /// The board's own height: [viewHeight] when it fits, taller when it scrolls.
  final double boardHeight;
  final bool scrolls;

  /// How much the cards grew (1 to 1.3).
  final double growth;
  final Rect lantern;
  final Offset light;
  final bool nobodyHanged;

  EndCard card(int id) => cards.firstWhere((c) => c.id == id);

  /// What a card's winners are lit by: the living winners.
  Iterable<EndCard> get pool => cards.where((c) => c.lit);

  /// How much of the board is under the foot's lip at scroll 0.
  double get seenAtTop => viewHeight - EndMetrics.lip;
}

/// The board for [viewerId] of [outcome] on a screen of [screen]. [bannerLines]
/// is how many lines the banner took (a third pushes the board down).
/// [measure] sets a text at this phone's size.
EndBoardPlan planEndBoard({
  required GameOutcome outcome,
  required int viewerId,
  required bool isHost,
  required String? hostName,
  required Size screen,
  required int bannerLines,
  required EndMeasure measure,
  double nameLine = 17.6,
  double roleLine = 14.4,
}) {
  final seats = endSeatsOf(outcome);
  final banner = endBannerOf(outcome, viewerId);
  final deaths = deathsOf(seats);
  final nobody = deaths.nobody;
  final boardWidth = screen.width - EndMetrics.boardMargin;
  final boardTop =
      EndMetrics.boardTop +
      (bannerLines > 2 ? EndMetrics.bannerExtra * (bannerLines - 2) : 0);
  final view = math.max(0.0, screen.height - EndMetrics.foot - boardTop);

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

  // Who the Hunter took, and by whom.
  final chosen = deaths.chosen.firstOrNull;
  final hunter = chosen == null
      ? null
      : deaths.voted
            .where(
              (s) => s.plays == RoleId.hunter && s.votedFor == chosen.seat.id,
            )
            .firstOrNull;

  Iterable<EndSeat> votersOf(EndSeat s) =>
      seats.where((v) => v.votedFor == s.seat.id);
  bool tagged(EndSeat s) => nobody || s.diedBy == EliminationReason.vote;

  List<SizedCard> sized(double growth) => [
    for (final s in order)
      sizeCard(
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
        measure: measure,
      ),
  ];

  // Grow while it still fits (five players or fewer); never shrink.
  var growth = 1.0;
  Rows rows;
  var cards = sized(growth);
  rows = packRows(cards, boardWidth, firstDead);
  var rowTops = rowTopsOf(rows, cards, boardWidth);
  if (seats.length <= EndMetrics.growsUpTo) {
    for (
      var g = EndMetrics.mostGrowth;
      g > 1 + 1e-9;
      g -= EndMetrics.growthStep
    ) {
      final c = sized(g);
      final r = packRows(c, boardWidth, firstDead);
      final t = rowTopsOf(r, c, boardWidth);
      if (t.contentHeight <= view && _sameRows(r.rows, rows.rows)) {
        growth = g;
        cards = c;
        rows = r;
        rowTops = t;
        break;
      }
    }
  }

  final scrolls = rowTops.contentHeight > view;
  final tops = [...rowTops.tops];
  var content = rowTops.contentHeight;
  if (scrolls) {
    content += cutByTheEdge(tops, rows, cards, view - EndMetrics.lip);
  } else {
    // Spare height is shared evenly between the rows.
    final spare = view - content;
    final each = spare / rows.rows.length;
    for (var r = 1; r < tops.length; r++) {
      tops[r] += each * r;
    }
  }

  final lantern = Rect.fromLTWH(
    boardWidth - EndMetrics.lanternLeftFromRight,
    EndMetrics.lanternTop,
    EndMetrics.lanternSize.width,
    EndMetrics.lanternSize.height,
  );
  // The light is the centre of the lantern's panes (`EndArt.lanternLight`).
  final light = Offset(
    lantern.left + 0.41 * lantern.width,
    lantern.top + 0.755 * lantern.height,
  );

  final placed = <EndCard>[];
  for (var r = 0; r < rows.rows.length; r++) {
    final row = rows.rows[r];
    final xs = rowPositions(rows, r, cards, boardWidth);
    for (var i = 0; i < row.length; i++) {
      final index = row[i];
      final c = cards[index];
      final s = order[index];
      final top = tops[r] + EndMetrics.jitterOf(c.id);
      final rect = Rect.fromLTWH(xs.lefts[i], top, c.width, c.height);
      final tagList = <EndTag>[];
      final names = c.tagNames;
      final voters = tagged(s) ? votersOf(s).toList() : <EndSeat>[];
      for (var t = 0; t < voters.length; t++) {
        final width = math.min(
          EndMetrics.tagApron + measure(EndText.tag, names[t]),
          xs.columns[i].width - 2 * EndMetrics.clear,
        );
        final natural =
            rect.left + EndMetrics.tagRoom / 4 - EndMetrics.tagStagger * t;
        final left = natural
            .clamp(
              xs.columns[i].left + EndMetrics.clear,
              math.max(
                xs.columns[i].left + EndMetrics.clear,
                xs.columns[i].right - EndMetrics.clear - width,
              ),
            )
            .toDouble();
        tagList.add(
          EndTag(
            voterId: voters[t].seat.id,
            name: voters[t].seat.name,
            token: voters[t].seat.token,
            rect: Rect.fromLTWH(
              left,
              rect.bottom + EndMetrics.tagFirst + EndMetrics.tagStep * t,
              width,
              EndMetrics.tagHeight,
            ),
          ),
        );
      }
      final dw = EndMetrics.dealtWidth(c.pw);
      final dh = dw * EndMetrics.dealtRatio;
      final rw = EndMetrics.ribbonWidth(c.pw);
      final rh = EndMetrics.ribbonHeight(rw);
      placed.add(
        EndCard(
          id: c.id,
          name: s.seat.name,
          token: s.seat.token,
          row: r,
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
          column: xs.columns[i],
          tags: tagList,
          pin: tagList.isEmpty
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
        ),
      );
    }
  }
  // Back in the order of [order] (rows are in it already, left to right).
  final byId = {for (final c in placed) c.id: c};
  final cardsInOrder = [for (final s in order) byId[s.seat.id]!];

  EndPick? pick;
  if (hunter != null && chosen != null) {
    pick = EndPick(
      hunterId: hunter.seat.id,
      pickId: chosen.seat.id,
      hunterName: hunter.seat.name,
      slip: placeSlip(
        from: byId[hunter.seat.id]!,
        to: byId[chosen.seat.id]!,
        all: cardsInOrder,
        boardWidth: boardWidth,
        width: measure(EndText.slip, '${hunter.seat.name}\'s pick'),
      ),
    );
  }

  return EndBoardPlan(
    banner: banner,
    bannerLines: bannerLines,
    cards: cardsInOrder,
    rows: [
      for (final row in rows.rows)
        [
          for (final i in row)
            cardsInOrder.indexWhere((c) => c.id == cards[i].id),
        ],
    ],
    pick: pick,
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
    boardHeight: scrolls ? content : view,
    scrolls: scrolls,
    growth: growth,
    lantern: lantern,
    light: light,
    nobodyHanged: nobody,
  );
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
