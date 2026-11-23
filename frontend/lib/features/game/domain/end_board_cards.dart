import 'dart:math' as math;
import 'dart:ui';

import '../../../design_system/models/role.dart';
import '../../../design_system/skin/art_set.dart' show TokenId;
import 'end_banner.dart';
import 'end_board_metrics.dart';

// What the end board's plan is made of (`planEndBoard` in `end_board.dart`):
// the cards, their tags, the Hunter's picks, the foot, the whole plan. Plain
// data, in the board's own coordinates (0,0 is its top left).

/// Which paper a card is cut from.
enum EndCardLook { winner, loser, werewolfWon, werewolfLost }

/// A vote tag: [voterId] voted for the card it hangs under.
class EndTag {
  const EndTag({
    required this.voterId,
    required this.name,
    required this.token,
    required this.rect,
    this.column = 0,
  });

  final int voterId;
  final String name;
  final TokenId? token;
  final Rect rect;

  /// Which of the strand's columns it hangs in (more than three: two).
  final int column;
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
    required this.nameWidth,
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

  /// The name and its room in the header: the least a card with it is wide.
  final double nameWidth;
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

  /// The card as it lies tilted, as a box: its corners turned for real.
  Rect get leaned => EndMetrics.leaned(rect, angle);

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
    required this.cards,
    required this.rows,
    required this.picks,
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
    required this.initialScroll,
  });

  final EndBanner banner;

  /// In the order they are laid out: the living winners, the living losers,
  /// the dead (the vote's, then the Hunter's pick).
  final List<EndCard> cards;

  /// Indexes into [cards], a row each, left to right.
  final List<List<int>> rows;

  /// The Hunter's picks: one per Hunter the vote took who took someone.
  final List<EndPick> picks;

  /// The three cards nobody held, as they ended.
  final List<RoleId> centre;
  final EndFoot foot;
  final Size screen;
  final double boardWidth;

  /// Where the board's top lies on the screen.
  final double boardTop;

  /// The height of the board's window: from [boardTop] to the foot's top
  /// (its torn lip lies over the last [EndMetrics.lip] of it).
  final double viewHeight;

  /// The board's own height: [viewHeight] when it fits, taller when it scrolls.
  final double boardHeight;
  final bool scrolls;

  /// How much the cards grew (1 to 1.3).
  final double growth;
  final Rect lantern;
  final Offset light;
  final bool nobodyHanged;

  /// Where the board stands scrolled when the screen opens: 0, or as far as
  /// brings the hanged into view (a short phone, a big table).
  final double initialScroll;

  EndCard card(int id) => cards.firstWhere((c) => c.id == id);

  /// What a card's winners are lit by: the living winners.
  Iterable<EndCard> get pool => cards.where((c) => c.lit);

  /// How much of the board is under the foot's lip at scroll 0.
  double get seenAtTop => viewHeight - EndMetrics.lip;
}
