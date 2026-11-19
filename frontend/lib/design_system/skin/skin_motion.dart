import 'package:flutter/foundation.dart';
import 'package:flutter/animation.dart';

/// How long things take to move.
@immutable
class SkinMotion {
  const SkinMotion({
    required this.press,
    required this.quick,
    required this.settle,
    required this.reveal,
    required this.curve,
  });

  /// A button going down or coming back up.
  final Duration press;

  /// Small state changes: a pick, a ring, a count.
  final Duration quick;

  /// A part of the screen arriving or leaving.
  final Duration settle;

  /// A card turning over.
  final Duration reveal;

  final Curve curve;
}
