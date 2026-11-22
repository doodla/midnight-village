import 'package:flutter/material.dart';

import '../../models/role.dart';
import '../art_set.dart';
import '../elevation.dart';
import '../ground.dart';
import '../skin.dart';
import '../skin_shape.dart';
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
const _blood = Color(0xFF80241E); // 7.4:1 under bone words
const _darkBlood = Color(0xFF5C0F0C); // the primary button's shadow at night
const _bloodLine = Color(0xFFC2413A); // thin red lines on night
const _bloodText = Color(0xFFF29D93); // red words on night (S11), 7.4:1
const _moonQuiet = Color(0xFFAAB0CF); // quiet text on night
const _moonFaint = Color(0xFF9EA4C8); // roles not in the deck (S03), 7.2:1
const _nightHairline = Color(0xFF2C3160);
const _dayShadow = Color(0xFF8F8A99); // rows' shadows, idle rings on day
const _dayQuiet = Color(0xFF36344B); // 7.5:1 on the day ground
const _paperQuiet = Color(0xFF3F3B54); // 8.3:1 on paper, 7.2 inset
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
  idle: _moonQuiet,
  outline: _moonQuiet,
  edge: _indigo,
  shadow: _deepShadow,
  paper: _bone,
  paperEdge: _paperEdge,
  accent: _amber,
  onAccent: _indigo,
  selection: _bone,
  mark: _bone,
  onMark: _indigo,
  danger: _blood,
  onDanger: _bone,
  dangerText: _bloodText,
  dangerLine: _bloodLine,
  disabled: _nightHairline,
  onDisabled: _moonFaint,
  elevation: GroundElevation(
    card: Elevation([HardShadow(Offset(3, 3), _deepShadow)]),
    lying: Elevation([HardShadow(Offset(0, 4), _deepShadow)]),
    raised: Elevation([HardShadow(Offset(4, 4), _deepShadow)]),
    slab: Elevation([
      HardShadow(Offset(0, 5), _paperEdge),
      HardShadow(Offset(0, 10), _deepShadow),
    ]),
    // The mock's amber layer is left out: amber is the primary button's
    // alone (first-time play spec, copy rule 10).
    heroSlab: Elevation([
      HardShadow(Offset(0, 5), _paperEdge),
      HardShadow(Offset(0, 11), _deepShadow),
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
  idle: _dayShadow,
  outline: _indigo,
  edge: _indigo,
  shadow: _dayShadow,
  paper: _bone,
  paperEdge: _paperEdge,
  // Amber by day too (the mocks' ink button read as another kind of
  // button), with an ink edge to stand off the grey.
  accent: _amber,
  onAccent: _indigo,
  accentEdge: _indigo,
  selection: _indigo,
  mark: _indigo,
  onMark: _bone,
  danger: _blood,
  onDanger: _bone,
  dangerText: _blood,
  dangerLine: _blood,
  disabled: _dayShadow,
  onDisabled: _dayQuiet,
  elevation: GroundElevation(
    card: Elevation([HardShadow(Offset(3, 3), _dayShadow)]),
    lying: Elevation([HardShadow(Offset(0, 4), _dayShadow)]),
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
  idle: _paperQuiet,
  outline: _indigo,
  edge: _indigo,
  shadow: _paperEdge,
  paper: _boneInset,
  paperEdge: _paperEdge,
  accent: _amber,
  onAccent: _indigo,
  accentEdge: _indigo,
  selection: _indigo,
  mark: _indigo,
  onMark: _bone,
  danger: _blood,
  onDanger: _bone,
  dangerText: _blood,
  dangerLine: _blood,
  disabled: _paperEdge,
  onDisabled: _paperQuiet,
  elevation: GroundElevation(
    card: Elevation([HardShadow(Offset(3, 3), _paperEdge)]),
    lying: Elevation([HardShadow(Offset(0, 4), _paperEdge)]),
    raised: Elevation([HardShadow(Offset(4, 4), _paperEdge)]),
    slab: Elevation([HardShadow(Offset(0, 5), _paperEdge)]),
    // The portrait in the role sheet (S03b).
    heroSlab: Elevation([HardShadow(Offset(5, 5), _blood)]),
    // The mock's sheet button (S03b) is the compact size: 4,4.
    primary: Elevation([HardShadow(Offset(5, 5), _blood)]),
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
  heroTitle: _gloock(46, height: 1, em: -0.02), // S01
  heroCode: _gloock(46, height: 1, em: 0.08), // S02
  heroVerdict: _gloock(44, height: 0.95, em: -0.01), // S10
  heroWinner: _gloock(40, height: 0.95, em: -0.01), // S11 (the picture)
  // S04's 58, to the hero scale's top.
  heroRole: _gloock(46, height: 0.9, em: -0.02), // S04
  display: _gloock(36, height: 0.95, em: -0.01), // S07, S10
  screenTitle: _gloock(34, height: 1.05, em: -0.01), // S05, S09
  headline: _gloock(32, height: 1, em: -0.01), // S03, S03b
  title: _gloock(26, height: 1.15, em: -0.01), // S06, S09
  tally: _gloock(28, height: 1), // S10
  heading: _gloock(24, height: 1), // S03 pace, S08, S10 names
  name: _gloock(21, height: 1.1), // S02
  nameSmall: _gloock(18, height: 1.1), // S06
  buttonLabelLarge: _gloock(21, height: 1), // S01, S04
  buttonLabel: _gloock(20, height: 1),
  buttonLabelSmall: _gloock(19, height: 1), // S01 Join, S03b Close
  timer: _gloock(84, height: 0.9, em: -0.02), // S08
  timerVote: _gloock(76, height: 0.9, em: -0.02), // S09
  timerSmall: _gloock(64, height: 1), // S05
  timerCompact: _gloock(34, height: 1), // S06
  bodyLarge: _figtree(17, FontWeight.w500, height: 1.35),
  lede: _figtree(16, FontWeight.w500, height: 1.3), // S01
  // The reading floor (first-time play spec, copy rule 7): 16 for what a
  // player reads to act (the mocks' 15), 14 for captions (their 12 and 13).
  body: _figtree(16, FontWeight.w600, height: 1.35),
  action: _figtree(16, FontWeight.w700, height: 1.2),
  code: _figtree(17, FontWeight.w700, height: 1.2, em: 0.12), // S01
  cue: _figtree(20, FontWeight.w700, height: 1.2),
  caption: _figtree(14, FontWeight.w600, height: 1.3),
  tag: _figtree(14, FontWeight.w700, height: 1.2),
  badge: _figtree(14, FontWeight.w700, height: 1.2),
);

const shadowPaperArt = ArtSet(
  folder: 'assets/skins/shadow_paper',
  rolePixels: Size(576, 768),
  tokenPixels: Size.square(192),
  scenePixels: {
    Scene.candle: Size(768, 1024),
    Scene.table: Size(1024, 768),
    Scene.streetDoor: Size(768, 1024),
    Scene.sleepingVillage: Size(768, 1024),
  },
  // Drawn at most 250 wide (S07): sharp at 2.4x.
  cardBackPixels: Size(600, 800),
  layered: {
    LayeredSceneId.nightVillage: _nightVillage,
    LayeredSceneId.dawnGallows: _dawnGallows,
  },
  // `object-position: 50% 15%` throughout the mocks.
  portraitFocus: Alignment(0, -0.7),
  // Read off the portraits in docs/design/art/ (the face's middle, from the
  // top): a held face cut short keeps it whole.
  faceCentres: {
    RoleId.doppelganger: 0.37,
    RoleId.drunk: 0.32,
    RoleId.hunter: 0.18,
    RoleId.insomniac: 0.35,
    RoleId.mason: 0.3,
    RoleId.minion: 0.5,
    RoleId.robber: 0.43,
    RoleId.seer: 0.41,
    RoleId.tanner: 0.31,
    RoleId.troublemaker: 0.36,
    RoleId.villager: 0.33,
    RoleId.werewolf: 0.35,
  },
  sceneFocus: {
    Scene.candle: Alignment(0, 0.24), // 50% 62%
    Scene.table: Alignment(0, 0.1), // 50% 55%
    Scene.streetDoor: Alignment(0, -0.76), // 50% 12%
    Scene.sleepingVillage: Alignment.topCenter, // 50% 0%
  },
);

/// 04's village (768 x 1024, `docs/design/art/layers/night-village/`):
/// the plate, then the clouds' shadows on the sky, the moon, the clouds'
/// shadows on the moon, and the clouds. Sizes and anchors are what
/// `just skin-art` prints for each cut. At rest they make the flat picture.
/// Brought in by the dusk the plate comes with the sheet (and further, the
/// screen's own `ArrivalShift`); then, inside the one scene, the clouds drift
/// to their places (`span` 0.3 to 0.85: the sheet lands at 0.85 of the
/// scene, 0.64 to the eye) and last the moon is lowered into its sky from
/// above the top edge, 220 canvas px (110 on a phone), over the second half
/// of the scene, after the sheet has landed. The paper is cut for 16 px of a
/// cloud's drift (the bleed); the moon may be anywhere, nothing of the plate
/// is under it and its shadows are cast by the clouds, not by where it is,
/// so they slide across it as it comes. Light from the upper left, so
/// shadows fall down and to the right.
const _nightVillage = LayeredScene(
  folder: 'night_village',
  canvas: Size(768, 1024),
  focus: Alignment.topCenter, // 50% 0%
  layers: [
    SceneLayer('village_plate', size: Size(768, 1024)),
    SceneLayer(
      'clouds_dark_shadow',
      size: Size(800, 311),
      anchor: Offset(-16, 4),
      from: Offset(-16, 0),
      span: _clouds,
    ),
    SceneLayer(
      'clouds_cream_shadow',
      size: Size(429, 332),
      anchor: Offset(355, 99),
      from: Offset(16, 0),
      span: _clouds,
    ),
    SceneLayer(
      'moon',
      size: Size(294, 332),
      anchor: Offset(453, 11),
      from: Offset(0, -220),
      span: _moon,
    ),
    SceneLayer(
      'moon_shadow_dark',
      size: Size(183, 115),
      anchor: Offset(585, 149),
      from: Offset(-16, 0),
      span: _clouds,
      clipTo: 'moon',
    ),
    SceneLayer(
      'moon_shadow_cream',
      size: Size(147, 48),
      anchor: Offset(412, 173),
      from: Offset(16, 0),
      span: _clouds,
      clipTo: 'moon',
    ),
    SceneLayer(
      'clouds_dark',
      size: Size(800, 166),
      anchor: Offset(-16, 79),
      from: Offset(-16, 0),
      span: _clouds,
    ),
    SceneLayer(
      'clouds_cream',
      size: Size(362, 177),
      anchor: Offset(422, 178),
      from: Offset(16, 0),
      span: _clouds,
    ),
  ],
);

/// The clouds settle after the sheet is down to the eye, and the moon after
/// them (`Motion.scene` is 500 ms: 150 to 425 ms, and 250 to 500 ms).
const _clouds = ArrivalSpan(0.3, 0.85);
const _moon = ArrivalSpan(0.5, 1);

/// 08's dawn (1024 x 768, `docs/design/art/layers/dawn-gallows/`): the sky,
/// the sun on its dotted path (the screen's own), the far hills that hide
/// the ends of the path, the birds, the middle roofs with the gallows
/// standing on them, and the near roofs. Brought in by the dawn the hills,
/// the middle roofs, the gallows and the near roofs rise from 300 canvas px
/// below as one bank (the paper under their seams is drawn 12 px deep, so
/// the near roofs start 12 px further down than the rest, no more, and no
/// edge of one is ever shown free of what hides it), the sun comes up from
/// behind the hills and the birds drift in; the sky stays. Light from the
/// upper right, so shadows fall down and to the left.
const _dawnGallows = LayeredScene(
  folder: 'dawn_gallows',
  canvas: Size(1024, 768),
  focus: Alignment(0, -0.2), // 50% 40%
  layers: [
    SceneLayer('sky_plate', size: Size(1024, 768)),
    SceneSlot(
      'sun',
      // The path over the hills (the mock's `M20 190 Q195 -40 370 190`, its
      // top raised so the sun clears the far ridge), in canvas pixels.
      arc: SceneArc(
        start: Offset(51.2, 543.4),
        control: Offset(512, -191.6),
        end: Offset(972.8, 543.4),
        // Just clear of the ridge at the start of the talk, and at its end
        // 60% of the disc still in view above the roofs (the timer's picture
        // is not gone before time is up); when a scene brings it in it starts 158 px
        // below the hills (which start 300 below their place) and comes up
        // from behind them.
        rise: 0.33,
        set: 0.79,
        dip: 458,
      ),
      // Its disc is 50 px in radius, the sprite's centre at (75, 75).
      sprite: SceneLayer('sun', size: Size(150, 150), anchor: Offset(-75, -75)),
    ),
    SceneLayer(
      'hills_far',
      size: Size(771, 208),
      anchor: Offset(253, 267),
      from: Offset(0, 300),
    ),
    SceneLayer(
      'birds',
      size: Size(921, 184),
      anchor: Offset(52, 58),
      from: Offset(-40, 30),
    ),
    SceneLayer(
      'roofs_mid',
      size: Size(627, 533),
      anchor: Offset(242, 247),
      from: Offset(0, 300),
    ),
    SceneLayer(
      'gallows',
      size: Size(284, 248),
      anchor: Offset(433, 204),
      from: Offset(0, 300),
    ),
    SceneLayer(
      'roofs_near',
      size: Size(1048, 620),
      anchor: Offset(-12, 160),
      from: Offset(0, 312),
    ),
  ],
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
    pipStretch: false,
    archRoundness: 1,
    paperLip: 3,
    paperShadow: 8,
  ),
  tilt: const SkinTilt(
    card: 0,
    stamp: 0,
    badge: 0,
    scatter: [-4 * SkinTilt.degree, 1 * SkinTilt.degree, 5 * SkinTilt.degree],
    thumb: -4 * SkinTilt.degree, // S08
    hero: -3 * SkinTilt.degree, // S11
  ),
  art: shadowPaperArt,
  scrim: _deepShadow.withValues(alpha: 0.72),
  dimmed: 0.4, // S03
);
