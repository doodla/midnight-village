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
/// touched and do nothing on the night's ground. Nothing here is for a card
/// being revealed or held: a card never vibrates (the owner, 23 November
/// 2026; `docs/design/feel.md`, section 3).
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

  static void _day(BuildContext context, Future<void> Function() buzz) {
    if (GroundScope.maybeOf(context) == GroundKind.night &&
        !OpenDay.under(context)) {
      return;
    }
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

/// Below it the night's ground is the day's dress, not the night: the vote
/// (09) is drawn under the square's night sky, but what is done on it is done
/// openly at the table, so its pick ticks and its lock knocks. Only the
/// vote's screen declares it; the night's screens never do, and nothing but
/// [Haptics] reads it.
class OpenDay extends InheritedWidget {
  const OpenDay({super.key, required super.child});

  /// Whether [context] is under an [OpenDay].
  static bool under(BuildContext context) =>
      context.getInheritedWidgetOfExactType<OpenDay>() != null;

  @override
  bool updateShouldNotify(OpenDay old) => false;
}
