import 'package:flutter/material.dart';

import '../elevation.dart';
import '../ground.dart';
import '../skin.dart';
import '../skin_shape.dart';
import '../skin_tilt.dart';
import '../skin_type.dart';
import 'shadow_paper.dart';

// "Night print": a linocut poster (mock row E: E_Card, E_Vote, E_Results).
// Values are the mocks' unless a comment says otherwise. Spacing, motion and
// (until Night print has its own) the art are Shadow paper's.

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
  outline: _cream,
  edge: _ink,
  shadow: _ink,
  paper: _paperCream,
  paperEdge: _ink,
  // At night the primary button is a cream print with a red shadow (E_Card).
  accent: _paperCream,
  onAccent: _ink,
  selection: _amber,
  mark: _amber,
  onMark: _ink,
  pick: _deepRed,
  onPick: _paperCream,
  danger: _deepRed,
  onDanger: _paperCream,
  dangerText: _stampPink,
  dangerLine: _red,
  disabled: _nightRule,
  onDisabled: _nightFaint,
  elevation: GroundElevation(
    card: Elevation([HardShadow(Offset(6, 6), _ink)]),
    raised: Elevation([HardShadow(Offset(4, 4), _ink)]),
    slab: Elevation([HardShadow(Offset(10, 10), _amber)]),
    heroSlab: Elevation([HardShadow(Offset(10, 10), _amber)]),
    primary: Elevation([HardShadow(Offset(6, 6), _red)]),
    selected: Elevation([HardShadow(Offset(6, 6), _amber)]),
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
  outline: _ink,
  edge: _ink,
  shadow: _ink,
  paper: paper,
  paperEdge: _ink,
  accent: _ink,
  onAccent: _paperCream,
  selection: _deepRed,
  mark: _amber,
  onMark: _ink,
  pick: _deepRed,
  onPick: _paperCream,
  danger: _deepRed,
  onDanger: _paperCream,
  dangerText: _deepRed,
  dangerLine: _red,
  disabled: _creamRule,
  onDisabled: _creamQuiet,
  elevation: const GroundElevation(
    card: Elevation([HardShadow(Offset(5, 5), _ink)]),
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

TextStyle _rozha(double size, {required double height}) => TextStyle(
  fontFamily: _display,
  fontWeight: FontWeight.w400,
  fontSize: size,
  height: height,
  letterSpacing: 0,
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

// The mocks set headings up to 58; the brief caps them at 36, so Night print
// keeps Shadow paper's sizes there. Alegreya Sans is small on the body, so
// body text is a size up from Figtree's (the mocks use 15 to 18).
final _type = SkinType(
  display: _rozha(36, height: 0.95),
  headline: _rozha(32, height: 0.95),
  title: _rozha(26, height: 1.05),
  heading: _rozha(24, height: 1),
  name: _rozha(22, height: 1.05),
  nameSmall: _rozha(18, height: 1.05),
  buttonLabel: _rozha(22, height: 1),
  timer: _rozha(84, height: 0.9),
  timerSmall: _rozha(64, height: 0.9),
  bodyLarge: _alegreya(18, FontWeight.w500, height: 1.3),
  body: _alegreya(16, FontWeight.w500, height: 1.3),
  action: _alegreya(16, FontWeight.w800, height: 1.2),
  small: _alegreya(15, FontWeight.w500, height: 1.3),
  caption: _alegreya(14, FontWeight.w500, height: 1.3),
  tag: _alegreya(13, FontWeight.w800, height: 1.2, em: 0.08),
  badge: _alegreya(13, FontWeight.w800, height: 1.2),
  label: _alegreya(13, FontWeight.w800, height: 1.3, em: 0.2),
  micro: _alegreya(11, FontWeight.w800, height: 1.2, em: 0.16),
);

final nightPrint = Skin(
  night: _night,
  day: _onCream(ground: _cream, paper: _paperCream),
  paper: _onCream(ground: _paperCream, paper: _creamWell),
  typography: _type,
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
  ),
  spacing: shadowPaperSpacing,
  motion: shadowPaperMotion,
  tilt: const SkinTilt(
    card: -1.2 * SkinTilt.degree,
    stamp: -5 * SkinTilt.degree,
    badge: 6 * SkinTilt.degree,
  ),
  art: shadowPaperArt,
  scrim: _ink.withValues(alpha: 0.72),
  dimmed: 0.4,
);
