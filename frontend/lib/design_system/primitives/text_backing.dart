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
  });

  final Widget child;

  /// Seeds the plate's tear and turn (the words it holds).
  final Object id;

  /// The plate's own paper (a role's team colour); the tag's ink where null.
  final Color? fill;

  /// The kind of paper the plate is cut from: a tag's, unless the caller
  /// names it (a component names its own part, so the inventory can check it).
  final PaperPart part;

  /// The colour of words on a plate: the tag's ink where dressed up, the
  /// ground's own text where there is no plate.
  static Color inkOf(BuildContext context) => context.dress.isPaper
      ? PaperPiece.inkOf(context, PaperPart.tag)
      : context.ground.text;

  @override
  Widget build(BuildContext context) {
    if (!context.dress.isPaper) return child;
    final parts = context.skin.parts;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        Positioned(
          left: -parts.backingBleed.dx,
          right: -parts.backingBleed.dx,
          top: -parts.backingBleed.dy,
          bottom: -parts.backingBleed.dy,
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
