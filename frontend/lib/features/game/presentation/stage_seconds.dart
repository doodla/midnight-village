import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'protocol_two_game.dart';

/// The whole seconds left until [deadline] by the server's clock
/// ([ProtocolTwoGameNotifier.untilServer]), built again each time the number
/// changes. It counts down to 0 and stays there: the server says when the
/// stage ends (the game fetches `/me/` after the deadline), never this.
/// Null [deadline] (an untimed stage) builds with null.
class StageSeconds extends ConsumerStatefulWidget {
  const StageSeconds({
    super.key,
    required this.gameId,
    required this.deadline,
    required this.builder,
  });

  final String gameId;
  final DateTime? deadline;
  final Widget Function(BuildContext context, int? seconds) builder;

  /// The seconds shown for [left]: rounded up, so "1" shows until the end.
  static int secondsFor(Duration left) =>
      left <= Duration.zero ? 0 : (left.inMicroseconds / 1e6).ceil();

  @override
  ConsumerState<StageSeconds> createState() => _StageSecondsState();
}

class _StageSecondsState extends ConsumerState<StageSeconds> {
  Timer? _tick;

  @override
  void dispose() {
    _tick?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    _tick?.cancel();
    final deadline = widget.deadline;
    if (deadline == null) return widget.builder(context, null);
    final left = ref
        .read(protocolTwoGameProvider(widget.gameId).notifier)
        .untilServer(deadline);
    final seconds = StageSeconds.secondsFor(left);
    if (seconds > 0) {
      // The moment the number drops by one.
      final next = left - Duration(seconds: seconds - 1);
      _tick = Timer(
        Duration(microseconds: math.max(1, next.inMicroseconds)),
        () {
          if (mounted) setState(() {});
        },
      );
    }
    return widget.builder(context, seconds);
  }
}

/// How much of a stage is left, 0 to 1, for the sun's place on its arc (08)
/// and the vote's bar (09). The stage's length is the table's setting and
/// `/me/` sends only its deadline, so the most seconds this phone has seen
/// left in the stage stands for the whole: a phone there from the start
/// shows the true share; one that opened mid-stage starts its sun at dawn.
/// Nothing is assumed and nothing waits on it: it only places a picture.
class StageShare {
  String? _stage;
  int _most = 0;

  /// The share of [stage] left with [seconds] to go; 1 when untimed.
  double left(String? stage, int? seconds) {
    if (seconds == null) return 1;
    if (stage != _stage) {
      _stage = stage;
      _most = 0;
    }
    _most = math.max(_most, seconds);
    return _most == 0 ? 0 : seconds / _most;
  }
}
