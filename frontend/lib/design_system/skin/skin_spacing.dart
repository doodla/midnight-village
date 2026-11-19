import 'package:flutter/foundation.dart';

/// The spacing scale, and the screen's own margins.
@immutable
class SkinSpacing {
  const SkinSpacing({
    required this.xxs,
    required this.xs,
    required this.sm,
    required this.md,
    required this.lg,
    required this.xl,
    required this.xxl,
    required this.gutter,
    required this.screenTop,
    required this.screenBottom,
  });

  final double xxs;
  final double xs;
  final double sm;
  final double md;
  final double lg;
  final double xl;
  final double xxl;

  /// Left and right margin of a screen.
  final double gutter;

  /// Above the first thing on a screen with no top picture.
  final double screenTop;

  /// Below the pinned actions.
  final double screenBottom;
}
