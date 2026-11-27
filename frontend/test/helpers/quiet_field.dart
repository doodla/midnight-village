import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/core/perf/perf_env.dart';
import 'package:midnight_village/design_system/perf/perf_strip.dart';

/// With `--dart-define=FIELD_QUIET=true`, each test runs with the quiet
/// field recorder and its beacon switched on, as on every live phone
/// (`startQuietField`), and off again after it. Summaries go nowhere.
/// Without it, nothing: the tests run with the recorder off (`PerfOff`).
///
/// Used by `test/flutter_test_config.dart` and `test_e2e/flutter_test_config.dart`:
/// the screen sweep (with its still-screen rule) and the harness, run once
/// with it on, show that measuring changes nothing a player could see.
void quietFieldInTests() {
  if (!const bool.fromEnvironment('FIELD_QUIET')) return;
  void Function()? stop;
  setUp(() {
    stop = startQuietField(now: perfNow, send: (_) => true).$2;
  });
  tearDown(() {
    stop?.call();
    stop = null;
  });
}
