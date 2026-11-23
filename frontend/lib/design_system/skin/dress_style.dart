import 'package:flutter/foundation.dart' show immutable;

import 'dress.dart';

/// The one place a dressed-up (paper) component gets its look: a table keyed
/// by the kind of paper a component is ([PaperPart]), read by `PaperPiece`
/// (`primitives/paper_piece.dart`), which is the only thing that draws a
/// paper component's body. A component declares its part and never draws its
/// own fill, edge, shadow or border on a paper screen.
///
/// **The one language for paper** (the owner, 23 November 2026: "the paper look
/// is so inconsistent"): paper pieces are flat matte paper with a deckled edge
/// and the paper shadow of the screen's one light; NO strokes, outlines, inset
/// lines or borders anywhere (the paper's shape and its shadow are its edge);
/// no pin on a button (pins only where something is pinned to a board: a
/// notice, a slip, a tag); the primary action is one piece of amber paper on a
/// darker backing with nothing drawn in it but its label, and when it cannot
/// act yet it is that SAME piece dimmed to ochre with its label saying why
/// (one locked form: "Ready", "Choose a card", "Need 3 players"); a secondary
/// action is a bone scrap (same material, a lower lift); a quiet action is
/// plain serif words, no underline; chips and tags are cut-paper tags; picked
/// and done are the `PaperMark` only; focus is a lifted shadow. A state never
/// changes the material (`paper_material_test.dart`), and every piece's shadow
/// falls away from the screen's one light, with no halo
/// (`paper_shadow_test.dart`); a piece stands off what it lies on by 1.25:1
/// and a shadow, its words at 4.5:1 (`paper_separation_test.dart`). `dress_style_test.dart` fails any paper component
/// that paints a stroke outside the named allow-list (`Drawn`).
///
/// The plain dress keeps every component's own look exactly as it was (the
/// owner has not asked for those screens): [PartDress.plain] says in words
/// what that is, and `dress_inventory.dart` lists both for every component.
enum PaperPart {
  /// The screen's one amber action: amber paper on a darker backing.
  primary,

  /// A bone scrap: the secondary action, an icon action, a stepper's glyph.
  scrap,

  /// A cut-paper tag the player can pick (a chip), not picked: a dim, flat
  /// scrap of navy paper.
  chip,

  /// The chip that IS picked: bone paper lifted high, a wax seal over its
  /// corner. Its own form, so a picked chip is never read as a button (the
  /// bone scraps, which lie low and wear no seal).
  chipPicked,

  /// A cut-paper tag that only says something ("Werewolf", "You").
  tag,

  /// The quiet tag a player's name sits on over the night board: navy paper
  /// with bone words, so a name never outshouts the dark cards it names.
  nameTag,

  /// A small paper disc: a count, a seat, a progress pip.
  disc,

  /// A drop of wax with a number in it (a count on a card).
  wax,

  /// A punched paper dot of a count of progress: a disc with its own shadow
  /// (a little higher than a plain disc, so it shows on a dark ground).
  pip,

  /// A panel of paper laid on the ground (a field, the deck's box).
  panel,
}

/// What a paper material is made of.
enum PaperFill {
  /// The screen's one amber.
  amber,

  /// Bone paper, in the ink of the paper's text.
  bone,

  /// The ground's panel tone: paper set into the ground.
  inset,

  /// The ground's text colour as paper ("Village" tags).
  ink,
}

/// How high a piece lies above what is under it: the elevation of the
/// ground it is on.
enum PaperRaise { primary, card, badge, lifted, none }

/// How rough the torn edge is (`skin.parts`).
enum PaperEdge { standard, plaque, pinned }

@immutable
class PartLook {
  const PartLook({
    required this.fill,
    required this.raise,
    this.edge = PaperEdge.standard,
    this.tilted = true,
    this.round = false,
    this.blob = false,
    this.seal = false,
  });

  final PaperFill fill;
  final PaperRaise raise;
  final PaperEdge edge;

  /// Set down a hair off square, from its id (the words stay level).
  final bool tilted;

  /// A disc, not a torn rectangle.
  final bool round;

  /// A drop of wax (a count), not a cut disc.
  final bool blob;

  /// Wears a wax seal over its corner (a picked chip).
  final bool seal;
}

/// A part's look in both dresses.
@immutable
class PartDress {
  const PartDress({required this.plain, required this.paper});

  /// What the plain dress draws (its component's own code, kept as it was).
  final String plain;

  /// What the paper dress draws, in the one language above.
  final PartLook paper;
}

abstract final class DressStyle {
  static const parts = <PaperPart, PartDress>{
    PaperPart.primary: PartDress(
      plain: 'amber fill, hard offset shadow, ink edge by day',
      paper: PartLook(
        fill: PaperFill.amber,
        raise: PaperRaise.primary,
        edge: PaperEdge.plaque,
      ),
    ),
    PaperPart.scrap: PartDress(
      plain: '2 px outline on the ground, no fill',
      paper: PartLook(fill: PaperFill.bone, raise: PaperRaise.card),
    ),
    PaperPart.chip: PartDress(
      plain: 'outlined box, ring when selected',
      paper: PartLook(fill: PaperFill.inset, raise: PaperRaise.badge),
    ),
    PaperPart.chipPicked: PartDress(
      plain: 'outlined box, ring when selected',
      paper: PartLook(
        fill: PaperFill.bone,
        raise: PaperRaise.lifted,
        seal: true,
      ),
    ),
    PaperPart.tag: PartDress(
      plain: 'flat fill (ink), or an outline for "You"',
      paper: PartLook(fill: PaperFill.ink, raise: PaperRaise.badge),
    ),
    PaperPart.nameTag: PartDress(
      plain: 'the name as words, no plate',
      paper: PartLook(fill: PaperFill.inset, raise: PaperRaise.badge),
    ),
    PaperPart.disc: PartDress(
      plain: 'flat disc, outlined when empty',
      paper: PartLook(
        fill: PaperFill.bone,
        raise: PaperRaise.badge,
        tilted: false,
        round: true,
      ),
    ),
    PaperPart.pip: PartDress(
      plain: 'flat pips: filled ink, an empty hairline',
      paper: PartLook(
        fill: PaperFill.bone,
        raise: PaperRaise.card,
        tilted: false,
        round: true,
      ),
    ),
    PaperPart.wax: PartDress(
      plain: 'a filled round badge with the number',
      paper: PartLook(
        fill: PaperFill.ink,
        raise: PaperRaise.badge,
        tilted: false,
        round: true,
        blob: true,
      ),
    ),
    PaperPart.panel: PartDress(
      plain: '2 px hairline outline, no fill',
      paper: PartLook(fill: PaperFill.inset, raise: PaperRaise.card),
    ),
  };

  /// The paper look of [part] (a paper component asks nothing else).
  static PartLook paper(PaperPart part) => parts[part]!.paper;

  /// The look [part] has in [dress]: null where the dress keeps the
  /// component's own plain code.
  static PartLook? of(PaperPart part, Dress dress) =>
      dress.isPaper ? paper(part) : null;
}
