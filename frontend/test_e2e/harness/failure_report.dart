import 'dart:convert';
import 'dart:io';

import 'debug_oracle_diff.dart';

/// Machine-readable failure output an agent can act on (contract §D5).
///
/// On any scenario failure the runner appends one JSON line to
/// `integration_test/screenshots/failures.jsonl` describing: which scenario,
/// which checkpoint, expected-vs-actual (oracle diff), and the relevant PNG
/// path (when a filmstrip frame is implicated).
class FailureReport {
  FailureReport._();

  static const String _path = 'integration_test/screenshots/failures.jsonl';

  /// Records a structured failure. Safe to call from anywhere; never throws.
  static void record({
    required String scenario,
    required String checkpoint,
    required String message,
    Map<String, Object?>? expected,
    Map<String, Object?>? actual,
    String? pngPath,
  }) {
    try {
      final entry = <String, Object?>{
        'scenario': scenario,
        'checkpoint': checkpoint,
        'message': message,
        if (expected != null) 'expected': expected,
        if (actual != null) 'actual': actual,
        if (expected != null && actual != null)
          'diff': diffMaps(expected, actual),
        if (pngPath != null) 'png': pngPath,
        'timestamp': DateTime.now().toIso8601String(),
      };
      final file = File(_path);
      file.parent.createSync(recursive: true);
      file.writeAsStringSync(
        '${jsonEncode(entry)}\n',
        mode: FileMode.append,
        flush: true,
      );
    } catch (_) {
      // Reporting must never mask the original test failure.
    }
  }

  /// Clears the failures file at the start of a run.
  static void reset() {
    try {
      final file = File(_path);
      if (file.existsSync()) file.deleteSync();
    } catch (_) {}
  }
}
