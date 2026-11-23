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
    this.skyDepth = 9,
    this.skyStep = 16,
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
    this.lockedSaturation = 0.25,
    this.lockedPale = const Color(0xFFD8D0BC),
    this.lockedPaleMix = 0.78,
    this.lockedMid = const Color(0xFF9C9279),
    this.lockedLift = 0.35,
    this.lockedShadow = 0.5,
    this.villageTag = const Color(0xFF203660),
    this.tannerTag = const Color(0xFF523714),
    this.werewolfTag = const Color(0xFF6E1D18),
    this.onTeamTag = const Color(0xFFE9E2D0),
    this.cardRim = const Color(0xFF080A1A),
    this.sealSize = 30,
    this.sealHang = 12,
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
  /// card, a card pinned up, a banner (a rougher tear), the day's sky window
  /// foot and the strip of time left.
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
  final double skyDepth;
  final double skyStep;
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

  /// A locked piece (a button that cannot act yet) is one of paper that is
  /// plainly not live, with no outline and no ring: its own paper keeps
  /// [lockedSaturation] of its colour and is laid [lockedPaleMix] of the way
  /// to [lockedPale] (the amber becomes a pale sand, clearly lighter and greyer
  /// than the live amber, its words still 4.5:1), it lies flat (its lift is
  /// [lockedLift] of the live piece's) and casts [lockedShadow] of the live
  /// shadow's ink. `paper_locked_test.dart` holds the margins.
  final double lockedSaturation;
  final Color lockedPale;

  /// Where the paper is laid instead on a ground too light for [lockedPale]
  /// to stand off it (the day and paper grounds): a mid sand.
  final Color lockedMid;
  final double lockedPaleMix;
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

  /// The wax seal a picked chip wears: its size, and how far it hangs over the
  /// chip's corner.
  final double sealSize;
  final double sealHang;
}
