import 'package:flutter/widgets.dart';

import '../skin/art_set.dart';

/// The one way a skin's picture is drawn: cropped to cover the space it is
/// given, around its focus, and decoded at the size it is shown (times the
/// screen's pixel ratio, rounded up to one of a few steps), never at the
/// asset's full size when it is shown small. See [ArtImage.decodedFor].
class ArtPicture extends StatelessWidget {
  const ArtPicture(this.image, {super.key, this.focus, this.decodeAt});

  final ArtImage image;

  /// Overrides the picture's own focus.
  final Alignment? focus;

  /// Decodes the picture for this box whatever box it is drawn in: a secret's
  /// picture, whose box follows its words, is always the one decoded ahead
  /// of the reveal (`secretArt`), so revealing it fetches nothing.
  final Size? decodeAt;

  @override
  Widget build(BuildContext context) {
    final ratio = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1;
    return LayoutBuilder(
      builder: (context, constraints) => Image(
        image: image.decodedFor(decodeAt ?? constraints.biggest, ratio),
        fit: BoxFit.cover,
        alignment: focus ?? image.focus,
        gaplessPlayback: true,
        excludeFromSemantics: true,
        // Bytes that are not a picture (a Wi-Fi sign-in page answered for
        // it) are not kept: the bundle reads the file again next time
        // (`LoadOnceBundle`). Nothing is drawn meanwhile, as without this.
        errorBuilder: (context, error, stack) {
          DefaultAssetBundle.of(context).evict(image.path);
          return const SizedBox.expand();
        },
      ),
    );
  }
}
