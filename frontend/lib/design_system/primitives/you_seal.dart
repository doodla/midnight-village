import 'package:flutter/widgets.dart';

import '../skin/art_set.dart';
import '../skin/dress.dart';
import '../skin/end_art.dart';
import '../skin/skin.dart';
import 'art_picture.dart';
import 'paper_light.dart';

/// The wax seal that says which card is yours: a blank seal of black wax
/// ([EndPiece.seal]) pressed with YOUR OWN sigil, in grey, as if the wax had
/// taken it. It is [size] across (30 on the end board), and the one thing on
/// the board that differs from phone to phone. Plain, it is the sigil alone.
/// (Not [PaperSeal]: that one is the padlock stamped on a locked vote.)
class YouSeal extends StatelessWidget {
  const YouSeal({super.key, required this.token, this.size = 30});

  final TokenId? token;
  final double size;

  /// The sigil's share of the seal's width.
  static const sigilShare = 0.52;

  /// How much of the sigil shows over the wax: it is pressed, not painted.
  static const sigilAlpha = 0.78;

  /// A matrix that takes the colour out of a picture.
  static const grey = ColorFilter.matrix(<double>[
    0.2126, 0.7152, 0.0722, 0, 0, //
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0, 0, 0, 1, 0,
  ]);

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final paper = context.dress.isPaper;
    final sigil = token == null
        ? null
        : ClipOval(child: ArtPicture(skin.art.token(token!)));
    if (!paper) {
      return ExcludeSemantics(
        child: SizedBox.square(dimension: size, child: sigil),
      );
    }
    final lean = PaperLight.of(context);
    final inner = size * sigilShare;
    return ExcludeSemantics(
      child: IgnorePointer(
        child: SizedBox.square(
          dimension: size,
          child: Stack(
            alignment: Alignment.center,
            clipBehavior: Clip.none,
            children: [
              // The seal's shadow: a disc of it, away from the light.
              Transform.translate(
                offset: Offset(lean * 2, 2),
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: context.ground.shadow,
                  ),
                  child: SizedBox.square(dimension: size * 0.92),
                ),
              ),
              ArtPicture(skin.art.end.piece(EndPiece.seal)),
              if (sigil != null)
                Opacity(
                  opacity: sigilAlpha,
                  child: ColorFiltered(
                    colorFilter: grey,
                    child: SizedBox.square(dimension: inner, child: sigil),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
