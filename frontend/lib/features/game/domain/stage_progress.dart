import 'package:flutter/foundation.dart';

/// The stages that count who is done (night protocol 2): looking at your
/// card, ready to vote, locked in.
enum ProgressStage {
  look('look'),
  talk('talk'),
  vote('vote');

  const ProgressStage(this.server);

  /// The server's name for it.
  final String server;

  static ProgressStage fromServer(Object? name) =>
      values.where((s) => s.server == name).firstOrNull ??
      (throw FormatException('Unknown progress stage', name));
}

/// How many of the players still at the table are done with [stage], and how
/// many are needed: counts only, never who (contract v2, "counts only").
///
/// The one parser for both places the server sends it: `/me/`'s `progress`
/// and the `progress` socket event. The event carries the same absolute
/// counts, so applying it twice, or after a fetch, changes nothing.
@immutable
class StageProgress {
  const StageProgress._(this.stage, this.done, this.needed);

  /// `{"stage", "done", "needed"}` (the event's `type` is ignored).
  factory StageProgress.fromJson(Map<String, dynamic> json) {
    final done = json['done'] as int;
    final needed = json['needed'] as int;
    if (done < 0 || needed < 0) {
      throw FormatException('Progress counts are never negative', json);
    }
    return StageProgress._(
      ProgressStage.fromServer(json['stage']),
      done,
      needed,
    );
  }

  final ProgressStage stage;
  final int done;
  final int needed;

  @override
  bool operator ==(Object other) =>
      other is StageProgress &&
      other.stage == stage &&
      other.done == done &&
      other.needed == needed;

  @override
  int get hashCode => Object.hash(stage, done, needed);

  @override
  String toString() => 'StageProgress(${stage.server}, $done of $needed)';
}
