import 'package:flutter/widgets.dart';

import '../skin/card_back_scope.dart';
import '../skin/ground.dart';
import '../skin/skin.dart';
import 'art_picture.dart';
import 'board_pieces.dart' show BoardCard;
import 'fit_line.dart';
import 'one_light.dart';

// Split from board_pieces.dart: the end board's card face down.

/// A [BoardCard] face down, as it lies before the end board's reveal turns it:
/// cut from the night's paper with a bone edge round it and round the game's
/// card back where the portrait will be (so it reads as a card on the dark
/// felt, as the mock's do), the player's name on it (when there is one) at
/// the name's own size. Its shadow falls away from the one light, as the
/// face's does. Its size is the caller's: every back of a board has one
/// portrait size, so no back says who won or who hangs.
class BoardCardBack extends StatelessWidget {
  const BoardCardBack({
    super.key,
    this.name,
    required this.size,
    required this.portraitWidth,
    required this.rect,
    this.angle = 0,
    this.headerHeight = BoardCard.defaultHeaderHeight,
  });

  final String? name;
  final Size size;
  final double portraitWidth;

  /// Where the card lies on the board, in the board's coordinates.
  final Rect rect;
  final double angle;
  final double headerHeight;

  /// The bone edge round the card and round its back's picture.
  static const edge = 1.5;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final night = skin.night;
    final bone = skin.paper.paper;
    final light = OneLight.maybeOf(context);
    final elevation = context.ground.elevation.card;
    final shadows = light == null
        ? elevation.boxShadowsLeaning(0)
        : paperShadows(light, rect, elevation);
    final radius = BorderRadius.circular(skin.shape.radiusTiny);
    // The edge is paper, not a stroke: the night card laid on a bone one a
    // hair larger, and the picture on its own bone mount.
    final body = DecoratedBox(
      decoration: ShapeDecoration(
        color: bone,
        shadows: shadows,
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),
      child: SizedBox.fromSize(
        size: size,
        child: Padding(
          padding: const EdgeInsets.all(edge),
          child: DecoratedBox(
            decoration: BoxDecoration(
              color: night.ground,
              borderRadius: radius,
            ),
            child: _face(context, night, bone, radius),
          ),
        ),
      ),
    );
    return ExcludeSemantics(
      child: angle == 0 ? body : Transform.rotate(angle: angle, child: body),
    );
  }

  Widget _face(
    BuildContext context,
    Ground night,
    Color bone,
    BorderRadius radius,
  ) {
    final skin = context.skin;
    return OverflowBox(
      alignment: Alignment.topCenter,
      maxWidth: size.width,
      maxHeight: size.height,
      child: SizedBox.fromSize(
        size: size,
        child: Column(
          children: [
            if (name != null)
              SizedBox(
                height: headerHeight,
                width: size.width,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: BoardCard.namePad,
                  ),
                  child: FitLine(
                    name!,
                    style: skin.typography.name.copyWith(color: night.text),
                  ),
                ),
              )
            else
              const SizedBox(height: BoardCard.inset),
            DecoratedBox(
              decoration: BoxDecoration(color: bone, borderRadius: radius),
              child: SizedBox(
                width: portraitWidth,
                height: portraitWidth * 3 / 4,
                child: Padding(
                  padding: const EdgeInsets.all(edge),
                  child: ClipRRect(
                    borderRadius: radius,
                    child: ArtPicture(context.cardBack),
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
