import 'dart:async';

import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../skin/ground.dart';
import '../skin/ground_scope.dart';

/// The game's touch feedback (`docs/design/feel.md`, section 3): the only
/// place that calls [HapticFeedback] (`haptics_only_here_test.dart` fails any
/// other). Light, and only for something every player does openly in the
/// day; each goes with a visible change on the same frame and is never the
/// only sign. A phone with no motor, or with touch feedback off, does
/// nothing and the screen is whole without it. Never throws, never waits.
///
/// [tick], [light] and [thud] take the [context] of the thing that was
/// touched and do nothing on the night's ground. [landed] is the one
/// exception.
abstract final class Haptics {
  /// A vote pick on 09, each time it moves; taking back "Ready to vote".
  static void tick(BuildContext context) =>
      _day(context, HapticFeedback.selectionClick);

  /// "Ready to vote" tapped; "Lock in {name}" tapped, on the tap and not on
  /// the answer; the result landing.
  static void light(BuildContext context) =>
      _day(context, HapticFeedback.lightImpact);

  /// The dead card landing face up: the one medium.
  static void thud(BuildContext context) =>
      _day(context, HapticFeedback.mediumImpact);

  /// Your card's face landing on 04 (the owner asked for it, 22 November
  /// 2026): the only vibration at night, so it takes no context.
  static void landed() => _fire(HapticFeedback.lightImpact);

  static void _day(BuildContext context, Future<void> Function() buzz) {
    if (GroundScope.maybeOf(context) == GroundKind.night) return;
    _fire(buzz);
  }

  static void _fire(Future<void> Function() buzz) {
    try {
      unawaited(buzz().catchError((Object _) {}));
    } on Object {
      // A platform without it: nothing to feel, nothing to report.
    }
  }
}
