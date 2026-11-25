import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../faces/face_content.dart';
import '../primitives/hold_to_reveal.dart';
import 'learned_store.dart';
import 'teach_once.dart';

/// A secret behind a hold that teaches the hold: the press-and-hold ring
/// on its [cover] (`cover(teaching)`) until this device has learned the one
/// `hold` cue, or for 3 s after [replay] fires (a tap on the screen's locked
/// gate). The ring fills while the cover is held ([HoldPress]); the first
/// reveal that counts, on any face, learns it, and the ring is gone from
/// every face.
class TeachingHold extends ConsumerStatefulWidget {
  const TeachingHold({
    super.key,
    required this.cover,
    required this.face,
    required this.target,
    this.replay,
    this.onRevealed,
    this.inPlace = false,
    this.open = false,
    this.onRevealChanged,
  });

  final Widget Function(bool teaching) cover;
  final FaceContent face;

  /// What this is, spoken ("Your card").
  final String target;

  final CueReplay? replay;

  /// Told each time a reveal counts (a gate opens on it).
  final VoidCallback? onRevealed;

  /// The face turns over in the cover's own box ([HoldToReveal.inPlace]).
  final bool inPlace;

  /// The face is up by itself ([HoldToReveal.open]), and says when it hides.
  final bool open;
  final ValueChanged<bool>? onRevealChanged;

  @override
  ConsumerState<TeachingHold> createState() => _TeachingHoldState();
}

class _TeachingHoldState extends ConsumerState<TeachingHold> {
  @override
  Widget build(BuildContext context) => TeachOnce(
    cue: Cue.hold,
    replay: widget.replay,
    builder: (context, teaching) => HoldToReveal(
      target: widget.target,
      face: widget.face,
      inPlace: widget.inPlace,
      open: widget.open,
      onRevealChanged: widget.onRevealChanged,
      onRevealed: () {
        ref.read(learnedCuesProvider.notifier).learn(Cue.hold);
        widget.onRevealed?.call();
      },
      cover: widget.cover(teaching),
    ),
  );
}
