import 'package:flutter/foundation.dart' show immutable;
import 'package:flutter/painting.dart';

/// The colours and lengths of the mood of light behind a dressed screen (see
/// `primitives/mood.dart`), part of the skin so a screen and a part ask for
/// none of it: a ground, a village veil, a moon or lantern pool, a vignette,
/// per light. The mood is composed once into a picture, never drawn per frame.
@immutable
class MoodPalette {
  const MoodPalette({
    this.nightBase = const Color(0xFF0C0E22),
    this.moon = const Color(0xFFDCE2FF),
    this.moonAlpha = 0.2,
    this.vignetteInk = const Color(0xFF03040C),
    this.nightVignette = 0.6,
    this.veilFrom = 0.30,
    this.veilFromAlpha = 0.22,
    this.veilMid = 0.62,
    this.veilMidAlpha = 0.74,
    this.lantern = const Color(0xFFFFBE6E),
    this.lanternAlpha = 0.26,
    this.lanternAt = const Alignment(0, 0.1),
    this.lanternHighAt = const Alignment(0, -0.1),
    this.daySky = const Color(0xFFD6CCE6),
    this.dayMid = const Color(0xFFF0D2BC),
    this.dayFoot = const Color(0xFFF5C27A),
    this.dayVeilTop = const Color(0xFFF2D3B6),
    this.dayVeilFoot = const Color(0xFFF2C98C),
    this.sun = const Color(0xFFFFD98E),
    this.dayVignetteInk = const Color(0xFF8A6A88),
    this.dayVignette = 0.26,
    this.poolReach = 80,
    this.poolWide = 2.2,
    this.poolAlpha = 0.62,
    this.poolEdgeAlpha = 0.24,
    this.leanNight = -0.45,
    this.leanLantern = 0,
    this.leanDay = 0.8,
  });

  /// The standard palette (the dressed skin's).
  static const standard = MoodPalette();

  /// Night: the ground the village falls into, a cool moon pool and a cone of
  /// it, a heavy vignette from a third of the way out.
  final Color nightBase;
  final Color moon;
  final double moonAlpha;
  final Color vignetteInk;
  final double nightVignette;

  /// How much of the night's own ground lies over the village (of the
  /// picture's height): the top third is lit, the rest falls into shadow.
  final double veilFrom;
  final double veilFromAlpha;
  final double veilMid;
  final double veilMidAlpha;

  /// The lantern's warm pool on what it lights.
  final Color lantern;
  final double lanternAlpha;

  /// Where the lantern's pool lies on the screen: the usual place, and a
  /// higher one for a screen whose lit part is nearer the top (the table).
  final Alignment lanternAt;
  final Alignment lanternHighAt;

  /// Day: a pale sky over a golden foot, a low warm sun, a soft vignette in a
  /// warm plum.
  final Color daySky;
  final Color dayMid;
  final Color dayFoot;
  final Color dayVeilTop;
  final Color dayVeilFoot;
  final Color sun;
  final Color dayVignetteInk;
  final double dayVignette;

  /// A lantern's pool round a field (`LanternPool`): how far it reaches above
  /// and below the field, how much wider than it, and how warm.
  final double poolReach;
  final double poolWide;
  final double poolAlpha;
  final double poolEdgeAlpha;

  /// Which way paper's shadow leans (sideways per unit of drop) away from
  /// each light: the moon high on the right throws left, a lantern overhead
  /// straight down, a low sun on the left long to the right.
  final double leanNight;
  final double leanLantern;
  final double leanDay;
}
