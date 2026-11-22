import 'dart:async';

import 'package:flutter/services.dart';

/// The phone's vibration: the one place the app asks for it (`docs/design/
/// feel.md`, section 3). Flutter's own `HapticFeedback`, no package. It
/// never throws and never waits: a phone with no motor, with touch feedback
/// off in the system, or a browser that may not vibrate simply does nothing,
/// and the screen is complete without it. A vibration always goes with a
/// visible change on the same frame; it is never the only sign.
abstract final class Haptics {
  /// A light tap: something small lands. Today only your card's face landing
  /// on 04 (the owner asked for it, 22 November 2026).
  static void light() => _fire(HapticFeedback.lightImpact);

  static void _fire(Future<void> Function() vibrate) {
    try {
      unawaited(vibrate().catchError((Object _) {}));
    } on Object {
      // No motor, no plugin, no permission: nothing to feel, nothing wrong.
    }
  }
}
