import 'dart:math' as math;

import 'dart:ui';

// The end board's numbers (the end-board SPEC, sections 2 and 3), in points on
// a phone 360 wide, in one place so the layout, the widgets and the tests read
// the same. Where a number is also a part's own (the tag's apron, the ribbon's
// size), `end_board_metrics_test.dart` holds the two equal.

/// What a width is asked of: the card's name (16 serif), a role's words on its
/// strip (12), a vote tag's name (16 serif), the red slip's words (16 serif).
enum EndText { name, role, tag, slip }

/// The width of [text] set as [kind] at this phone's text size.
typedef EndMeasure = double Function(EndText kind, String text);

abstract final class EndMetrics {
  // ---- The card (SPEC 2, "Player card").
  /// A winner's portrait is this wide, a loser's the other; both can grow.
  static const winnerPortrait = 90.0;
  static const loserPortrait = 64.0;

  /// With this many players or fewer the cards may grow, up to [mostGrowth].
  static const growsUpTo = 5;
  static const mostGrowth = 1.3;
  static const growthStep = 0.05;

  static const headerHeight = 22.0;
  static const stripHeight = 17.0;

  /// The paper round the portrait: 4 each side and under it.
  static const portraitInset = 4.0;
  static const nameRoom = 20.0;
  static const roleRoom = 18.0;

  /// A card that carries tags is this much wider, to clear the pin.
  static const tagRoom = 28.0;

  static double portraitHeight(double width) => width * 3 / 4;
  static double cardHeight(
    double portraitWidth, {
    double header = headerHeight,
  }) => header + portraitHeight(portraitWidth) + portraitInset;

  /// The header and the strip as tall as their words are at this phone's text
  /// size, never less than the SPEC's 22 and 17.
  static double headerFor(double nameLine) =>
      math.max(headerHeight, nameLine + 4);
  static double stripFor(double roleLine) =>
      math.max(stripHeight, roleLine + 2);

  // ---- The dealt card, the ribbon, the seal, the pin (SPEC 2).
  static const dealtShare = 0.34;
  static const dealtLeast = 30.0;
  static const dealtMost = 40.0;
  static const dealtRatio = 1.3;

  /// The dealt card's top left lies this share of its own size out from the
  /// card's top left.
  static const dealtOutX = 0.3;
  static const dealtOutY = 0.5;

  static double dealtWidth(double portraitWidth) =>
      (portraitWidth * dealtShare).clamp(dealtLeast, dealtMost);

  static const ribbonLeast = 24.0;
  static const ribbonMost = 34.0;
  static const ribbonShare = 0.34;
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

  // ---- The tags (SPEC 2, "Vote tags").
  static const tagHeight = 28.0;
  static const tagStep = 24.0;
  static const tagFirst = 4.0;
  static const tagStagger = 6.0;

  /// A tag is this much wider than its name: the paper's edges, the hole, the
  /// sigil (`VoteTag.apron`).
  static const tagApron = 52.0;

  /// How far a strand of [tags] hangs below its card's bottom.
  static double strand(int tags) =>
      tags == 0 ? 0 : tagFirst + tagStep * (tags - 1) + tagHeight;

  // ---- The Hunter's slip (a `PaperSlip`: 40 tall, its words and the pin).
  static const slipHeight = 40.0;
  static const slipRoom = 33.0;

  // ---- The board (SPEC 2 and 3), x from the board's left edge.
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

  /// The lantern hangs from the board's top right; the first row stops at it.
  static const lanternSize = Size(88, 152);
  static const lanternLeftFromRight = 86.0;
  static const lanternTop = -6.0;
  static const firstRowFromRight = 92.0;

  // ---- The page (360 x 780 phone).
  static const boardTop = 168.0;
  static const bannerExtra = 30.0;
  static const roof = 30.0;

  /// The fixed foot: the cobbles, the scraps, the plaque.
  static const foot = 148.0;

  /// How far the foot's torn lip overlaps the board's foot.
  static const lip = 14.0;

  /// A card cut by the lip when the board scrolls: this share of it shows.
  static const cutShows = 0.55;

  // ---- Tilt (SPEC 3, rule 6).
  static const tiltDegrees = 2.0;
  static const hangedTiltDegrees = 3.0;
  static const jitter = 2.0;

  /// A tilted card leans out of its box by about this much.
  static const tiltReach = 3.0;

  /// Clear air between what hangs above a card and the row over it: the
  /// slot's clearance, the lean and the jitter.
  static const hangClear = clear + tiltReach + jitter;

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
