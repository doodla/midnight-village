import 'dress_style.dart';

/// Every shared component of the design system and what it looks like in each
/// dress: the table `dress_inventory_test.dart` holds the code to (every
/// primitive file is here or in [notAComponent]; every entry has a sample on
/// the parts page, `test_screens/paper_parts_test.dart`; the README's table is
/// this list) and `paper_strokes_test.dart` paints in paper dress, failing on
/// any stroke, outline or border outside a `Drawn`.
///
/// A new component is added here, with its paper look, or the tests fail.
class PartEntry {
  const PartEntry(
    this.name,
    this.file, {
    required this.plain,
    required this.paper,
    this.part,
    this.built,
  });

  /// The component's class (or the family of classes) as screens know it.
  final String name;

  /// Under `lib/design_system/`.
  final String file;

  /// What it looks like on a plain screen (today's look, kept exactly).
  final String plain;

  /// What it looks like on a paper screen, in the one language
  /// (`dress_style.dart`).
  final String paper;

  /// The kind of paper it is made of (`PaperPiece`), where it is one.
  final PaperPart? part;

  /// The widget classes the parts page builds for it (`paper_components_test`
  /// finds them in the tree), where they are not its name's words (a family
  /// `A / B` is each of those words).
  final List<String>? built;
}

const inventory = <PartEntry>[
  // ---- Actions
  PartEntry(
    'PrimaryButton',
    'primitives/primary_button.dart',
    part: PaperPart.primary,
    plain:
        'amber fill, hard offset shadow, ink edge by day; waiting, locked and quiet are a 2 px outline',
    paper:
        'ready: one amber piece on a darker backing, only its label in it (a second smaller line under it where it has one: 08\'s count); waiting and locked (the night board\'s "Choose" slot too): the quietest piece there is, dark indigo paper barely lifted off the ground with its label saying why (one locked form, 4.5:1); quiet: a bone scrap; on (a toggle pressed, 08\'s "Ready ✓"): navy paper laid lower where the amber was, its words bone; done: words and the paper mark, no paper',
  ),
  PartEntry(
    'SecondaryButton',
    'primitives/secondary_button.dart',
    part: PaperPart.scrap,
    plain: '2 px outline on the ground, no fill ("paper": a raised paper tile)',
    paper: 'a bone scrap, lower lift than the amber; dimmed when waiting',
  ),
  PartEntry(
    'TextAction',
    'primitives/text_action.dart',
    plain: 'small button type, underlined, no fill',
    paper:
        'plain serif words in full ink, no underline, no paper; dims when pressed',
  ),
  PartEntry(
    'IconAction',
    'primitives/icon_action.dart',
    plain: 'Material icon button (the table\'s Share)',
    paper:
        'a bare ink glyph, no paper under it (it lies on a notice already); a press dims it, focus lifts it',
  ),
  PartEntry(
    'GlyphButton',
    'primitives/viewfinder.dart',
    part: PaperPart.scrap,
    plain: 'outlined square with a glyph; on = lift and fill',
    paper:
        'a bone scrap square with the glyph; on = lifted with the paper mark',
  ),
  PartEntry(
    'ValueStepper',
    'primitives/value_stepper.dart',
    part: PaperPart.disc,
    plain: 'two outlined round buttons round the value',
    paper:
        'two cut paper discs (minus, plus), sunk into the panel at the end of the range; the value in a well (paper sunk into the panel, the ground\'s own colour)',
  ),
  PartEntry(
    'HoldRing',
    'teach/hold_cue.dart',
    built: ['HoldCue'],
    plain: 'a ring that fills while the finger stays down, the word "Hold"',
    paper:
        'a navy paper disc with the word on it; the hold\'s progress an amber paper arc round it, filling clockwise over the same time (filled shapes only, no stroke)',
  ),
  PartEntry(
    'HoldToReveal',
    'primitives/hold_to_reveal.dart',
    built: ['FaceDownCard'],
    plain: 'a focus outline on the cover',
    paper: 'focus lifts the cover (a deeper shadow), no outline',
  ),
  // ---- Chips, tags, badges
  PartEntry(
    'PresetChip',
    'primitives/chips.dart',
    part: PaperPart.chip,
    plain: 'outlined box; the selected one lifts and takes a thicker ring',
    paper:
        "a cut-paper tag: picked = bone paper lifted high with a wax seal over its corner (its own form, `PaperPart.chipPicked`, never a button's); not picked = a flat, dim scrap of navy paper",
  ),
  PartEntry(
    'TagChip',
    'primitives/tag_chip.dart',
    part: PaperPart.tag,
    plain: 'flat fill in ink (danger for the Werewolf team)',
    paper:
        'a cut-paper tag; a team\'s tag (`TagChip.team`) is paper of the team\'s own colour on every surface: the Werewolf team red, the Village blue, the Tanner umber',
  ),
  PartEntry(
    'YouTag',
    'primitives/you_tag.dart',
    part: PaperPart.tag,
    plain: '"You" outlined in the row\'s ink; "Practice" bare words',
    paper:
        '"You" on a cut-paper tag in the ink of what it lies on (navy on a bone row, bone on the night), set in the tag face wherever it is',
  ),
  PartEntry(
    'CountBadge',
    'primitives/count_badge.dart',
    part: PaperPart.wax,
    plain: 'a filled round badge with the number',
    paper:
        'a drop of wax with the number in it (a `PaperPiece`, part wax), never a ring',
  ),
  PartEntry(
    'SeatDot / SlotMark',
    'primitives/dots.dart',
    part: PaperPart.disc,
    plain: 'filled disc or slip; empty ones outlined',
    paper:
        'filled paper disc or slip; empty ones a darker paper disc, no outline',
  ),
  PartEntry(
    'ProgressPips',
    'primitives/progress_pips.dart',
    part: PaperPart.pip,
    plain: 'plain pips (filled ink, empty hairline) and "N of M"',
    paper:
        'punched paper dots with a shadow; the unlit one a darker paper that keeps 3:1 against the ground',
  ),
  PartEntry(
    'ScrapLabel',
    'primitives/scrap_label.dart',
    part: PaperPart.scrap,
    plain: 'words in ink ("Edit")',
    paper: 'a small bone scrap with the words',
  ),
  // ---- Rows, slips, cards
  PartEntry(
    'PlayerRow',
    'primitives/player_row.dart',
    plain: 'paper row with a ring when picked or your own',
    paper:
        'a pinned torn slip, set down a hair off square; picked = lift and the paper mark; your own = the "You" tag; Tally strokes are strips of paper with a shadow',
  ),
  PartEntry(
    'PlayerToken',
    'primitives/player_token.dart',
    plain: 'round token art',
    paper:
        'a cut disc of paper with its shadow, the emblem laid in it (its printed rim left outside); never a ring',
  ),
  PartEntry(
    'RoleCard',
    'primitives/role_card.dart',
    plain: 'portrait with a ring (lit or hairline) and a count badge',
    paper:
        'a mini card cut from paper. IN the deck: full colour, lifted paper, the paper mark on its corner, the name on a bone tag, a count a wax badge on its lower corner. OUT: lowered paper with no shadow, its colour mostly gone and faded, no mark, the name on the quiet navy tag',
  ),
  PartEntry(
    'Fanned',
    'primitives/fanned.dart',
    plain: 'cards in a row',
    paper: 'cards fanned a hair, paint only',
  ),
  PartEntry(
    'FaceDownCard',
    'primitives/face_down_card.dart',
    plain: 'card back in a ring, hard shadow; picked = ring, lift, glow',
    paper:
        'two cut layers, a darker indigo one (never red) with the navy one laid on it a rim smaller, both deckled with their shadows (the card back\'s own printed rim and margin left outside, `CardBack.frameInset`); picked = lift, deeper shadow, the paper mark; no glow, no ring; a face-up card\'s role name on the quiet navy tag (never a team\'s colour); the one hero card on a deckled bone card like the face',
  ),
  PartEntry(
    'PaperCard',
    'primitives/paper_card.dart',
    plain: 'cut paper card, hard shadow',
    paper:
        'deckled paper with the paper shadow; pinned = a pin through each top corner (a notice)',
  ),
  PartEntry(
    'HeldFace',
    'faces/held_face.dart',
    plain:
        'the role card: portrait with a hairline frame, a rule above the text',
    paper:
        'the role card on paper, no frame and no rule; the same name, tag and lines as the sheet (`RoleHead`, `RoleText.lineSpan`)',
  ),
  PartEntry(
    'RoleSheetBody',
    'primitives/role_sheet_body.dart',
    plain: 'portrait, tags and the role\'s words on paper',
    paper:
        'the same on paper: the team tag above the name (`RoleHead`), "Night:" and "Wins:" in the strong face, the portrait a deckled picture',
  ),
  PartEntry(
    'PeekBox',
    'primitives/panels.dart',
    plain: 'a strip of night laid on the day with a card in it',
    paper:
        'a panel of night paper (deckled, with its shadow); its card two cut layers like every card back',
  ),
  PartEntry(
    'OutlinePanel',
    'primitives/panels.dart',
    part: PaperPart.panel,
    plain: '2 px hairline outline round a summary',
    paper:
        'a panel of paper set into the ground (a tone that stands off it by 1.25:1), deckled, with its shadow, no outline',
  ),
  // ---- Notices, fields, sheets
  PartEntry(
    'Notice',
    'primitives/notice.dart',
    plain: 'one line of words and a quiet action ("Not sent." "Try again")',
    paper: 'the same line, its action plain serif words',
  ),
  PartEntry(
    'QrPicture',
    'primitives/qr_picture.dart',
    plain: 'the code in the ground\'s ink',
    paper:
        'the same, on the pinned notice (a drawing, allowed: `Drawn.qrCode`)',
  ),
  PartEntry(
    'SkinField',
    'primitives/skin_field.dart',
    part: PaperPart.scrap,
    plain: 'name: raised paper tile; code: 2 px outline',
    paper:
        'name: a bone scrap; code: a panel of paper; lifted while it has the focus',
  ),
  PartEntry(
    'SheetScaffold',
    'primitives/sheet_scaffold.dart',
    plain: 'paper sheet with a lit strip along its top',
    paper:
        'a torn sheet of paper, no lit strip; its Close is plain serif words (`SheetClose`)',
  ),
  PartEntry(
    'Rule / SideRule',
    'primitives/rule.dart',
    plain: 'a hairline, or a line down a block\'s side',
    paper: 'no line: the room it takes',
  ),
  // ---- Banners, timer, marks
  PartEntry(
    'PaperBanner',
    'primitives/paper_banner.dart',
    plain: 'its words on the ground',
    paper: 'torn bone paper with two pins',
  ),
  PartEntry(
    'TextBacking',
    'primitives/text_backing.dart',
    plain: 'nothing',
    paper:
        'a name plate: a cut-paper tag behind the words (paint only), the words in the tag\'s ink',
  ),
  PartEntry(
    'Band / TimerBand',
    'primitives/band.dart',
    plain: 'a band with the clock, the sun or the bar',
    paper: 'the same band; the night board\'s sits on a banner',
  ),
  PartEntry(
    'WorldTimer',
    'primitives/world_timer.dart',
    plain: 'the seconds beside a candle on a panel with a hairline frame',
    paper: 'the same panel with no frame',
  ),
  PartEntry(
    'CandleGauge',
    'primitives/candle_gauge.dart',
    plain: 'the paper candle (art) on a ledge with a hairline',
    paper: 'the candle on a ledge with no hairline (the candle is art)',
  ),
  PartEntry(
    'PaperMark',
    'primitives/paper_mark.dart',
    plain: 'not drawn (a pick is a ring)',
    paper:
        'a drop of wax with a tick cut from paper laid on it (filled, with a shadow; no ring): the one mark for picked and done',
  ),
  PartEntry(
    'PaperSeal',
    'primitives/paper_seal.dart',
    plain: 'a scalloped seal with a padlock',
    paper: 'a disc of red wax with the padlock in bone, no ring',
  ),
  PartEntry(
    'PaperPin',
    'primitives/paper_pin.dart',
    plain: 'takes no room',
    paper: 'a flat pin: only where something is pinned (a notice, a slip)',
  ),
  // ---- Waiting
  PartEntry(
    'Pending / BusyMark',
    'primitives/pending.dart',
    plain: 'the control sinks with a small lantern in its padding',
    paper: 'the same, on the control\'s own paper',
  ),
  PartEntry(
    'Waiting',
    'primitives/waiting_sign.dart',
    built: ['PaperLantern'],
    plain: 'three paper lanterns on cords, lit one after another',
    paper: 'the same',
  ),
  PartEntry(
    'PaperLantern',
    'primitives/paper_lantern.dart',
    plain: 'a cut-paper lantern with a warm glow',
    paper:
        'cut from paper: a cord strip, filled ribs, no outline; the busy mark a punched lantern whose flame is a hole',
  ),
  // ---- Scanner
  PartEntry(
    'Viewfinder / ShutteredWindow',
    'primitives/viewfinder.dart',
    plain: 'a paper window with four corners; a closed one is outlined',
    paper:
        'the same window; a closed one is a recess of paper (the corners are a drawing, allowed: `Drawn.scanner`)',
  ),
  // ---- The end board
  PartEntry(
    'PaperScrap / PaperSlip',
    'primitives/paper_scrap.dart',
    part: PaperPart.scrap,
    plain: 'its words in the ground\'s ink, with the same 48 touch target',
    paper:
        'a scrap of bone paper pinned to the board (a scrap: the paper 40 tall, the touch target 48, a flat pin through its top left), its words in the name face; a slip is the same paper and says something, no tap',
  ),
  PartEntry(
    'VoteTag',
    'primitives/vote_tag.dart',
    plain: 'the voter\'s sigil and their name, no paper',
    paper:
        'a name tag of bone paper (the scrap\'s), its left end cut to a point, at least 26 tall, with a punched hole, the voter\'s sigil in a small disc and their name in the name face, set smaller rather than cut',
  ),
  PartEntry(
    'Twine',
    'primitives/twine.dart',
    plain:
        'the same thread (filled, never a stroke): solid for a move, gapped for a look, a head at its far end where it says a way',
    paper:
        'paper thread in bone, a sagging curve between two cards\' corners with a paper shadow away from the light; solid for a move, gapped for a look; with a head, a filled paper triangle at its far end, the way it went; red only for the Werewolf team',
  ),
  PartEntry(
    'StoryCardFace',
    'primitives/story_card.dart',
    plain: 'its tab\'s words and the role, no paper',
    paper:
        'a card of a night\'s picture story (08, My night held): a tab with whose it is in the name face, never cut, the role\'s portrait with its name on a strip at its foot (bone paper, the Werewolf team\'s red), or face down the game\'s card back on the back\'s dark rim; its shadow away from the light',
  ),
  PartEntry(
    'YouSeal',
    'primitives/you_seal.dart',
    plain: 'the player\'s own sigil alone',
    paper:
        'a blank seal of black wax pressed with the player\'s own sigil in grey, a disc of shadow away from the light',
  ),
  PartEntry(
    'InkStamp / DeathRibbon',
    'primitives/death_mark.dart',
    plain: 'the ribbon\'s picture alone; the stamp the same (no paper in it)',
    paper:
        'the black mourning ribbon pinned on a card\'s top right corner, a bone edge so it reads on red, a shadow away from the light; the stamp a narrow plate of dark ink in a double bone rule, its word in bone, bone lines bursting out round it, laid across a card\'s lower edge clear of the face and the role',
  ),
  PartEntry(
    'BoardCardBack',
    'primitives/board_card_back.dart',
    plain: 'the same card face down (the end board is paper only)',
    paper:
        'a board card face down before the reveal turns it: night paper with a bone edge, the name, the game\'s card back in a bone frame, every back of a board one portrait size',
  ),
  PartEntry(
    'FurledScroll',
    'primitives/furled_scroll.dart',
    plain: 'nothing (the end board is paper only)',
    paper:
        'the banner rolled up before it unrolls: a bone roll with its curl at each end, tied twice, a soft shadow under it',
  ),
  PartEntry(
    'BannerSlice / BoardFrame / BoardRoof',
    'primitives/sliced_art.dart',
    plain: 'the banner\'s words alone; no frame (the child as it is), no roof',
    paper:
        'a swallowtail banner of cut paper (bone, or red when the Werewolf team or the Tanner won) that stretches with its words, ends never distorted; a nine-slice frame of planks about 19 thick round felt with grain; a three-slice roof',
  ),
  PartEntry(
    'BoardCard / DealtCard / BoardLight / BoardFoot',
    'primitives/board_pieces.dart',
    plain: 'a card is its words alone; the rest draw nothing',
    paper:
        'a player\'s card pinned on the board: bone paper for a winner, dull for a loser (portrait darkened and drained), the Werewolf team\'s red, a name header, a 4:3 portrait with the role on a strip across its foot, a little darker the further it is from the lantern, its shadow away from it and bigger when raised; the small older sepia card tucked behind its corner; the lantern\'s warm pool on the living winners (screen blend) with the two darkenings; the cobbles with a torn lip and a shadow thrown up onto the board',
  ),
  PartEntry(
    'NameTag',
    'primitives/name_tag.dart',
    part: PaperPart.scrap,
    plain: 'the player\'s sigil and their name, no paper',
    paper:
        'a player in the square (08): a tag of bone paper set a hair off square, the player\'s sigil in a small disc (your own tag: your wax seal) and their name in the name face, set smaller rather than cut; not a button',
  ),
  PartEntry(
    'DeckPile',
    'primitives/deck_pile.dart',
    plain: 'the role\'s words alone ("3 Villagers")',
    paper:
        'one role of the deck in play: a board card (bone, the Werewolf team\'s red) with the role on the strip at its foot, the other copies fanned behind it; a tap or a hold opens the role',
  ),
  PartEntry(
    'SealedNote',
    'primitives/sealed_note.dart',
    part: PaperPart.scrap,
    plain: 'its words ("My night")',
    paper:
        'a folded note of bone paper, the flap a fold of the same paper (filled, no line), sealed with the player\'s own wax; held, it sinks into its shadow; until learned its seal lifts and settles once (the hold taught by doing it)',
  ),
  PartEntry(
    'SquareSky',
    'primitives/square_sky.dart',
    plain: 'the dawn\'s layers, the clock, the lantern\'s picture',
    paper:
        'a strip of night sky over the dawn\'s far roofs and gallows under a veil of the night, the clock large in its middle, the wall lantern lit at its right, the board\'s roof along its foot',
  ),
  PartEntry(
    'EndLantern',
    'primitives/end_lantern.dart',
    plain: 'the lantern\'s picture alone, no glow',
    paper:
        'the paper lantern, lit with a warm glow laid on with the screen blend; unlit, the same lantern with no glow',
  ),
];

/// Files in `primitives/` that are not a component a player sees as one: what
/// they are, so a new file must say.
const notAComponent = <String, String>{
  'primitives/screen_frame_layout.dart':
      'part of screen_frame.dart: how the screen lays its body out',
  'primitives/timer_band.dart':
      'part of band.dart: `TimerBand` is in the Band / TimerBand row',
  'primitives/art_picture.dart': 'draws a picture of the art set',
  'primitives/art_precache.dart': 'decodes art ahead; draws nothing',
  'primitives/cut_paper.dart': 'the plain decoration helpers',
  'primitives/deckle.dart': 'the torn-edge shape',
  'primitives/deckled_paper.dart':
      'the paper decoration helper `PaperPiece` uses',
  'primitives/drawn.dart': 'the allow-list of drawings',
  'primitives/faint_art.dart': 'a faint picture behind a screen',
  'primitives/fit_line.dart': 'text fitting; draws only words',
  'primitives/lantern_pool.dart': 'the lantern\'s light on the ground',
  'primitives/layered_art.dart': 'the layered village art',
  'primitives/mood.dart': 'the dressed screen\'s light behind everything',
  'primitives/nudge.dart': 'a short shake; draws nothing',
  'primitives/one_light.dart':
      'the end board\'s one light as a point: the lean and the dimming of every piece on it; draws nothing',
  'primitives/paper_flip.dart': 'the card turning; motion only',
  'primitives/paper_grain.dart': 'the paper\'s grain tile',
  'primitives/paper_light.dart': 'the screen\'s one light',
  'primitives/paper_piece.dart': 'the body of every paper component',
  'primitives/scene_arrival.dart': 'a scene change\'s clock',
  'primitives/scene_switcher.dart': 'a scene change',
  'primitives/screen_frame.dart': 'the screen',
  'primitives/tilted_paper.dart': 'turns paper a hair',
};
