import 'package:flutter/material.dart';

import '../skin/art_set.dart';
import '../skin/skin.dart';
import 'art_picture.dart';
import 'screen_frame.dart';

/// A skin picture across the top of a screen, shown faintly and fading into
/// the ground: the village standing behind a screen that is mostly empty (the
/// scanner's), never the loud picture 01 opens with. For [ScreenFrame.backdrop].
class FaintArt extends StatelessWidget {
  const FaintArt(this.art, {super.key, this.opacity = 0.26});

  final ArtImage art;

  /// How much of the picture shows.
  final double opacity;

  @override
  Widget build(BuildContext context) {
    final ground = context.ground.ground;
    final height =
        TopArtLayout.scene.height + MediaQuery.paddingOf(context).top;
    return Align(
      alignment: Alignment.topCenter,
      child: SizedBox(
        height: height,
        width: double.infinity,
        child: Stack(
          fit: StackFit.expand,
          children: [
            Opacity(opacity: opacity, child: ArtPicture(art)),
            DecoratedBox(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  stops: const [0.3, 1],
                  colors: [ground.withValues(alpha: 0), ground],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}
