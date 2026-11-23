import 'package:flutter/widgets.dart';

import '../../core/update/stale_smell.dart';
import '../skin/art_set.dart';

/// The one way a skin's picture is drawn: cropped to cover the space it is
/// given, around its focus, and decoded at the size it is shown (times the
/// screen's pixel ratio, rounded up to one of a few steps), never at the
/// asset's full size when it is shown small. See [ArtImage.decodedFor].
class ArtPicture extends StatelessWidget {
  const ArtPicture(
    this.image, {
    super.key,
    this.focus,
    this.decodeAt,
    this.inset = 0,
  });

  final ArtImage image;

  /// Overrides the picture's own focus.
  final Alignment? focus;

  /// Decodes the picture for this box whatever box it is drawn in: a secret's
  /// picture, whose box follows its words, is always the one decoded ahead
  /// of the reveal (`secretArt`), so revealing it fetches nothing.
  final Size? decodeAt;

  /// A share of the picture's width cut off every side (a dressed card shows
  /// the inside of its print, framed in paper); the picture itself is as it
  /// was.
  final double inset;

  /// Test hooks (`test/flutter_test_config.dart`); null in the app. Quietly
  /// drawing nothing is right for a player on a bad line, but it let a missing
  /// Werewolf portrait ship with every test green: under test a picture that
  /// is not in the bundle, or whose bytes do not decode, fails the test that
  /// shows it.
  @visibleForTesting
  static void Function(ArtImage image)? debugBeforeDraw;

  @visibleForTesting
  static void Function(ArtImage image, Object error)? debugOnError;

  @override
  Widget build(BuildContext context) {
    debugBeforeDraw?.call(image);
    final ratio = MediaQuery.maybeDevicePixelRatioOf(context) ?? 1;
    return LayoutBuilder(
      builder: (context, constraints) => _cropped(
        Image(
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
            // A page where a picture should be: the build may be out of date.
            StaleSmell.report();
            debugOnError?.call(image, error);
            return const SizedBox.expand();
          },
        ),
      ),
    );
  }

  Widget _cropped(Widget picture) => inset <= 0
      ? picture
      : ClipRect(
          child: Transform.scale(scale: 1 / (1 - 2 * inset), child: picture),
        );
}
