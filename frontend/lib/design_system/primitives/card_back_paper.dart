import 'package:flutter/material.dart';

import '../models/role.dart';
import '../skin/card_back_scope.dart';
import '../skin/werewolf_portrait.dart';
import '../skin/skin.dart';
import 'art_picture.dart';
import 'deckle.dart';
import 'deckled_paper.dart';
import '../skin/elevation.dart';

/// A card of dressed paper: a layer of red (or bone, for a face) paper with the
/// card's navy paper laid on it a rim smaller, both deckled, the lower with a
/// shadow cast by the paper above it. The picture inside is the card's art
/// as it is, its own printed edge left outside the navy layer (`CardBack.
/// frameInset`); the edge of the card is two cut layers and their shadows,
/// never a line. [face] shows a role instead of the back.
class CardBackPaper extends StatelessWidget {
  const CardBackPaper({
    super.key,
    required this.id,
    required this.elevation,
    this.face,
    this.over,
  });

  final Object id;

  /// What the whole card casts.
  final Elevation elevation;
  final RoleId? face;

  /// Laid over the picture (the hold ring).
  final Widget? over;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final ground = context.ground;
    final parts = skin.parts;
    final art = face == null ? context.cardBack : context.roleArt(face!);
    final inset = face == null ? CardBackScope.of(context).frameInset : 0.0;
    return LayoutBuilder(
      builder: (context, box) {
        final rim = (box.maxWidth * 0.035).clamp(2.0, 5.0);
        final top = DeckleBorder(
          seed: deckleSeed((id, 'top')),
          depth: parts.deckleDepth,
          step: parts.deckleStep,
        );
        return Stack(
          fit: StackFit.expand,
          children: [
            DecoratedBox(
              decoration: deckledPaper(
                context,
                fill: face == null ? parts.cardRim : ground.paper,
                id: (id, 'rim'),
                elevation: elevation,
                depth: parts.deckleDepth,
                step: parts.deckleStep,
                edgeLine: false,
                side: BorderSide.none,
              ),
            ),
            Padding(
              padding: EdgeInsets.all(rim),
              child: DecoratedBox(
                decoration: deckledPaper(
                  context,
                  fill: skin.night.ground,
                  id: (id, 'top'),
                  elevation: ground.elevation.badge,
                  depth: parts.deckleDepth,
                  step: parts.deckleStep,
                  edgeLine: false,
                  side: BorderSide.none,
                ),
                child: ClipPath(
                  clipper: ShapeBorderClipper(shape: top),
                  child: Stack(
                    fit: StackFit.expand,
                    children: [
                      ArtPicture(art, inset: inset),
                      ?over,
                    ],
                  ),
                ),
              ),
            ),
          ],
        );
      },
    );
  }
}
