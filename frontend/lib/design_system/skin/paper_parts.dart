import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter/painting.dart';

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
    this.plaqueInset = 3,
    this.plaquePin = 5,
    this.plaquePinIn = 11,
    this.plaqueLineAlpha = 0.28,
    this.plaquePinAlpha = 0.55,
    this.markScale = 1.4,
    this.backingBleed = const Offset(8, 5),
    this.backingAlpha = 0.9,
    this.fanAngle = 0.12,
    this.fanScale = 1.1,
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

  /// The plaque (the primary button's amber paper): its torn edge, the cut
  /// line set in from it, the pin at each end and how far in it sits, and how
  /// strongly the line and the pins show.
  final double plaqueDepth;
  final double plaqueStep;
  final double plaqueInset;
  final double plaquePin;
  final double plaquePinIn;
  final double plaqueLineAlpha;
  final double plaquePinAlpha;

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
}
