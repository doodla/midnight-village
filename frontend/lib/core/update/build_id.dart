import 'package:flutter/foundation.dart';

/// Which build this is: the commit it was made from, compiled in by
/// `tool/vercel_build.sh` (`--dart-define=BUILD_COMMIT=<sha>`). A local run,
/// a test or a build made without one is [local], and never asks whether it
/// is out of date.
class BuildId {
  BuildId._();

  static const local = 'local';

  static const _mine = String.fromEnvironment(
    'BUILD_COMMIT',
    defaultValue: local,
  );

  /// This build's commit; only the web app renews itself (an installed app's
  /// pictures ship inside it, and no page can be reloaded).
  static const String mine = kIsWeb ? _mine : local;

  /// A commit that names a real build (not a local run, not an empty one).
  static bool isReal(String id) => id.isNotEmpty && id != local;
}
