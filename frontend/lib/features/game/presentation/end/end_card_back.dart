import 'package:flutter/widgets.dart';

import '../../../../design_system/primitives/art_picture.dart';
import '../../../../design_system/primitives/board_pieces.dart';
import '../../../../design_system/primitives/fit_line.dart';
import '../../../../design_system/primitives/one_light.dart';
import '../../../../design_system/skin/card_back_scope.dart';
import '../../../../design_system/skin/skin.dart';

/// A [BoardCard] face down, as it lies before the end board's reveal turns it
/// (the reveal's own piece, built from the primitives):
/// the same size and shape, cut from the night's paper, the player's name on
/// it (when there is one) and the game's card back where the portrait will be.
/// Its shadow falls away from the one light, as the face's does.
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

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final night = skin.night;
    final light = OneLight.maybeOf(context);
    final elevation = context.ground.elevation.card;
    final shadows = light == null
        ? elevation.boxShadowsLeaning(0)
        : paperShadows(light, rect, elevation);
    final radius = BorderRadius.circular(skin.shape.radiusTiny);
    final body = DecoratedBox(
      decoration: ShapeDecoration(
        color: night.ground,
        shadows: shadows,
        shape: RoundedRectangleBorder(borderRadius: radius),
      ),
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
            SizedBox(
              width: portraitWidth,
              height: portraitWidth * 3 / 4,
              child: ClipRRect(
                borderRadius: radius,
                child: ArtPicture(context.cardBack),
              ),
            ),
          ],
        ),
      ),
    );
    return ExcludeSemantics(
      child: angle == 0 ? body : Transform.rotate(angle: angle, child: body),
    );
  }
}
