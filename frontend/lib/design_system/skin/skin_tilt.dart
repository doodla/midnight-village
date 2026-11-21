import 'dart:math' as math;

import 'package:flutter/foundation.dart';

/// The small rotations a skin gives some shapes, in radians (positive is
/// clockwise), by role. A skin that sets everything straight uses
/// [SkinTilt.none]. Primitives take a [Tilt] and look its angle up here.
@immutable
class SkinTilt {
  const SkinTilt({
    required this.card,
    required this.stamp,
    required this.badge,
    required this.scatter,
    required this.thumb,
    required this.hero,
  });

  static const none = SkinTilt(
    card: 0,
    stamp: 0,
    badge: 0,
    scatter: [0],
    thumb: 0,
    hero: 0,
  );

  /// One degree, so a skin can write `-4 * SkinTilt.degree` as its mock does.
  static const degree = math.pi / 180;

  /// A large paper card (your card, a dead player's card).
  final double card;

  /// A stamped word or mark ("your vote").
  final double stamp;

  /// A round badge such as a timer.
  final double badge;

  /// Cards dropped loosely on the table, in turn (S05: -4, 1, 5 degrees).
  final List<double> scatter;

  /// A small card set into a box ("My night", S08).
  final double thumb;

  /// The one portrait a screen is about (the winner, S11).
  final double hero;

  double angle(Tilt tilt) => switch (tilt) {
    _Named(:final read) => read(this),
    ScatterTilt(:final index) => scatter[index % scatter.length],
  };
}

/// Which of the skin's tilts a shape takes.
@immutable
sealed class Tilt {
  const Tilt._();

  static const none = _Named('none', _none);
  static const card = _Named('card', _card);
  static const stamp = _Named('stamp', _stamp);
  static const badge = _Named('badge', _badge);
  static const thumb = _Named('thumb', _thumb);
  static const hero = _Named('hero', _hero);

  static double _none(SkinTilt t) => 0;
  static double _card(SkinTilt t) => t.card;
  static double _stamp(SkinTilt t) => t.stamp;
  static double _badge(SkinTilt t) => t.badge;
  static double _thumb(SkinTilt t) => t.thumb;
  static double _hero(SkinTilt t) => t.hero;

  /// The [index]th of a row of loosely dropped cards.
  const factory Tilt.scatter(int index) = ScatterTilt;
}

final class _Named extends Tilt {
  const _Named(this.name, this.read) : super._();

  final String name;
  final double Function(SkinTilt) read;

  @override
  String toString() => 'Tilt.$name';
}

final class ScatterTilt extends Tilt {
  const ScatterTilt(this.index) : super._();

  final int index;

  @override
  bool operator ==(Object other) =>
      other is ScatterTilt && other.index == index;

  @override
  int get hashCode => index.hashCode;
}
