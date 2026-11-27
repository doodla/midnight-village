import 'dart:async';

import 'field_recorder.dart';
import 'field_summary.dart';
import 'perf.dart';

/// The quiet recorder's way out: a summary (`field_summary.dart`) goes to
/// the server at the end of each game, and one of the play before the tab is
/// hidden; what was sent is forgotten.
///
/// Never on a tap's path and never waited for. At the end board it waits
/// for the phone to be at rest (no touch, socket message, screen change or
/// answer for [FieldRecorder.busyFor]), with a plain timer looked at once a
/// second while the end board is shown: never a summary built as someone
/// taps "Play again", never a loop of empty timers while it animates. Leaving
/// the end board first leaves it for the next send. It goes by
/// `navigator.sendBeacon`, which the browser sends on its own, also as the
/// tab goes. Nothing is sent when nothing was tapped or asked for, and
/// nothing it does can throw into the app (`quietly`).
class FieldBeacon {
  FieldBeacon({
    required this.recorder,
    required this.commit,
    required this.send,
    this.environment,
    this.sent,
  });

  final FieldRecorder recorder;

  /// This build's commit (`BuildId.mine`).
  final String commit;

  /// Hands one summary (JSON) to the browser; false if it would not take it.
  final bool Function(String summary) send;

  /// What the phone says about itself (`perfEnvironment`): read once, when
  /// the first summary is made, never at the app's start. Null: the
  /// recorder's own.
  final Map<String, Object?> Function()? environment;
  Map<String, Object?>? _environment;

  /// After each summary is handed over (the browser forgets its records of
  /// finished requests: `perfClearResourceTimings`).
  final void Function()? sent;

  /// The end board's name for the recorder (`AppScreen.end`).
  static const endBoard = 'end';

  /// What a summary sent at the end board says of its end.
  static const endOfGame = 'end_board';

  Timer? _atEnd;

  /// The recorder's screen changed to [screen].
  void screenShown(String screen) {
    _atEnd?.cancel();
    _atEnd = null;
    if (screen != endBoard) return;
    _atEnd = Timer.periodic(
      Duration(milliseconds: FieldRecorder.busyFor.round()),
      (timer) {
        if (!recorder.atRest) return;
        timer.cancel();
        _atEnd = null;
        flush(endOfGame);
      },
    );
  }

  /// The tab is being hidden (switched away, locked, closed). A phone locked
  /// and opened again while nothing but polls went out sends nothing: they
  /// go with the next summary (phones lock often in a game).
  void hidden() => quietly(() {
    final something =
        recorder.taps.any((t) => t.done) ||
        recorder.requests.any((q) => !q.isPoll);
    if (something) flush('hidden');
  });

  /// Sends what was recorded since the last send, and forgets it. Returns
  /// whether anything was sent.
  bool flush(String end) =>
      quietly(() {
        if (recorder.taps.isEmpty && recorder.requests.isEmpty) return false;
        _environment ??= environment?.call();
        final summary = fieldSummaryJson(
          recorder,
          commit: commit,
          end: end,
          environment: _environment,
        );
        if (summary == null) return false;
        recorder.clear();
        final took = send(summary);
        sent?.call();
        return took;
      }) ??
      false;
}
