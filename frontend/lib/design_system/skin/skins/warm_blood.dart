import 'package:flutter/material.dart';

import '../art_set.dart';
import '../elevation.dart';
import '../ground.dart';
import '../skin.dart';
import '../skin_shape.dart';
import '../skin_tilt.dart';
import '../skin_type.dart';

// "Warm blood": the village seen by heat, the way a hunter's scope finds a
// warm body in the dark (docs/design/skins/warm_blood.md). It has no mock;
// every value here is this skin's own choice.
//
// Colour is temperature. The night is the cold end of a heat scale and the
// day its hot end; the frame around them (plates, text, rules) is cold white
// and violet, and warm colour is kept for what is alive: the pictures, the
// steps things cast, danger, and the one thing to press. The art is Shadow
// paper's pictures filmed on that scale by tool/thermal_art.py
// (`just skin-art`); the faces load only when Warm blood is chosen.

// The heat scale's stops that the frame uses (tool/thermal_art.py has them
// all, cold to hot).
const _cold = Color(0xFF0E0920); // night ground; ink on the light grounds
const _violet = Color(0xFF4A2B9A); // the step under things at night
const _deepViolet = Color(0xFF2A1760); // a second, colder step
const _magenta = Color(0xFFBC2A7C);
const _ember = Color(0xFFF25C33);
const _orange = Color(0xFFFA8A26);
const _hot = Color(0xFFFFD23F); // day ground; the primary button at night

// The frame: cold white plates, and what is written and ruled on them.
const _frost = Color(0xFFF1EEF6); // paper; text on night
const _frostWell = Color(0xFFE2DDED); // a box set into a plate
const _frostRule = Color(0xFFC9C2DC);
const _frostQuiet = Color(0xFF5A4F7A);
const _nightWell = Color(0xFF1A1136);
const _nightRule = Color(0xFF3A2C66);
const _nightQuiet = Color(0xFFB7AFD4);
const _nightFaint = Color(0xFF9A91BC);
const _nightOff = Color(0xFF2A1F4D); // a button that cannot be used
const _dayWell = Color(0xFFF3BC2C); // a box set into the day ground
const _dayRule = Color(0xFFC9971A);
const _dayStep = Color(0xFFF2811D); // the step under things by day
const _dayQuiet = Color(0xFF3D2C63);
const _dayFaint = Color(0xFF4F3D78);
const _dayIdle = Color(0xFF8C6A12);
const _dayOff = Color(0xFFE0B02A);
const _dayOffInk = Color(0xFF5E4B16);

// Danger and the Werewolf: the deep red of the scale, dark enough to carry
// cold-white words (5.7:1), with lighter and darker turns of it for words and
// lines on each ground.
const _wolf = Color(0xFFB5174F);
const _wolfOnNight = Color(0xFFFF7FA3); // red words on night
const _wolfLineOnNight = Color(0xFFF0457A);
const _wolfOnDay = Color(0xFF9C1244); // red words and rings on the day yellow

const _night = Ground(
  ground: _cold,
  panel: _nightWell,
  text: _frost,
  quietText: _nightQuiet,
  faintText: _nightFaint,
  hairline: _nightRule,
  idle: _nightQuiet,
  outline: _nightQuiet,
  edge: _cold,
  shadow: _violet,
  paper: _frost,
  paperEdge: _frostRule,
  // The hottest thing on a night screen is the thing to press.
  accent: _hot,
  onAccent: _cold,
  selection: _orange,
  // Marks are part of the frame, not of the heat: cold white.
  mark: _frost,
  onMark: _cold,
  pick: _wolf,
  onPick: _frost,
  danger: _wolf,
  onDanger: _frost,
  dangerText: _wolfOnNight,
  dangerLine: _wolfLineOnNight,
  disabled: _nightOff,
  onDisabled: _nightFaint,
  elevation: GroundElevation(
    card: Elevation([HardShadow(Offset(3, 3), _violet)]),
    lying: Elevation([HardShadow(Offset(3, 3), _violet)]),
    raised: Elevation([HardShadow(Offset(4, 4), _violet)]),
    slab: Elevation([
      HardShadow(Offset(4, 4), _violet),
      HardShadow(Offset(8, 8), _deepViolet),
    ]),
    // The one card a screen is about gives off heat: three steps, cooling.
    heroSlab: Elevation([
      HardShadow(Offset(4, 4), _orange),
      HardShadow(Offset(8, 8), _magenta),
      HardShadow(Offset(12, 12), _violet),
    ]),
    primary: Elevation([
      HardShadow(Offset(3, 3), _orange),
      HardShadow(Offset(6, 6), _magenta),
    ]),
    selected: Elevation([
      HardShadow(Offset(3, 3), _violet),
      HardShadow(Offset(7, 7), _deepViolet),
    ]),
    badge: Elevation([HardShadow(Offset(2, 2), _violet)]),
  ),
);

const _day = Ground(
  ground: _hot,
  panel: _dayWell,
  text: _cold,
  quietText: _dayQuiet,
  faintText: _dayFaint,
  hairline: _dayRule,
  idle: _dayIdle,
  outline: _cold,
  edge: _cold,
  shadow: _dayStep,
  paper: _frost,
  paperEdge: _frostRule,
  // By day everything is hot, so the thing to press is the one cold thing.
  accent: _cold,
  onAccent: _hot,
  selection: _wolfOnDay,
  // The sun over the rooftops is white-hot.
  mark: _frost,
  onMark: _cold,
  pick: _wolf,
  onPick: _frost,
  danger: _wolf,
  onDanger: _frost,
  dangerText: _wolfOnDay,
  dangerLine: _wolf,
  disabled: _dayOff,
  onDisabled: _dayOffInk,
  elevation: GroundElevation(
    card: Elevation([HardShadow(Offset(3, 3), _dayStep)]),
    lying: Elevation([HardShadow(Offset(3, 3), _dayStep)]),
    raised: Elevation([HardShadow(Offset(4, 4), _dayStep)]),
    slab: Elevation([
      HardShadow(Offset(4, 4), _dayStep),
      HardShadow(Offset(8, 8), _ember),
    ]),
    heroSlab: Elevation([
      HardShadow(Offset(4, 4), _dayStep),
      HardShadow(Offset(8, 8), _wolf),
    ]),
    primary: Elevation([
      HardShadow(Offset(3, 3), _ember),
      HardShadow(Offset(6, 6), _wolf),
    ]),
    selected: Elevation([HardShadow(Offset(6, 6), _cold)]),
    badge: Elevation([HardShadow(Offset(2, 2), _dayStep)]),
  ),
);

const _paper = Ground(
  ground: _frost,
  panel: _frostWell,
  text: _cold,
  quietText: _frostQuiet,
  faintText: _frostQuiet,
  hairline: _frostRule,
  idle: _frostQuiet,
  outline: _cold,
  edge: _cold,
  shadow: _frostRule,
  paper: _frostWell,
  paperEdge: _frostRule,
  accent: _cold,
  onAccent: _frost,
  selection: _wolf,
  mark: _cold,
  onMark: _frost,
  pick: _wolf,
  onPick: _frost,
  danger: _wolf,
  onDanger: _frost,
  dangerText: _wolf,
  dangerLine: _wolf,
  disabled: _frostRule,
  onDisabled: _frostQuiet,
  elevation: GroundElevation(
    card: Elevation([HardShadow(Offset(3, 3), _frostRule)]),
    lying: Elevation([HardShadow(Offset(3, 3), _frostRule)]),
    raised: Elevation([HardShadow(Offset(4, 4), _frostRule)]),
    slab: Elevation([HardShadow(Offset(4, 4), _frostRule)]),
    heroSlab: Elevation([
      HardShadow(Offset(4, 4), _orange),
      HardShadow(Offset(8, 8), _magenta),
    ]),
    primary: Elevation([
      HardShadow(Offset(3, 3), _ember),
      HardShadow(Offset(6, 6), _wolf),
    ]),
    selected: Elevation([HardShadow(Offset(5, 5), _cold)]),
    badge: Elevation([HardShadow(Offset(2, 2), _frostRule)]),
  ),
);

const _display = 'Big Shoulders Display';
const _body = 'Barlow';

TextStyle _shoulders(double size, {required double height, double em = 0}) =>
    TextStyle(
      fontFamily: _display,
      fontWeight: FontWeight.w800,
      fontSize: size,
      height: height,
      letterSpacing: em * size,
    );

TextStyle _barlow(
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

// The brief's scale (design brief section 4), like every skin. Big Shoulders
// is tall and narrow, so the headings sit at the top of their ranges and the
// hero lines near theirs and still fit a 320 phone; its small sizes are let
// out a little. Barlow is a little narrow too, which leaves room to keep the
// reading text at 16 and above and captions, tags and badges at 14 and above;
// only the two labels set in capitals are smaller (the scale fixes `label`
// at 12).
final _type = SkinType(
  heroTitle: _shoulders(54, height: 0.95),
  heroCode: _shoulders(56, height: 1, em: 0.04),
  heroRole: _shoulders(58, height: 0.9),
  heroVerdict: _shoulders(52, height: 0.95),
  heroWinner: _shoulders(48, height: 0.95),
  display: _shoulders(36, height: 1),
  screenTitle: _shoulders(36, height: 1.05),
  headline: _shoulders(34, height: 1),
  title: _shoulders(28, height: 1.1, em: 0.005),
  tally: _shoulders(28, height: 1),
  heading: _shoulders(24, height: 1.05, em: 0.01),
  name: _shoulders(24, height: 1.05, em: 0.01),
  nameSmall: _shoulders(20, height: 1.05, em: 0.015),
  buttonLabelLarge: _shoulders(24, height: 1, em: 0.02),
  buttonLabel: _shoulders(23, height: 1, em: 0.02),
  buttonLabelSmall: _shoulders(21, height: 1, em: 0.02),
  timer: _shoulders(84, height: 0.9),
  timerVote: _shoulders(80, height: 0.9),
  timerSmall: _shoulders(64, height: 0.95),
  timerCompact: _shoulders(34, height: 1),
  bodyLarge: _barlow(17, FontWeight.w500, height: 1.35),
  lede: _barlow(17, FontWeight.w500, height: 1.3),
  body: _barlow(16, FontWeight.w500, height: 1.35),
  action: _barlow(16, FontWeight.w700, height: 1.2),
  code: _barlow(17, FontWeight.w700, height: 1.2, em: 0.12),
  small: _barlow(15, FontWeight.w500, height: 1.35),
  smallStrong: _barlow(15, FontWeight.w700, height: 1.35),
  caption: _barlow(14, FontWeight.w500, height: 1.3),
  tag: _barlow(14, FontWeight.w700, height: 1.2, em: 0.01),
  badge: _barlow(14, FontWeight.w700, height: 1.2),
  label: _barlow(12, FontWeight.w700, height: 1.4, em: 0.08),
  // The smallest label shares a row of four narrow tiles (S03): one size down
  // and set tighter, so its longest word is whole on a 360 phone.
  micro: _barlow(11, FontWeight.w700, height: 1.2, em: 0.03),
);

/// Warm blood's pictures: Shadow paper's, filmed by heat, with tokens that
/// fill a tile (its token frames are rounded squares).
const warmBloodArt = ArtSet(
  folder: 'assets/skins/warm_blood',
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
  heroPortraitFocus: Alignment(0, -0.76),
  sceneFocus: {
    Scene.candle: Alignment(0, 0.24),
    Scene.table: Alignment(0, 0.1),
    Scene.streetDoor: Alignment(0, -0.76),
    Scene.sleepingVillage: Alignment.topCenter,
    Scene.nightVillage: Alignment.topCenter,
    Scene.dawnGallows: Alignment(0, -0.2),
  },
);

final warmBlood = Skin(
  night: _night,
  day: _day,
  paper: _paper,
  typography: _type,
  // Only the weights the type roles use (800 of Big Shoulders Display, 500
  // and 700 of Barlow).
  fonts: const SkinFonts.onDemand({
    _display: [
      'assets/fonts/bigshouldersdisplay/BigShouldersDisplay-ExtraBold.ttf',
    ],
    _body: [
      'assets/fonts/barlow/Barlow-Medium.ttf',
      'assets/fonts/barlow/Barlow-Bold.ttf',
    ],
  }),
  // A screen, not paper: rounded plates with a thin dark line, tokens on
  // rounded tiles, and nothing tilted. An instrument sets things straight.
  shape: const SkinShape(
    radius: 10,
    radiusSmall: 6,
    radiusTiny: 4,
    sheetRadius: 16,
    rowLeadRoundness: 0.35,
    tokenRoundness: 0.35,
    badgeRoundness: 0.5,
    ring: 2,
    selectedRing: 3,
    stroke: 2,
    edgeWidth: 2,
    pressKeep: 0,
    pip: Size.square(10), // a sensor cell
    pipRoundness: 0.3,
    pipEmptyStroke: 0,
    pipStretch: false,
    archRoundness: 0.35,
  ),
  tilt: SkinTilt.none,
  art: warmBloodArt,
  scrim: _cold.withValues(alpha: 0.78),
  dimmed: 0.4,
  waiting: 0.35,
  recessed: 0.75,
);
