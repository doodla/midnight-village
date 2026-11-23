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
        'ready: one amber piece on a darker backing, only its label in it; locked, waiting and quiet: a bone scrap (faded when waiting); the waiting "Choose" slot: a darker recess; done: words and the paper mark, no paper',
  ),
  PartEntry(
    'SecondaryButton',
    'primitives/secondary_button.dart',
    part: PaperPart.scrap,
    plain: '2 px outline on the ground, no fill ("paper": a raised paper tile)',
    paper: 'a bone scrap, lower lift than the amber; faded when waiting',
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
    part: PaperPart.scrap,
    plain: 'Material icon button (the table\'s Share)',
    paper: 'a bone scrap square with the glyph',
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
        'two bone paper discs (minus, plus), faded at the end of the range; the value on a ground backing',
  ),
  PartEntry(
    'HoldRing',
    'teach/hold_cue.dart',
    plain: 'a ring that fills while the finger stays down, the word "Hold"',
    paper: 'the same gauge (a drawing, allowed: `Drawn.holdGauge`)',
  ),
  PartEntry(
    'HoldToReveal',
    'primitives/hold_to_reveal.dart',
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
        'a cut-paper tag: bone, lifted and wearing the paper mark when selected; a darker scrap when not',
  ),
  PartEntry(
    'TagChip',
    'primitives/tag_chip.dart',
    part: PaperPart.tag,
    plain: 'flat fill in ink (danger for the Werewolf team)',
    paper: 'a cut-paper tag in the same colours, with the badge shadow',
  ),
  PartEntry(
    'YouTag',
    'primitives/you_tag.dart',
    part: PaperPart.tag,
    plain: '"You" outlined in the row\'s ink; "Practice" bare words',
    paper:
        '"You" on a cut-paper tag a shade darker than its row; "Practice" bare words',
  ),
  PartEntry(
    'CountBadge',
    'primitives/count_badge.dart',
    plain: 'a filled round badge with the number',
    paper: 'the same flat disc with the badge shadow (never a ring)',
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
    plain: 'plain pips (filled ink, empty hairline) and "N of M"',
    paper: 'the same flat pips and words (no outline in either)',
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
        'a pinned torn slip, set down a hair off square; picked = lift and the paper mark; your own = the "You" tag; Tally strokes are a drawing (`Drawn.tally`)',
  ),
  PartEntry(
    'PlayerToken',
    'primitives/player_token.dart',
    plain: 'round token art',
    paper: 'the same token art',
  ),
  PartEntry(
    'RoleCard',
    'primitives/role_card.dart',
    plain: 'portrait with a ring (lit or hairline) and a count badge',
    paper:
        'the portrait as a piece of paper with its shadow, no ring; the count badge on its corner',
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
        'card back as paper with its shadow, no ring; picked = lift, deeper shadow, glow and the paper mark on its corner',
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
    paper: 'the role card on paper, no frame and no rule',
  ),
  PartEntry(
    'RoleSheetBody',
    'primitives/role_sheet_body.dart',
    plain: 'portrait, tags and the role\'s words on paper',
    paper: 'the same on paper, its tags cut-paper tags',
  ),
  PartEntry(
    'PeekBox',
    'primitives/panels.dart',
    plain: 'a strip of night laid on the day with a card in it',
    paper: 'the same strip, paper shadow, no edge line',
  ),
  PartEntry(
    'OutlinePanel',
    'primitives/panels.dart',
    part: PaperPart.panel,
    plain: '2 px hairline outline round a summary',
    paper: 'a panel of paper set into the ground (darker tone), no outline',
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
    paper: 'a torn sheet of paper, no lit strip; its buttons are scraps',
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
    paper: 'a solid backing behind words that sit over the village',
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
        'wax, a pressed ring and a brush tick: the one mark for picked and done (a drawing, allowed: `Drawn.mark`)',
  ),
  PartEntry(
    'PaperSeal',
    'primitives/paper_seal.dart',
    plain: 'a scalloped seal with a padlock',
    paper: 'the same (a drawing, allowed: `Drawn.mark`)',
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
    plain: 'three paper lanterns on cords, lit one after another',
    paper: 'the same',
  ),
  PartEntry(
    'PaperLantern',
    'primitives/paper_lantern.dart',
    plain: 'a cut-paper lantern with a warm glow',
    paper: 'the same (a drawing, allowed: `Drawn.lantern`)',
  ),
  // ---- Scanner
  PartEntry(
    'Viewfinder / ShutteredWindow',
    'primitives/viewfinder.dart',
    plain: 'a paper window with four corners; a closed one is outlined',
    paper:
        'the same window; a closed one is a recess of paper (the corners are a drawing, allowed: `Drawn.scanner`)',
  ),
];

/// Files in `primitives/` that are not a component a player sees as one: what
/// they are, so a new file must say.
const notAComponent = <String, String>{
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
  'primitives/paper_flip.dart': 'the card turning; motion only',
  'primitives/paper_grain.dart': 'the paper\'s grain tile',
  'primitives/paper_light.dart': 'the screen\'s one light',
  'primitives/paper_piece.dart': 'the body of every paper component',
  'primitives/scene_arrival.dart': 'a scene change\'s clock',
  'primitives/scene_switcher.dart': 'a scene change',
  'primitives/screen_frame.dart': 'the screen',
  'primitives/tilted_paper.dart': 'turns paper a hair',
};
