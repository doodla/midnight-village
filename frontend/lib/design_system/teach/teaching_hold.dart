import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../faces/face_content.dart';
import '../primitives/hold_to_reveal.dart';
import 'learned_store.dart';
import 'teach_once.dart';

/// A secret behind a hold that teaches the hold: the press-and-hold ring
/// on its [cover] (`cover(teaching)`) until this device has learned [cue],
/// or for 3 s after [replay] fires (a tap on the screen's locked gate). The
/// ring fills while the cover is held ([HoldPress]); the reveal that counts
/// learns [cue], and the `hold` cue with it, and the ring is gone.
class TeachingHold extends ConsumerStatefulWidget {
  const TeachingHold({
    super.key,
    required this.cover,
    required this.face,
    required this.target,
    this.cue = Cue.hold,
    this.replay,
    this.onRevealed,
  });

  final Widget Function(bool teaching) cover;
  final FaceContent face;

  /// What this is, spoken ("Your card").
  final String target;

  /// Which surface's lesson this is: [Cue.hold] on 04, [Cue.holdYou] on the
  /// night board, [Cue.holdMyNight] on 08.
  final Cue cue;
  final CueReplay? replay;

  /// Told each time a reveal counts (a gate opens on it).
  final VoidCallback? onRevealed;

  @override
  ConsumerState<TeachingHold> createState() => _TeachingHoldState();
}

class _TeachingHoldState extends ConsumerState<TeachingHold> {
  @override
  Widget build(BuildContext context) => TeachOnce(
    cue: widget.cue,
    replay: widget.replay,
    builder: (context, teaching) => HoldToReveal(
      target: widget.target,
      face: widget.face,
      onRevealed: () {
        final learned = ref.read(learnedCuesProvider.notifier);
        learned.learn(Cue.hold);
        if (widget.cue != Cue.hold) learned.learn(widget.cue);
        widget.onRevealed?.call();
      },
      cover: widget.cover(teaching),
    ),
  );
}
