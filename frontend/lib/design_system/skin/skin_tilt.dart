import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// The small rotation a skin gives some shapes, in radians (positive is
/// clockwise). A skin that sets everything straight uses [SkinTilt.none].
@immutable
class SkinTilt {
  const SkinTilt({
    required this.card,
    required this.stamp,
    required this.badge,
  });

  static const none = SkinTilt(card: 0, stamp: 0, badge: 0);

  /// One degree, so a skin can write `-1.2 * SkinTilt.degree` as its mock does.
  static const degree = math.pi / 180;

  /// A large paper card (your card, a dead player's card).
  final double card;

  /// A stamped word or mark ("your vote").
  final double stamp;

  /// A round badge such as a timer.
  final double badge;
}
