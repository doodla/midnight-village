import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../faces/face_content.dart';
import '../primitives/hold_to_reveal.dart';
import 'learned_store.dart';
import 'teach_once.dart';

/// A secret behind a hold that teaches the hold: the `hold` cue on its
/// [cover] (`cover(teaching)`) until this device has learned it, or for 3 s
/// after [replay] fires (a tap on the screen's locked gate). The first
/// reveal that counts on any face learns it. The cue is not drawn while the
/// face is shown.
class TeachingHold extends ConsumerStatefulWidget {
  const TeachingHold({
    super.key,
    required this.cover,
    required this.face,
    required this.target,
    this.cap,
    this.replay,
    this.onRevealed,
  });

  final Widget Function(bool teaching) cover;
  final FaceContent face;

  /// What this is, spoken ("Your card").
  final String target;
  final Duration? cap;
  final CueReplay? replay;

  /// Told each time a reveal counts (a gate opens on it).
  final VoidCallback? onRevealed;

  @override
  ConsumerState<TeachingHold> createState() => _TeachingHoldState();
}

class _TeachingHoldState extends ConsumerState<TeachingHold> {
  var _shown = false;

  @override
  Widget build(BuildContext context) => TeachOnce(
    cue: Cue.hold,
    replay: widget.replay,
    builder: (context, teaching) => HoldToReveal(
      target: widget.target,
      face: widget.face,
      cap: widget.cap,
      onRevealChanged: (shown) {
        if (mounted) setState(() => _shown = shown);
      },
      onRevealed: () {
        ref.read(learnedCuesProvider.notifier).learn(Cue.hold);
        widget.onRevealed?.call();
      },
      cover: widget.cover(teaching && !_shown),
    ),
  );
}
