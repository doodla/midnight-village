part of 'shadow_paper.dart';

// The dressed-up Shadow paper (`Dress.paper`): what `context.skin` gives on a
// screen that asked for it. The same palette, type, art and scale as the plain
// skin; what differs is below: a warm day ground, quieter inks that keep 7:1 on
// the mood's own lights, paper that casts the two-layer paper shadow (never
// the plain look's hard copy), one 5 px corner, and the angles a piece of
// paper is set down at.

const _dawnGreyDr = Color(
  0xFFECD5C2,
); // day ground: warm paper light (mood: day)

const _amberBackingDr = Color(0xFFAB731F); // the plaque's darker paper under it

// What paper casts, by the ground it lies on (the mood recipe: a warm dark ink
// by day and on paper, the night's own deep indigo at night).
const _dayCastDr = Color(0xFF2A1D2B);

const _paperCastDr = Color(0xFF3B2E22);

const _moonQuietDr = Color(
  0xFFD6DBF0,
); // quiet text on night (7:1 on the brightest of the mood's pools)

const _moonFaintDr = Color(0xFFB0B6D9); // roles not in the deck (S03)

const _dayQuietDr = Color(0xFF1E1C30); // 7:1 on the day mood's darkest pixel

// Not in a mock: faint text on day. The mocks' #5a5670 fails AA on the day
// grey (4.4:1), so this is the nearest darker grey that passes (5.0:1).
const _dayFaintDr = Color(0xFF45415A);

const _nightDr = Ground(
  ground: _indigo,
  panel: _indigoWell,
  text: _bone,
  quietText: _moonQuietDr,
  faintText: _moonFaintDr,
  hairline: _nightHairline,
  idle: _moonQuietDr,
  outline: _moonQuietDr,
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
  onDisabled: _moonFaintDr,
  elevation: GroundElevation(
    card: Elevation([HardShadow.drop(Offset(0, 6), _deepShadow)]),
    lying: Elevation([HardShadow.drop(Offset(0, 8), _deepShadow)]),
    raised: Elevation([HardShadow.drop(Offset(0, 9), _deepShadow)]),
    slab: Elevation([
      HardShadow.edge(Offset(0, 5), _paperEdge),
      HardShadow.drop(Offset(0, 18), _deepShadow),
    ]),
    heroSlab: Elevation([
      HardShadow.edge(Offset(0, 5), _paperEdge),
      HardShadow.drop(Offset(0, 21), _deepShadow),
    ]),
    // The plaque: amber paper on a darker paper backing, and what it casts.
    primary: Elevation([
      HardShadow.edge(Offset(0, 5), _amberBackingDr),
      HardShadow.drop(Offset(0, 12), _deepShadow),
    ]),
    // A picked card at night lifts off the table (S06).
    selected: Elevation([HardShadow.drop(Offset(0, 15), _deepShadow)]),
    badge: Elevation([HardShadow.drop(Offset(0, 3), _deepShadow)]),
    glow: _boneGlow,
  ),
);

const _dayDr = Ground(
  ground: _dawnGreyDr,
  // Not in a mock: a box set into the day ground uses paper's inset tone.
  panel: _boneInset,
  text: _indigo,
  quietText: _dayQuietDr,
  faintText: _dayFaintDr,
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
  onDisabled: _dayQuietDr,
  elevation: GroundElevation(
    card: Elevation([HardShadow.drop(Offset(0, 6), _dayCastDr)]),
    lying: Elevation([HardShadow.drop(Offset(0, 8), _dayCastDr)]),
    raised: Elevation([HardShadow.drop(Offset(0, 9), _dayCastDr)]),
    slab: Elevation([
      HardShadow.edge(Offset(0, 5), _paperEdge),
      HardShadow.drop(Offset(0, 18), _dayCastDr),
    ]),
    heroSlab: Elevation([
      HardShadow.edge(Offset(0, 5), _paperEdge),
      HardShadow.drop(Offset(0, 21), _dayCastDr),
    ]),
    primary: Elevation([
      HardShadow.edge(Offset(0, 5), _amberBackingDr),
      HardShadow.drop(Offset(0, 12), _dayCastDr),
    ]),
    selected: Elevation([HardShadow.drop(Offset(0, 12), _dayCastDr)]),
    badge: Elevation([HardShadow.drop(Offset(0, 3), _dayCastDr)]),
  ),
);

const _paperDr = Ground(
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
    card: Elevation([HardShadow.drop(Offset(0, 6), _paperCastDr)]),
    lying: Elevation([HardShadow.drop(Offset(0, 8), _paperCastDr)]),
    raised: Elevation([HardShadow.drop(Offset(0, 9), _paperCastDr)]),
    slab: Elevation([HardShadow.drop(Offset(0, 8), _paperCastDr)]),
    // The portrait in the role sheet (S03b).
    heroSlab: Elevation([HardShadow.drop(Offset(0, 14), _paperCastDr)]),
    primary: Elevation([
      HardShadow.edge(Offset(0, 5), _amberBackingDr),
      HardShadow.drop(Offset(0, 10), _paperCastDr),
    ]),
    selected: Elevation([HardShadow.drop(Offset(0, 12), _paperCastDr)]),
    badge: Elevation([HardShadow.drop(Offset(0, 3), _paperCastDr)]),
  ),
);

final _shadowPaperDressed = Skin(
  night: _nightDr,
  day: _dayDr,
  paper: _paperDr,
  typography: _type,
  shape: const SkinShape(
    radius: 5, // one corner: every cut of paper
    radiusSmall: 5,
    radiusTiny: 5,
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
    seededCard: 2.5 * SkinTilt.degree, // set down by hand, from the id
    seededRow: 1.2 * SkinTilt.degree,
  ),
  art: shadowPaperArt,
  scrim: _deepShadow.withValues(alpha: 0.72),
  dimmed: 0.4, // S03
  dress: Dress.paper,
);
