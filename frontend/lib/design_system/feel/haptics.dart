import 'package:flutter/services.dart';
import 'package:flutter/widgets.dart';

import '../skin/ground.dart';
import '../skin/ground_scope.dart';

/// The game's touch feedback (`docs/design/feel.md`, section 3): the only
/// place that calls [HapticFeedback] (`haptics_only_here_test.dart` fails any
/// other). Light, and only for something every player does openly in the
/// day; each goes with a visible change on the same frame and is never the
/// only sign. A phone with no motor, or with touch feedback off, does
/// nothing and the screen is whole without it.
///
/// Never at night: each call takes the [context] of the thing that was
/// touched and does nothing on the night's ground. Never throws.
abstract final class Haptics {
  /// A vote pick on 09, each time it moves; taking back "Ready to vote".
  static void tick(BuildContext context) =>
      _fire(context, HapticFeedback.selectionClick);

  /// "Ready to vote" tapped; "Lock in {name}" tapped, on the tap and not on
  /// the answer; the result landing.
  static void light(BuildContext context) =>
      _fire(context, HapticFeedback.lightImpact);

  /// The dead card landing face up: the one medium.
  static void thud(BuildContext context) =>
      _fire(context, HapticFeedback.mediumImpact);

  static void _fire(BuildContext context, Future<void> Function() buzz) {
    if (GroundScope.maybeOf(context) == GroundKind.night) return;
    try {
      buzz().ignore();
    } catch (_) {
      // A platform without it: nothing to feel, nothing to report.
    }
  }
}
