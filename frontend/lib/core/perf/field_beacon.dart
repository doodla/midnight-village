import 'package:flutter/scheduler.dart';

import 'field_recorder.dart';
import 'field_summary.dart';

/// The quiet recorder's way out: a game's summary (`field_summary.dart`)
/// goes to the server once, when the end board is shown, and whatever was
/// recorded since goes when the tab is hidden; what was sent is forgotten.
///
/// Never on a tap's path and never waited for: at the end board it is built
/// in an idle task (after the frames that were wanted, once no animation
/// runs), and it leaves by `navigator.sendBeacon`, which the browser sends
/// on its own, also as the tab goes. Nothing is sent when nothing was
/// tapped or asked for.
class FieldBeacon {
  FieldBeacon({
    required this.recorder,
    required this.commit,
    required this.send,
  });

  final FieldRecorder recorder;

  /// This build's commit (`BuildId.mine`).
  final String commit;

  /// Hands one summary (JSON) to the browser; false if it would not take it.
  final bool Function(String summary) send;

  /// The end board's name for the recorder (`AppScreen.end`).
  static const endBoard = 'end';

  /// What a summary sent at the end board says of its end.
  static const endOfGame = 'end_board';

  var _waiting = false;

  /// The recorder's screen changed to [screen].
  void screenShown(String screen) {
    if (screen != endBoard || _waiting) return;
    _waiting = true;
    SchedulerBinding.instance.scheduleTask(() {
      _waiting = false;
      flush(endOfGame);
    }, Priority.idle);
  }

  /// The tab is being hidden (switched away, locked, closed).
  void hidden() => flush('hidden');

  /// Sends what was recorded since the last send, and forgets it. Returns
  /// whether anything was sent.
  bool flush(String end) {
    final summary = fieldSummaryJson(recorder, commit: commit, end: end);
    if (summary == null) return false;
    recorder.clear();
    return send(summary);
  }
}
