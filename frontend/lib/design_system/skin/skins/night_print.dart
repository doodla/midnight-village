import 'package:flutter/material.dart';

import '../art_set.dart';
import '../elevation.dart';
import '../ground.dart';
import '../skin.dart';
import '../skin_shape.dart';
import '../skin_tilt.dart';
import '../skin_type.dart';

// "Night print": a linocut poster (mock row E: E_Card, E_Vote, E_Results).
// Values are the mocks' unless a comment says otherwise. The art is Shadow
// paper's pictures printed in five inks by tool/linocut_art.py
// (`just skin-art`); the faces load only when Night print is chosen.

// Palette.
const _nightIndigo = Color(0xFF14183A); // night ground
const _cream = Color(0xFFF3E8D3); // day ground; text on night
const _paperCream = Color(0xFFF5EBD8); // paper
const _ink = Color(0xFF17130F);
const _red = Color(0xFFC8452F); // shadows and lines
const _amber = Color(0xFFE3A13A);
const _stampPink = Color(0xFFF0A08C); // red words on night ("your vote")
// Not in the mocks: the mocks' red under cream text is 4.1:1, short of AA for
// small text, so red fills and red words on cream use this deeper red (5.3:1).
const _deepRed = Color(0xFFA8392A);
// Not in the mocks, which print in full-strength ink only: the quieter text,
// rules and wells a full screen also needs.
const _nightQuiet = Color(0xFFC9BFAE);
const _nightFaint = Color(0xFFA8A08F);
const _nightRule = Color(0xFF4A4F7C);
const _creamQuiet = Color(0xFF5A4F44);
const _creamFaint = Color(0xFF6B5F52);
const _creamWell = Color(0xFFE8DCC3);
const _creamRule = Color(0xFFB8AC94);

const _night = Ground(
  ground: _nightIndigo,
  panel: _ink,
  text: _cream,
  quietText: _nightQuiet,
  faintText: _nightFaint,
  hairline: _nightRule,
  idle: _nightQuiet,
  outline: _cream,
  edge: _ink,
  shadow: _ink,
  paper: _paperCream,
  paperEdge: _ink,
  // The mocks' cream print (E_Card) is lantern amber: the one warm accent is
  // the primary button's in every skin (first-time play spec, rule 10).
  accent: _amber,
  onAccent: _ink,
  selection: _cream,
  mark: _cream,
  onMark: _ink,
  danger: _deepRed,
  onDanger: _paperCream,
  dangerText: _stampPink,
  dangerLine: _red,
  disabled: _nightRule,
  onDisabled: _nightFaint,
  elevation: GroundElevation(
    card: Elevation([HardShadow(Offset(6, 6), _ink)]),
    lying: Elevation([HardShadow(Offset(4, 4), _ink)]),
    raised: Elevation([HardShadow(Offset(4, 4), _ink)]),
    // The mocks' amber slabs print in red: amber is the primary's alone.
    slab: Elevation([HardShadow(Offset(10, 10), _red)]),
    heroSlab: Elevation([HardShadow(Offset(10, 10), _red)]),
    primary: Elevation([HardShadow(Offset(6, 6), _red)]),
    selected: Elevation([HardShadow(Offset(6, 6), _ink)]),
    badge: Elevation([HardShadow(Offset(4, 4), _ink)]),
  ),
);

Ground _onCream({required Color ground, required Color paper}) => Ground(
  ground: ground,
  panel: _creamWell,
  text: _ink,
  quietText: _creamQuiet,
  faintText: _creamFaint,
  hairline: _creamRule,
  idle: _creamQuiet,
  outline: _ink,
  edge: _ink,
  shadow: _ink,
  paper: paper,
  paperEdge: _ink,
  accent: _amber,
  onAccent: _ink,
  accentEdge: _ink,
  selection: _ink,
  mark: _ink,
  onMark: _paperCream,
  danger: _deepRed,
  onDanger: _paperCream,
  dangerText: _deepRed,
  dangerLine: _red,
  disabled: _creamRule,
  onDisabled: _creamQuiet,
  elevation: const GroundElevation(
    card: Elevation([HardShadow(Offset(5, 5), _ink)]),
    lying: Elevation([HardShadow(Offset(4, 4), _ink)]),
    raised: Elevation([HardShadow(Offset(4, 4), _ink)]),
    slab: Elevation([HardShadow(Offset(8, 8), _red)]),
    heroSlab: Elevation([HardShadow(Offset(8, 8), _red)]),
    primary: Elevation([HardShadow(Offset(6, 6), _red)]),
    selected: Elevation([HardShadow(Offset(6, 6), _ink)]),
    badge: Elevation([HardShadow(Offset(4, 4), _ink)]),
  ),
);

const _display = 'Rozha One';
const _body = 'Alegreya Sans';

TextStyle _rozha(double size, {required double height, double em = 0}) =>
    TextStyle(
      fontFamily: _display,
      fontWeight: FontWeight.w400,
      fontSize: size,
      height: height,
      letterSpacing: em * size,
    );

TextStyle _alegreya(
  double size,
  FontWeight weight, {
  required double height,
  double em = 0,
}) => TextStyle(
  fontFamily: _body,
  fontWeight: weight,
  fontSize: size,
  height: height,
  letterSpacing: em * size,
);

// Night print follows the same scale as every skin (design brief section 4):
// its mocks set headings up to 58, which the hero roles now allow on the one
// line per screen that is the hero; every other heading stays 26 to 36.
// Alegreya Sans is small on the body, so body text sits at the top of the
// brief's 15 to 17.
final _type = SkinType(
  heroTitle: _rozha(46, height: 0.95),
  heroCode: _rozha(46, height: 1, em: 0.06),
  heroVerdict: _rozha(44, height: 0.95),
  heroWinner: _rozha(40, height: 0.95),
  display: _rozha(36, height: 0.95),
  screenTitle: _rozha(34, height: 1),
  headline: _rozha(32, height: 0.95),
  title: _rozha(26, height: 1.05),
  tally: _rozha(28, height: 1),
  heading: _rozha(24, height: 1),
  name: _rozha(22, height: 1.05),
  nameSmall: _rozha(18, height: 1.05),
  buttonLabelLarge: _rozha(23, height: 1),
  buttonLabel: _rozha(22, height: 1),
  buttonLabelSmall: _rozha(20, height: 1),
  timer: _rozha(84, height: 0.9),
  timerVote: _rozha(76, height: 0.9),
  timerSmall: _rozha(64, height: 0.9),
  timerCompact: _rozha(34, height: 1),
  bodyLarge: _alegreya(17, FontWeight.w500, height: 1.3),
  lede: _alegreya(17, FontWeight.w500, height: 1.3),
  body: _alegreya(16, FontWeight.w500, height: 1.3),
  action: _alegreya(16, FontWeight.w800, height: 1.2),
  code: _alegreya(17, FontWeight.w800, height: 1.2, em: 0.12),
  cue: _alegreya(20, FontWeight.w800, height: 1.2),
  // The reading floor (first-time play spec, copy rule 7): captions at 14.
  caption: _alegreya(14, FontWeight.w500, height: 1.3),
  tag: _alegreya(14, FontWeight.w800, height: 1.2),
  badge: _alegreya(14, FontWeight.w800, height: 1.2),
);

/// Night print's pictures: Shadow paper's, printed in its five inks, with
/// square tokens (its frames are square).
const nightPrintArt = ArtSet(
  folder: 'assets/skins/night_print',
  rolePixels: Size(576, 768),
  tokenPixels: Size.square(192),
  scenePixels: {
    Scene.cardBack: Size(600, 800),
    Scene.candle: Size(768, 1024),
    Scene.table: Size(1024, 768),
    Scene.streetDoor: Size(768, 1024),
    Scene.sleepingVillage: Size(768, 1024),
    Scene.nightVillage: Size(768, 1024),
    Scene.dawnRooftops: Size(768, 1024),
    Scene.dawnGallows: Size(1024, 768),
  },
  portraitFocus: Alignment(0, -0.7),
  sceneFocus: {
    Scene.candle: Alignment(0, 0.24),
    Scene.table: Alignment(0, 0.1),
    Scene.streetDoor: Alignment(0, -0.76),
    Scene.sleepingVillage: Alignment.topCenter,
    Scene.nightVillage: Alignment.topCenter,
    Scene.dawnGallows: Alignment(0, -0.2),
  },
);

final nightPrint = Skin(
  night: _night,
  day: _onCream(ground: _cream, paper: _paperCream),
  paper: _onCream(ground: _paperCream, paper: _creamWell),
  typography: _type,
  // Only the weights the type roles use (500 and 800 of Alegreya Sans).
  fonts: const SkinFonts.onDemand({
    _display: ['assets/fonts/rozhaone/RozhaOne-Regular.ttf'],
    _body: [
      'assets/fonts/alegreyasans/AlegreyaSans-Medium.ttf',
      'assets/fonts/alegreyasans/AlegreyaSans-ExtraBold.ttf',
    ],
  }),
  shape: const SkinShape(
    radius: 0,
    radiusSmall: 0,
    radiusTiny: 0,
    sheetRadius: 0,
    rowLeadRoundness: 0,
    tokenRoundness: 0,
    badgeRoundness: 1, // the round timer badge (E_Vote)
    ring: 2.5,
    selectedRing: 3,
    stroke: 3,
    edgeWidth: 3,
    pressKeep: 0,
    pip: Size(26, 8),
    pipRoundness: 0,
    pipEmptyStroke: 2,
    pipStretch: true, // E_Card: the bars run the width of the row
    archRoundness: 0,
  ),
  tilt: const SkinTilt(
    card: -1.2 * SkinTilt.degree,
    stamp: -5 * SkinTilt.degree,
    badge: 6 * SkinTilt.degree,
    // Not in the mocks: Shadow paper's loose cards, a little straighter.
    scatter: [-3 * SkinTilt.degree, 1 * SkinTilt.degree, 3 * SkinTilt.degree],
    thumb: -3 * SkinTilt.degree,
    hero: -2 * SkinTilt.degree,
  ),
  art: nightPrintArt,
  scrim: _ink.withValues(alpha: 0.72),
  dimmed: 0.4,
);
