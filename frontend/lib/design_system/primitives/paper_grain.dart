import 'dart:math' as math;
import 'dart:ui' as ui;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

/// The grain of paper: a small tile of speckle and fibre, drawn once (seeded,
/// so every phone makes the same one), kept for the life of the app and tiled
/// over a paper fill as a [DecorationImage]. Nothing is drawn per frame and
/// no layer is saved: a tile is a few image draws.
abstract final class PaperGrain {
  /// The tile's side in logical pixels (made at [density] times that).
  static const tile = 96.0;
  static const density = 2.0;

  /// How much of it shows over a paper fill.
  static const opacity = 0.5;

  static const _seed = 1123;
  static const _specks = 380;
  static const _fibres = 26;

  static ImageProvider? _provider;

  /// The grain as an image provider that has its image at once.
  static ImageProvider get provider => _provider ??= _GrainProvider(_make());

  /// The tiled grain over a paper fill, for a [BoxDecoration.image].
  static DecorationImage get image => DecorationImage(
    image: provider,
    repeat: ImageRepeat.repeat,
    scale: density,
    opacity: opacity,
  );

  static ui.Image _make() {
    final random = math.Random(_seed);
    final side = tile * density;
    final recorder = ui.PictureRecorder();
    final canvas = ui.Canvas(recorder);
    final dark = Paint()..color = const Color(0x2E2A2030);
    final light = Paint()..color = const Color(0x40FFFFFF);
    for (var i = 0; i < _specks; i++) {
      final at = Offset(random.nextDouble() * side, random.nextDouble() * side);
      final r = (0.4 + random.nextDouble() * 0.9) * density;
      canvas.drawCircle(at, r, random.nextBool() ? dark : light);
    }
    final fibre = Paint()
      ..strokeWidth = 0.6 * density
      ..strokeCap = StrokeCap.round
      ..color = const Color(0x1F3A2F24);
    for (var i = 0; i < _fibres; i++) {
      final from = Offset(
        random.nextDouble() * side,
        random.nextDouble() * side,
      );
      final angle = random.nextDouble() * math.pi;
      final length = (4 + random.nextDouble() * 10) * density;
      canvas.drawLine(
        from,
        from + Offset(math.cos(angle), math.sin(angle)) * length,
        fibre,
      );
    }
    return recorder.endRecording().toImageSync(side.round(), side.round());
  }
}

class _GrainProvider extends ImageProvider<_GrainProvider> {
  const _GrainProvider(this.image);

  final ui.Image image;

  @override
  Future<_GrainProvider> obtainKey(ImageConfiguration configuration) =>
      SynchronousFuture<_GrainProvider>(this);

  @override
  ImageStreamCompleter loadImage(
    _GrainProvider key,
    ImageDecoderCallback decode,
  ) => OneFrameImageStreamCompleter(
    SynchronousFuture<ImageInfo>(ImageInfo(image: image.clone(), scale: 1)),
  );

  @override
  bool operator ==(Object other) =>
      other is _GrainProvider && other.image == image;

  @override
  int get hashCode => identityHashCode(image);
}
