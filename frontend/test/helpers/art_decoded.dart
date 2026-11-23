import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/primitives/art_picture.dart';

/// Reads and decodes every picture on screen (image providers load on real
/// I/O, which the test clock never waits for), then pumps once.
Future<void> loadPictures(WidgetTester tester) async {
  await tester.runAsync(() async {
    for (final element in find.byType(Image).evaluate()) {
      await precacheImage((element.widget as Image).image, element);
    }
  });
  await tester.pump();
}

/// What a picture's [Image] draws: its file, and whether the pixels are there.
class PaintedPicture {
  PaintedPicture(this.path, this.decoded);

  final String path;

  /// A decoded image reached the paint (not a placeholder, not the error
  /// builder's empty box).
  final bool decoded;

  @override
  String toString() => '$path ${decoded ? 'decoded' : 'NOT decoded'}';
}

/// Every [ArtPicture] under [of] (the whole screen by default) whose file name
/// contains [part], with whether it painted a decoded image. Call after
/// [loadPictures].
List<PaintedPicture> paintedPictures(
  WidgetTester tester, {
  Finder? of,
  String part = '',
}) {
  final pictures = of == null
      ? find.byType(ArtPicture)
      : find.descendant(of: of, matching: find.byType(ArtPicture));
  return [
    for (final element in pictures.evaluate())
      if ((element.widget as ArtPicture).image.path.contains(part))
        PaintedPicture(
          (element.widget as ArtPicture).image.path,
          find
              .descendant(
                of: find.byElementPredicate((e) => e == element),
                matching: find.byType(RawImage),
              )
              .evaluate()
              .any((e) => (e.renderObject! as RenderImage).image != null),
        ),
  ];
}
