import 'dart:async';

import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'learned_store.dart';

/// Tells a [TeachOnce] to show its cue again: a tap on a locked gate
/// replays that screen's cue, on any device (first-time play spec, section
/// 2), for a newcomer on a phone that has already learned it.
class CueReplay extends ChangeNotifier {
  void replay() => notifyListeners();

  /// The replay of the nearest [TeachOnce] above (null where it has none):
  /// a cue that rests once taught listens, to play once more (`HoldCue`).
  static CueReplay? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_ReplayScope>()?.replay;
}

class _ReplayScope extends InheritedWidget {
  const _ReplayScope({required this.replay, required super.child});

  final CueReplay? replay;

  @override
  bool updateShouldNotify(_ReplayScope old) => old.replay != replay;
}

/// Builds [builder] with `teaching: true` while this device has not learned
/// [cue], and for [replayFor] after [replay] fires; `false` otherwise. A cue
/// never adds waiting time: it only changes what is drawn.
///
/// Hidden information: whether a cue shows depends on the device's history,
/// never on the role.
class TeachOnce extends ConsumerStatefulWidget {
  const TeachOnce({
    super.key,
    required this.cue,
    required this.builder,
    this.replay,
  });

  final Cue cue;
  final Widget Function(BuildContext context, bool teaching) builder;
  final CueReplay? replay;

  /// How long a replayed cue shows.
  static const replayFor = Duration(seconds: 3);

  @override
  ConsumerState<TeachOnce> createState() => _TeachOnceState();
}

class _TeachOnceState extends ConsumerState<TeachOnce> {
  Timer? _replaying;

  @override
  void initState() {
    super.initState();
    widget.replay?.addListener(_replay);
  }

  @override
  void didUpdateWidget(TeachOnce old) {
    super.didUpdateWidget(old);
    if (old.replay != widget.replay) {
      old.replay?.removeListener(_replay);
      widget.replay?.addListener(_replay);
    }
  }

  @override
  void dispose() {
    widget.replay?.removeListener(_replay);
    _replaying?.cancel();
    super.dispose();
  }

  void _replay() {
    _replaying?.cancel();
    setState(() {
      _replaying = Timer(TeachOnce.replayFor, () {
        if (mounted) setState(() => _replaying = null);
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    final learned = ref.watch(
      learnedCuesProvider.select((cues) => cues.contains(widget.cue)),
    );
    return _ReplayScope(
      replay: widget.replay,
      child: widget.builder(context, !learned || _replaying != null),
    );
  }
}
