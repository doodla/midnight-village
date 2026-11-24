import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter/painting.dart';

import 'ground.dart';

/// The sizes, angles and edges of the paper parts a dressed screen is made of
/// (pins, banners, the plaque, torn cards), so no part and no screen carries a
/// number of its own. Only a screen dressed up draws them (`Dress.paper`).
@immutable
class PaperParts {
  const PaperParts({
    this.pinSize = 9,
    this.pinCardSize = 11,
    this.pinInkAlpha = 0.8,
    this.pinShadow = const Color(0x73000000),
    this.pinDrop = const Offset(3.5, 2.5),
    this.deckleDepth = 2.4,
    this.deckleStep = 6,
    this.pinnedDepth = 3.2,
    this.pinnedStep = 8,
    this.bannerAngle = -0.012,
    this.bannerDepth = 4.5,
    this.bannerCandle = 0.78,
    this.bannerStep = 13,
    this.barDepth = 2,
    this.plaqueDepth = 3.4,
    this.plaqueStep = 7,
    this.markScale = 1.4,
    this.backingBleed = const Offset(8, 7),
    this.backingAlpha = 0.9,
    this.fanAngle = 0.12,
    this.fanScale = 1.1,
    this.tokenInset = 0.055,
    this.discDepth = 1.3,
    this.discStep = 5,
    this.waxDepth = 2.2,
    this.waxStep = 6,
    this.lockedWell = 0.9,
    this.lockedDark = 0.72,
    this.lockedLift = 0.35,
    this.lockedShadow = 0.5,
    this.villageTag = const Color(0xFF203660),
    this.tannerTag = const Color(0xFF523714),
    this.werewolfTag = const Color(0xFF6E1D18),
    this.onTeamTag = const Color(0xFFE9E2D0),
    this.cardRim = const Color(0xFF080A1A),
    this.outSaturation = 0.15,
    this.holdBand = 0.07,
    this.holdBandLeast = 3,
    this.holdBandGap = 2,
    this.holdDrop = 2,
    this.holdArcAlpha = 0.5,
    this.lanternCast = const Offset(0.07, 0.09),
    this.lanternHalo = 1.25,
    this.lanternHaloAlpha = 0.34,
    this.sealSize = 30,
    this.sealHang = 12,
    this.boardShade = const Color(0xFF000000),
    this.lanternGlowAlpha = 0.5,
    this.foldShade = 0.18,
    this.flapLight = 0.12,
    this.squareLantern = 0.62,
    this.squareVeil = 0.8,
    this.squarePortraitFew = 84,
    this.squarePortraitMany = 64,
    this.squarePortraitLeast = 48,
    this.squarePortraitStep = 2,
    this.squareSpareAbove = 0.3,
    this.squareSpareBetween = 0.4,
    this.squareButtonWidest = 264,
    this.squareLeastBody = 380,
    this.storySlipWidest = 360,
    this.storySceneShare = 1.4,
    this.storyLookSag = 8,
    this.linkWidth = 4,
    this.linkHead = 16,
    this.linkDot = 5.6,
    this.linkDash = 12,
    this.linkGap = 7,
    this.winnerPaper = const Color(0xFFF4E8CB),
    this.loserPaper = const Color(0xFFC9C0AA),
    this.nightPaper = const Color(0xFFCFD2E2),
    this.werewolfWonPaper = const Color(0xFF9A2C25),
    this.werewolfLostPaper = const Color(0xFF7B231E),
    this.boardFelt = const Color(0xFF20234A),
    this.boardFeltNight = const Color(0xFF191B3A),
    this.poolColor = const Color(0xFFFFB860),
    this.poolAlpha = 0.25,
    this.poolPull = 0.25,
    this.vignetteLantern = 0.6,
    this.vignetteEdge = 0.32,
    this.loserKeep = 0.55,
    this.loserDark = 0.78,
    this.duskTint = const [
      Color(0xD12C2460),
      Color(0x80965C8C),
      Color(0x73E88C70),
      Color(0x80FABE82),
      Color(0x80FCD6A5),
    ],
    this.duskStops = const [0, 0.1, 0.2, 0.34, 1],
    this.duskReach = 300,
    this.nightMoonWidth = 40,
    this.nightMoonAt = const Offset(72, 4),
    this.nightFeltReach = 1.6,
  });

  /// The standard parts (the dressed skin's).
  static const standard = PaperParts();

  /// A pin through paper: its size on a scrap or a banner, and on a pinned
  /// card; how dark its ink is; its own hard shadow and how far it drops
  /// (sideways per unit of the screen's light lean, and down).
  final double pinSize;
  final double pinCardSize;
  final double pinInkAlpha;
  final Color pinShadow;
  final Offset pinDrop;

  /// A torn edge: how far it steps in and the length of one nibble, for a
  /// card, a card pinned up, a banner (a rougher tear) and the strip of
  /// time left.
  final double deckleDepth;
  final double deckleStep;
  final double pinnedDepth;
  final double pinnedStep;
  final double bannerAngle;
  final double bannerDepth;

  /// How much of the timer's line the night board's candle stands as high as
  /// on a banner: the whole of it (the flame above, the ledge below) sits
  /// inside the slip, whose torn edges and turn take a few pixels.
  final double bannerCandle;
  final double bannerStep;
  final double barDepth;

  /// The plaque (the primary button's amber paper): its torn edge.
  final double plaqueDepth;
  final double plaqueStep;

  /// The done mark's size, of the label's.
  final double markScale;

  /// A backing behind words over the village (`TextBacking`): how far it
  /// reaches past them (sideways, up and down) and how solid it is.
  final Offset backingBleed;
  final double backingAlpha;

  /// A fan of cards: how far the outermost is turned (radians) and how much
  /// larger each card is drawn.
  final double fanAngle;
  final double fanScale;

  /// How much of a token's printed rim a dressed token leaves outside its
  /// paper disc, of the picture's width.
  final double tokenInset;

  /// A cut disc's rim: how far it steps in and the length of one nibble.
  final double discDepth;
  final double discStep;

  /// A drop of wax's edge (a count): rounder and more uneven than a cut disc.
  final double waxDepth;
  final double waxStep;

  /// An unlit progress dot: the ground's ink laid half-way into the ground,
  /// so it keeps 3:1 against it.
  Color pipUnlit(Ground ground) => Color.lerp(ground.ground, ground.text, 0.5)!;

  /// A locked piece (a button that cannot act yet) is the QUIETEST form of
  /// button, never the brightest: dark indigo paper, [lockedWell] of the way
  /// from the ground to the ground's panel (so it stands off the ground by
  /// 1.25:1 and lies lower than a chip), no amber and no bone, its words the
  /// ground's own text (4.5:1 or more), barely lifted: its lift is
  /// [lockedLift] of a scrap's and it casts [lockedShadow] of a scrap's ink.
  /// `paper_rules_test.dart` ("locked") holds it lower than every live button
  /// form in luminance and in shadow.
  final double lockedWell;

  /// On a light ground: how far the paper is laid from the ground toward its
  /// ink, so a locked piece is still the darkest button there.
  final double lockedDark;
  final double lockedLift;
  final double lockedShadow;

  /// A team's tag, the same on every surface and ground (a tag is paper of
  /// its own colour, never the ground's): the Village's slate blue, the
  /// Tanner's umber, the Werewolf team's red; words in [onTeamTag].
  final Color villageTag;
  final Color tannerTag;
  final Color werewolfTag;
  final Color onTeamTag;

  /// The paper a face-down card's navy layer lies on: a darker indigo, never
  /// red (red is the Werewolf team's, on its tag, rows and markers, and
  /// nowhere else; `paper_red_test.dart`).
  final Color cardRim;

  /// The hold disc's amber arc: its band's share of the disc (at least
  /// [holdBandLeast] px), the gap between band and disc, and the ink of its
  /// shadow (the drop is two px a unit of the light's lean, and two down).
  final double holdBand;
  final double holdBandLeast;
  final double holdBandGap;
  final double holdDrop;
  final double holdArcAlpha;

  /// The paper lantern's shadow (of its width, sideways and down), the glow
  /// round it (its radius in widths) and how bright that is at most.
  final Offset lanternCast;
  final double lanternHalo;
  final double lanternHaloAlpha;

  /// A card OUT of the deck keeps this share of its colour (a colour matrix).
  final double outSaturation;

  /// A colour filter that keeps [keep] of every colour (1 all, 0 grey).
  ColorFilter desaturate(double keep) {
    final inv = 1 - keep;
    final r = 0.2126 * inv, g = 0.7152 * inv, b = 0.0722 * inv;
    return ColorFilter.matrix([
      r + keep, g, b, 0, 0, //
      r, g + keep, b, 0, 0, //
      r, g, b + keep, 0, 0, //
      0, 0, 0, 1, 0,
    ]);
  }

  /// The wax seal a picked chip wears: its size, and how far it hangs over the
  /// chip's corner.
  final double sealSize;
  final double sealHang;

  /// The black a piece far from the light is darkened with (the end board's
  /// `OneLight.dimFilter`), and the lantern's glow at its centre.
  final Color boardShade;
  final double lanternGlowAlpha;

  /// 08's sealed note: the fold's shade under its flap (toward the paper's
  /// ink) and the flap a hair lighter (toward the ground's light), as shares.
  final double foldShade;
  final double flapLight;

  /// 08's wall lantern, of the end board's lantern's size.
  final double squareLantern;

  /// 08's sky: how much of the night lies over the dawn's layers, so the
  /// clock is the loudest thing in it.
  final double squareVeil;

  /// 08's deck portraits: the widest, with six roles or fewer and with more;
  /// the least that still reads as a face (below it the cards become
  /// name-only, before the board scrolls); and the step they shrink by.
  final double squarePortraitFew;
  final double squarePortraitMany;
  final double squarePortraitLeast;
  final double squarePortraitStep;

  /// 08's spare height: the share above the deck, and the share between the
  /// deck and the tags (the rest is below).
  final double squareSpareAbove;
  final double squareSpareBetween;

  /// 08's one button's widest, on the cobbles, and the least height the
  /// board and its foot are given before the band and body scroll together.
  final double squareButtonWidest;
  final double squareLeastBody;

  /// 08's picture story: the slip's sentence is set at most this wide, the
  /// sleeping village is this many portrait widths tall, and a look across
  /// a row sags this far.
  final double storySlipWidest;
  final double storySceneShare;
  final double storyLookSag;

  /// The end board's "What happened" links (`CardLink`), read at arm's
  /// length across a whole board: the thread's width, a head's length and
  /// width, a dot's radius, and a look's dash and gap.
  final double linkWidth;
  final double linkHead;
  final double linkDot;
  final double linkDash;
  final double linkGap;

  /// The end board's card papers: a winner lit, a loser dull, the Werewolf
  /// team's red (won, lost) and the cool paper of the replayed night. Ink on
  /// the red ones is [onTeamTag].
  final Color winnerPaper;
  final Color loserPaper;
  final Color nightPaper;
  final Color werewolfWonPaper;
  final Color werewolfLostPaper;

  /// The felt the cards are pinned to, by day and by the replayed night.
  final Color boardFelt;
  final Color boardFeltNight;

  /// The lantern's warm pool on the living winners: its colour, its strength,
  /// and how far it is pulled toward the lantern; the two darkenings (round
  /// the lantern, at the edges).
  final Color poolColor;
  final double poolAlpha;
  final double poolPull;
  final double vignetteLantern;
  final double vignetteEdge;

  /// The end board's sky at dawn: the dusk laid over the sky plate (under
  /// the gallows and the roofs), top to bottom, at [duskStops] of
  /// [duskReach] points; so the banner is the bright thing in the sky.
  final List<Color> duskTint;
  final List<double> duskStops;
  final double duskReach;

  /// The end board's night (What happened): how wide the moon is in the
  /// sky, and how far its cool light reaches across the felt from the top
  /// left (a radial gradient's radius, in shares of the board).
  final double nightMoonWidth;

  /// Where the moon's top left is in the sky: clear of the chimneys and the
  /// lantern, up at the left.
  final Offset nightMoonAt;
  final double nightFeltReach;

  /// A loser's portrait: how much of its colour it keeps, and how dark it is.
  final double loserKeep;
  final double loserDark;
}
