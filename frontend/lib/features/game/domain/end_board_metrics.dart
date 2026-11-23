import 'dart:math' as math;

import 'dart:ui';

// The end board's numbers (docs/specs/frontend/end-board.md, sections 2 and
// 3), in points, in one place so the layout, the widgets and the tests read the
// same. Where a number is also a part's own (the tag's apron, the ribbon's
// size), `end_board_view_test.dart` holds the two equal. Heights that hold
// words are never a number here: they come from the words measured at the
// phone's text size (the `...For` functions).

/// What a width is asked of: the card's name (16 serif), a role's words on its
/// strip (12), a vote tag's name (16 serif), the red slip's words (16 serif).
enum EndText { name, role, tag, slip }

/// The width of [text] set as [kind] at this phone's text size.
typedef EndMeasure = double Function(EndText kind, String text);

abstract final class EndMetrics {
  // ---- The card (spec 2, "Player card").
  /// A winner's portrait is this wide, a loser's the other; both can grow.
  static const winnerPortrait = 90.0;
  static const loserPortrait = 64.0;

  /// With this many players or fewer the cards may grow, up to [mostGrowth],
  /// each row as far as its own room lets it.
  static const growsUpTo = 5;
  static const mostGrowth = 1.3;
  static const growthStep = 0.01;

  /// With this many players or fewer the board fits its window without
  /// scrolling (a 360 x 780 phone at text size 1): it closes up (`EndFit`)
  /// before it may scroll. Cards never shrink for it.
  static const fitsUpTo = 6;

  static const headerHeight = 22.0;
  static const stripHeight = 17.0;

  /// The paper each side of the portrait.
  static const portraitInset = 4.0;

  /// The paper under the portrait: the role's strip hangs over the portrait's
  /// foot and this edge, so the face shows whole above it.
  static const cardFoot = 10.0;

  /// The strip is a tab as wide as its words and this, its foot this far up
  /// from the card's.
  static const stripPad = 10.0;
  static const stripUp = 1.0;
  static const nameRoom = 20.0;
  static const roleRoom = 18.0;

  /// A card that carries tags is this much wider, to clear the pin.
  static const tagRoom = 28.0;

  static double portraitHeight(double width) => width * 3 / 4;
  static double cardHeight(
    double portraitWidth, {
    double header = headerHeight,
  }) => header + portraitHeight(portraitWidth) + cardFoot;

  /// The header and the strip as tall as their words are at this phone's text
  /// size, never less than the spec's 22 and 17.
  static double headerFor(double nameLine) =>
      math.max(headerHeight, nameLine + 4);
  static double stripFor(double roleLine) =>
      math.max(stripHeight, roleLine + 2);

  // ---- The dealt card, the ribbon, the seal, the pin (spec 2).
  static const dealtShare = 0.38;
  static const dealtLeast = 34.0;
  static const dealtMost = 40.0;
  static const dealtRatio = 1.3;

  /// The dealt card's top left lies this share of its own size out from the
  /// card's top left: about two thirds of it shows.
  static const dealtOutX = 0.3;
  static const dealtOutY = 0.5;

  static double dealtWidth(double portraitWidth) =>
      (portraitWidth * dealtShare).clamp(dealtLeast, dealtMost);

  static const ribbonLeast = 30.0;
  static const ribbonMost = 38.0;
  static const ribbonShare = 0.38;
  static const ribbonInside = 0.28;
  static const ribbonPixels = Size(153, 193);

  static double ribbonWidth(double portraitWidth) =>
      (portraitWidth * ribbonShare).clamp(ribbonLeast, ribbonMost);
  static double ribbonHeight(double width) =>
      width * ribbonPixels.height / ribbonPixels.width;

  static const seal = 30.0;
  static const sealHang = 14.0;
  static const sealDown = 0.44;

  static const pin = 10.0;
  static const pinIn = 8.0;
  static const pinUp = 6.0;

  // ---- The tags (spec 2, "Vote tags").
  /// A tag is at least this tall, and as tall as its name and [tagPad].
  static const tagLeast = 26.0;
  static const tagPad = 6.0;

  /// Clear air between two tags, and from the card's foot to the first.
  static const tagGap = 4.0;
  static const tagFirst = 4.0;
  static const tagStagger = 6.0;

  /// More tags than this under one card hang in columns, as many as fit, up
  /// to [mostTagColumns].
  static const tagsInOneColumn = 3;
  static const mostTagColumns = 3;

  static double tagHeightFor(double nameLine) =>
      math.max(tagLeast, nameLine + tagPad);

  /// A tag is this much wider than its name: the paper's edges, the hole, the
  /// sigil (`VoteTag.apron`).
  static const tagApron = 52.0;

  /// How far a strand of [count] tags, [tag] tall, in [columns], hangs below
  /// its card's bottom.
  static double strand(int count, double tag, {int columns = 1}) {
    if (count == 0) return 0;
    final rows = (count / columns).ceil();
    return tagFirst + rows * tag + (rows - 1) * tagGap;
  }

  // ---- The Hunter's slip (a `PaperSlip`: 40 tall, its words and the pin).
  static const slipHeight = 40.0;
  static const slipRoom = 33.0;

  /// How far round the two cards the Hunter's slip may hang, looking for a
  /// place that covers nothing.
  static const slipReach = 40.0;

  /// How far the ribbon is turned on its card (`DeathMark.ribbonTurn`).
  static const ribbonTurn = 14 * math.pi / 180;

  // ---- The board (spec 2 and 3), x from the board's left edge.
  /// The board is the screen's width less this (2 each side).
  static const boardMargin = 4.0;

  /// The frame's thickness each side, and the room the cards have inside it.
  static const insetX = 22.5;
  static const insetTop = 20.0;
  static const insetBottom = 20.0;

  /// Air above a row, and above one with a dealt card; a card keeps this clear
  /// of its slot's edge.
  static const gap = 12.0;
  static const gapDealt = 24.0;
  static const clear = 6.0;

  /// The least air a board closing up keeps under whatever stands above: a
  /// card (the spec's 8), and what a card holds up (its 6 clear).
  static const gapLeast = 8.0;
  static const hangLeast = clear;

  /// The most air added between two rows when the board has room to spare;
  /// the rest is shared above and below, so a small group stands centred.
  static const mostSpare = 40.0;

  /// The lantern hangs from the board's top right; the first row stops at it.
  static const lanternSize = Size(88, 152);
  static const lanternLeftFromRight = 86.0;
  static const lanternTop = -6.0;
  static const firstRowFromRight = 92.0;

  // ---- The page. The sky, the banner and the roof stand above the board.
  /// The banner's top on a phone 780 tall (the mocks'), and on the shortest
  /// (640): between the two it follows the screen's height.
  static const bannerTopTall = 36.0;
  static const bannerTopShort = 10.0;
  static const tallScreen = 780.0;
  static const shortScreen = 640.0;

  /// The board's frame begins this far under the banner's foot.
  static const bannerBelow = 4.0;
  static const roof = 30.0;

  /// How far the foot's torn lip overlaps the board's foot.
  static const lip = 14.0;

  /// A card cut by the lip when the board scrolls: this share of it shows.
  static const cutShows = 0.55;

  /// The least of a card that shows under the eave when the board opens
  /// scrolled down: enough to read as a card cut, so there is more above.
  static const cutLeast = 14.0;

  /// How tall a screen is, from short (0) to the mocks' (1).
  static double tallness(double screenHeight) =>
      ((screenHeight - shortScreen) / (tallScreen - shortScreen)).clamp(0, 1);

  /// The banner's top: less sky on a short phone.
  static double bannerTopFor(double screenHeight) =>
      bannerTopShort +
      (bannerTopTall - bannerTopShort) * tallness(screenHeight);

  /// Where the board's frame begins under a banner [bannerHeight] tall.
  static double boardTopFor(double screenHeight, double bannerHeight) =>
      bannerTopFor(screenHeight) + bannerHeight + bannerBelow;

  // ---- Tilt (spec 3, rule 6).
  static const tiltDegrees = 2.0;
  static const hangedTiltDegrees = 3.0;
  static const jitter = 2.0;

  /// How far a [size] turned by [angle] about its centre reaches out of its
  /// upright box, across and down.
  static Size leanOf(Size size, double angle) {
    final c = math.cos(angle).abs(), s = math.sin(angle).abs();
    return Size(
      (size.width * c + size.height * s - size.width) / 2,
      (size.width * s + size.height * c - size.height) / 2,
    );
  }

  /// The box a [rect] turned by [angle] about its centre fills.
  static Rect leaned(Rect rect, double angle) {
    final lean = leanOf(rect.size, angle);
    return Rect.fromLTRB(
      rect.left - lean.width,
      rect.top - lean.height,
      rect.right + lean.width,
      rect.bottom + lean.height,
    );
  }

  /// Clear air between what hangs above a card and the row over it: the
  /// slot's clearance and the jitter (the lean is the card's own, measured).
  static const hangClear = clear + jitter;

  /// A number from [id] and [salt], the same on every phone and every screen,
  /// in -1 to 1. Cosmetic, not game randomness; small enough numbers that the
  /// web's arithmetic gives what the phone's does.
  static double seeded(int id, int salt) {
    var h = (((id % 100003) * 73856093) + salt * 19349663) & 0x7FFFFFFF;
    h = ((h ^ (h >> 15)) * 2459) & 0x7FFFFFFF;
    h = ((h ^ (h >> 13)) * 3187) & 0x7FFFFFFF;
    return (h % 2001) / 1000 - 1;
  }

  /// The tilt in radians: ±2 degrees, ±3 for a hanged card (raised higher).
  static double angleOf(int id, {required bool hanged}) {
    final unit = seeded(id, 1);
    final degrees = hanged
        ? (unit < 0 ? -hangedTiltDegrees : hangedTiltDegrees)
        : unit * tiltDegrees;
    return degrees * math.pi / 180;
  }

  static double jitterOf(int id) => seeded(id, 2) * jitter;
}

/// How hard a board works to fit its window (spec 3, rule 9). [loose] is the
/// board as the rules lay it. A board of six or fewer that would scroll tries
/// [close]: a strand takes the row beside the Hunter's pick too (the slip
/// hangs between the two cards), strands of two or more hang across where
/// they fit, and a hanged card slides along its slot so its ribbon clears the
/// card above and the rows close up. Then [closest]: the air between rows
/// down to the least ([EndMetrics.gapLeast], [EndMetrics.hangLeast]).
class EndFit {
  const EndFit._(
    this.name, {
    required this.besidePick,
    required this.across,
    required this.slide,
    required this.gap,
    required this.hangClear,
  });

  /// The step's name, for a failing test's words.
  final String name;

  @override
  String toString() => name;

  /// A strand may take the row beside the Hunter's pick.
  final bool besidePick;

  /// A strand of more tags than this hangs across, where they fit.
  final int across;

  /// A hanged card may slide along its slot to clear its ribbon.
  final bool slide;

  /// Air under whatever stands above a card, and above what it holds up.
  final double gap;
  final double hangClear;

  static const loose = EndFit._(
    'loose',
    besidePick: false,
    across: EndMetrics.tagsInOneColumn,
    slide: false,
    gap: EndMetrics.gap,
    hangClear: EndMetrics.hangClear,
  );
  static const close = EndFit._(
    'close',
    besidePick: true,
    across: 1,
    slide: true,
    gap: EndMetrics.gap,
    hangClear: EndMetrics.hangClear,
  );

  /// Every step, loosest first.
  static const levels = [loose, close, closest];

  static const closest = EndFit._(
    'closest',
    besidePick: true,
    across: 1,
    slide: true,
    gap: EndMetrics.gapLeast,
    hangClear: EndMetrics.hangLeast,
  );
}
