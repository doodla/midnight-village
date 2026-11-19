import 'package:flutter/material.dart';

import '../art_set.dart';
import '../elevation.dart';
import '../ground.dart';
import '../skin.dart';
import '../skin_motion.dart';
import '../skin_shape.dart';
import '../skin_spacing.dart';
import '../skin_tilt.dart';
import '../skin_type.dart';

// "Shadow paper" (design brief section 2, mocks docs/design/mocks/S*.dc.html).
// Every value is the mocks' unless its comment says otherwise.

// Palette.
const _indigo = Color(0xFF14172F); // night ground; ink on paper
const _indigoWell = Color(0xFF1D2145); // the night timer's panel (S05)
const _deepShadow = Color(0xFF07091A);
const _dawnGrey = Color(0xFFCFCBD6); // day ground
const _bone = Color(0xFFE9E2D0); // paper; text on night
const _boneInset = Color(0xFFDCD4BF); // a box set into paper (S03b)
const _paperEdge = Color(0xFFBFB69F);
const _amber = Color(0xFFE3A13A); // the one warm accent
const _blood = Color(0xFF8F2A24);
const _darkBlood = Color(0xFF5C0F0C); // the primary button's shadow at night
const _bloodLine = Color(0xFFC2413A); // thin red lines on night
const _bloodText = Color(0xFFE0786C); // red words on night (S11)
const _moonQuiet = Color(0xFFAAB0CF); // quiet text on night
const _moonFaint = Color(0xFF8A90B4); // roles not in the deck (S03)
const _nightHairline = Color(0xFF2C3160);
const _dayShadow = Color(0xFF8F8A99); // rows' shadows, idle rings on day
const _dayQuiet = Color(0xFF3B3950);
const _paperQuiet = Color(0xFF5A5670);
// Not in a mock: faint text on day. The mocks' #5a5670 fails AA on the day
// grey (4.4:1), so this is the nearest darker grey that passes (5.0:1).
const _dayFaint = Color(0xFF524E66);

const _night = Ground(
  ground: _indigo,
  panel: _indigoWell,
  text: _bone,
  quietText: _moonQuiet,
  faintText: _moonFaint,
  hairline: _nightHairline,
  outline: _moonQuiet,
  edge: _indigo,
  shadow: _deepShadow,
  paper: _bone,
  paperEdge: _paperEdge,
  accent: _amber,
  onAccent: _indigo,
  selection: _amber,
  mark: _amber,
  onMark: _indigo,
  pick: _blood,
  onPick: _bone,
  danger: _blood,
  onDanger: _bone,
  dangerText: _bloodText,
  dangerLine: _bloodLine,
  disabled: _nightHairline,
  onDisabled: _moonFaint,
  elevation: GroundElevation(
    card: Elevation([HardShadow(Offset(3, 3), _deepShadow)]),
    raised: Elevation([HardShadow(Offset(4, 4), _deepShadow)]),
    slab: Elevation([
      HardShadow(Offset(0, 5), _paperEdge),
      HardShadow(Offset(0, 10), _deepShadow),
    ]),
    heroSlab: Elevation([
      HardShadow(Offset(0, 5), _paperEdge),
      HardShadow(Offset(0, 11), _amber),
      HardShadow(Offset(0, 17), _deepShadow),
    ]),
    primary: Elevation([HardShadow(Offset(5, 5), _darkBlood)]),
    // A picked card at night lifts off the table (S06).
    selected: Elevation([HardShadow(Offset(0, 8), _deepShadow)]),
    badge: Elevation([HardShadow(Offset(0, 2), _deepShadow)]),
  ),
);

const _day = Ground(
  ground: _dawnGrey,
  // Not in a mock: a box set into the day ground uses paper's inset tone.
  panel: _boneInset,
  text: _indigo,
  quietText: _dayQuiet,
  faintText: _dayFaint,
  hairline: _dayShadow,
  outline: _indigo,
  edge: _indigo,
  shadow: _dayShadow,
  paper: _bone,
  paperEdge: _paperEdge,
  accent: _indigo,
  onAccent: _bone,
  selection: _blood,
  mark: _amber,
  onMark: _indigo,
  pick: _blood,
  onPick: _bone,
  danger: _blood,
  onDanger: _bone,
  dangerText: _blood,
  dangerLine: _blood,
  disabled: _dayShadow,
  onDisabled: _dayQuiet,
  elevation: GroundElevation(
    card: Elevation([HardShadow(Offset(3, 3), _dayShadow)]),
    raised: Elevation([HardShadow(Offset(4, 4), _dayShadow)]),
    slab: Elevation([
      HardShadow(Offset(0, 5), _paperEdge),
      HardShadow(Offset(0, 10), _dayShadow),
    ]),
    heroSlab: Elevation([
      HardShadow(Offset(0, 5), _paperEdge),
      HardShadow(Offset(0, 10), _blood),
    ]),
    primary: Elevation([HardShadow(Offset(5, 5), _blood)]),
    selected: Elevation([HardShadow(Offset(4, 4), _indigo)]),
    badge: Elevation([HardShadow(Offset(0, 2), _dayShadow)]),
  ),
);

const _paper = Ground(
  ground: _bone,
  panel: _boneInset,
  text: _indigo,
  quietText: _paperQuiet,
  faintText: _paperQuiet,
  hairline: _paperEdge,
  outline: _indigo,
  edge: _indigo,
  shadow: _paperEdge,
  paper: _boneInset,
  paperEdge: _paperEdge,
  accent: _indigo,
  onAccent: _bone,
  selection: _blood,
  mark: _amber,
  onMark: _indigo,
  pick: _blood,
  onPick: _bone,
  danger: _blood,
  onDanger: _bone,
  dangerText: _blood,
  dangerLine: _blood,
  disabled: _paperEdge,
  onDisabled: _paperQuiet,
  elevation: GroundElevation(
    card: Elevation([HardShadow(Offset(3, 3), _paperEdge)]),
    raised: Elevation([HardShadow(Offset(4, 4), _paperEdge)]),
    slab: Elevation([HardShadow(Offset(0, 5), _paperEdge)]),
    // The portrait in the role sheet (S03b).
    heroSlab: Elevation([HardShadow(Offset(5, 5), _blood)]),
    primary: Elevation([HardShadow(Offset(4, 4), _blood)]),
    selected: Elevation([HardShadow(Offset(4, 4), _indigo)]),
    badge: Elevation([HardShadow(Offset(0, 2), _paperEdge)]),
  ),
);

const _display = 'Gloock';
const _body = 'Figtree';

TextStyle _gloock(double size, {required double height, double em = 0}) =>
    TextStyle(
      fontFamily: _display,
      fontWeight: FontWeight.w400,
      fontSize: size,
      height: height,
      letterSpacing: em * size,
    );

TextStyle _figtree(
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

final _type = SkinType(
  display: _gloock(36, height: 1, em: -0.01),
  headline: _gloock(32, height: 1, em: -0.01),
  title: _gloock(26, height: 1.15, em: -0.01),
  heading: _gloock(24, height: 1),
  name: _gloock(21, height: 1.1),
  nameSmall: _gloock(18, height: 1.1),
  buttonLabel: _gloock(20, height: 1),
  timer: _gloock(84, height: 0.9, em: -0.02),
  timerSmall: _gloock(64, height: 1),
  bodyLarge: _figtree(17, FontWeight.w500, height: 1.35),
  body: _figtree(15, FontWeight.w600, height: 1.35),
  action: _figtree(15, FontWeight.w700, height: 1.2),
  small: _figtree(14, FontWeight.w600, height: 1.35),
  caption: _figtree(13, FontWeight.w600, height: 1.3),
  tag: _figtree(13, FontWeight.w700, height: 1.2),
  badge: _figtree(12, FontWeight.w700, height: 1.2),
  label: _figtree(12, FontWeight.w700, height: 1.4, em: 0.14),
  micro: _figtree(11, FontWeight.w700, height: 1.2, em: 0.1),
);

const shadowPaperSpacing = SkinSpacing(
  xxs: 4,
  xs: 6,
  sm: 8,
  md: 12,
  lg: 16,
  xl: 24,
  xxl: 32,
  gutter: 24,
  screenTop: 40,
  screenBottom: 28,
);

/// Not in a mock (the mocks are still pictures): short, firm movements.
const shadowPaperMotion = SkinMotion(
  press: Duration(milliseconds: 90),
  quick: Duration(milliseconds: 160),
  settle: Duration(milliseconds: 260),
  reveal: Duration(milliseconds: 400),
  curve: Curves.easeOutCubic,
);

const shadowPaperArt = ArtSet(
  folder: 'assets/skins/shadow_paper',
  drawnTokens: {
    TokenId.crow,
    TokenId.key,
    TokenId.moth,
    TokenId.bell,
    TokenId.thorn,
  },
  // `object-position: 50% 15%` throughout the mocks.
  portraitFocus: Alignment(0, -0.7),
  sceneFocus: {
    Scene.candle: Alignment(0, 0.24), // 50% 62%
    Scene.table: Alignment(0, 0.1), // 50% 55%
    Scene.streetDoor: Alignment(0, -0.76), // 50% 12%
    Scene.sleepingVillage: Alignment.topCenter,
    Scene.dawnGallows: Alignment(0, -0.2), // 50% 40%
  },
);

final shadowPaper = Skin(
  night: _night,
  day: _day,
  paper: _paper,
  typography: _type,
  shape: const SkinShape(
    radius: 6,
    radiusSmall: 4,
    radiusTiny: 3,
    sheetRadius: 14,
    rowLeadRoundness: 1,
    tokenRoundness: 1,
    badgeRoundness: 1,
    ring: 2,
    selectedRing: 3,
    stroke: 2,
    edgeWidth: 0,
    pressKeep: 0.2,
    pip: Size.square(12),
    pipRoundness: 1,
    pipEmptyStroke: 0,
  ),
  spacing: shadowPaperSpacing,
  motion: shadowPaperMotion,
  tilt: SkinTilt.none,
  art: shadowPaperArt,
  scrim: _deepShadow.withValues(alpha: 0.72),
  dimmed: 0.4,
);
