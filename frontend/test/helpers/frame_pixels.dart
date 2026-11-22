import 'dart:typed_data';

import 'package:flutter_test/flutter_test.dart';

/// The frame as drawn, read pixel by pixel: what the window really shows,
/// where a widget test can only say what is in the tree. A pixel no widget
/// painted is transparent (alpha 0): the window's own clear colour.
class FramePixels {
  FramePixels._(this.width, this.height, this._rgba);

  final int width;
  final int height;
  final ByteData _rgba;

  /// Draws the frame now (the test clock does not move).
  static Future<FramePixels> of(WidgetTester tester) async {
    final out = await tester.runAsync(() async {
      final image = await captureImage(tester.binding.rootElement!);
      final bytes = await image.toByteData();
      final pixels = FramePixels._(image.width, image.height, bytes!);
      image.dispose();
      return pixels;
    });
    return out!;
  }

  /// The pixel at ([x], [y]) in logical pixels of a view [ratio] times as
  /// dense, as 0xAARRGGBB.
  int at(double x, double y, {double ratio = 1}) {
    final px = (x * ratio).floor().clamp(0, width - 1);
    final py = (y * ratio).floor().clamp(0, height - 1);
    return _pixel(px, py);
  }

  int _pixel(int px, int py) {
    final i = (py * width + px) * 4;
    final r = _rgba.getUint8(i);
    final g = _rgba.getUint8(i + 1);
    final b = _rgba.getUint8(i + 2);
    final a = _rgba.getUint8(i + 3);
    return (a << 24) | (r << 16) | (g << 8) | b;
  }

  /// Every pixel with where it is, row by row.
  Iterable<(int, int, int)> get cells sync* {
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        yield (x, y, _pixel(x, y));
      }
    }
  }

  /// Every pixel, one at a time.
  Iterable<int> get all sync* {
    for (var y = 0; y < height; y++) {
      for (var x = 0; x < width; x++) {
        yield _pixel(x, y);
      }
    }
  }

  /// How many pixels no widget painted.
  int get unpainted => all.where((p) => (p >> 24) & 0xFF != 0xFF).length;

  static int red(int pixel) => (pixel >> 16) & 0xFF;
  static int green(int pixel) => (pixel >> 8) & 0xFF;
  static int blue(int pixel) => pixel & 0xFF;
}
