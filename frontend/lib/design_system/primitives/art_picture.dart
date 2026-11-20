import 'package:flutter/widgets.dart';

import '../skin/art_set.dart';

/// The one way a skin's picture is drawn: cropped to cover the space it is
/// given, around its focus, and decoded at the size it is shown (times the
/// screen's pixel ratio, rounded up to one of a few steps), never at the
/// asset's full size when it is shown small. See [ArtImage.decodedFor].
class ArtPicture extends StatelessWidget {
  const ArtPicture(this.image, {super.key, this.focus});

  final ArtImage image;

  /// Overrides the picture's own focus.
  final Alignment? focus;

  @override
  Widget build(BuildContext context) {
    final ratio = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1;
    return LayoutBuilder(
      builder: (context, constraints) => Image(
        image: image.decodedFor(constraints.biggest, ratio),
        fit: BoxFit.cover,
        alignment: focus ?? image.focus,
        gaplessPlayback: true,
        excludeFromSemantics: true,
      ),
    );
  }
}
