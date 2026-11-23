import 'package:flutter/widgets.dart';

import '../skin/dress.dart';
import '../skin/dress_style.dart';
import 'paper_piece.dart';
import '../skin/skin.dart';

/// A name plate: dressed up, a cut-paper tag (a [PaperPiece], the same as a
/// `TagChip`) behind words that would otherwise sit over the village or a
/// light, reaching a little past the words on every side (the skin's
/// `backingBleed`), so they keep their contrast whatever is behind
/// (`dressed_contrast_test.dart` measures it). The words on it are in
/// [inkOf]. PAINT ONLY: it takes no room and no touch, and the words keep the
/// box they had. On a plain screen there is no plate: [child] as it is.
class TextBacking extends StatelessWidget {
  const TextBacking({
    super.key,
    required this.child,
    this.id = 'plate',
    this.fill,
    this.part = PaperPart.tag,
    this.bleed,
  });

  final Widget child;

  /// Seeds the plate's tear and turn (the words it holds).
  final Object id;

  /// The plate's own paper (a role's team colour); the tag's ink where null.
  final Color? fill;

  /// The kind of paper the plate is cut from: a tag's, unless the caller
  /// names it (a component names its own part, so the inventory can check it).
  final PaperPart part;

  /// How far the plate reaches past the words (sideways, up and down): the
  /// skin's `backingBleed` where null.
  final Offset? bleed;

  /// The colour of words on a plate of [part]: the part's ink where dressed
  /// up, the ground's own text where there is no plate.
  static Color inkOf(BuildContext context, {PaperPart part = PaperPart.tag}) =>
      context.dress.isPaper
      ? PaperPiece.inkOf(context, part)
      : context.ground.text;

  @override
  Widget build(BuildContext context) {
    if (!context.dress.isPaper) return child;
    final bleed = this.bleed ?? context.skin.parts.backingBleed;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: -bleed.dx,
          right: -bleed.dx,
          top: -bleed.dy,
          bottom: -bleed.dy,
          child: IgnorePointer(
            child: PaperPiece(
              part: part,
              id: id,
              fill: fill,
              child: const SizedBox.expand(),
            ),
          ),
        ),
        child,
      ],
    );
  }
}
