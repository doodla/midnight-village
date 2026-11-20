import 'package:flutter/material.dart';

import '../copy/copy.dart';
import '../layout/space.dart';
import '../skin/skin.dart';

/// The thumbprint on a face-down card that says "hold" (the `hold` cue,
/// first-time play spec, section 2). While [teaching], a bone ring round it
/// breathes (scale 1.00 to 1.06, a 1.4 s loop) with the word "Hold" at 20 px
/// under it; once learned, the thumbprint alone, still. With reduced motion
/// the ring stands still. It sets itself smaller to fit a small card; a card
/// too small for the word at 20 px leaves it out ([word]) and its holder
/// sets it beside the card.
///
/// It is drawn in the night's colours on any ground: it always lies on a
/// card back.
class HoldCue extends StatefulWidget {
  const HoldCue({
    super.key,
    required this.teaching,
    this.size = maxSize,
    this.word = true,
  });

  final bool teaching;

  /// Draw "Hold" under the thumbprint while teaching.
  final bool word;

  /// The ring's diameter at most.
  final double size;

  /// The hero card's (S07's 132 disc).
  static const maxSize = 132.0;

  /// One breath, in and out.
  static const breath = Duration(milliseconds: 1400);
  static const breathScale = 1.06;

  @override
  State<HoldCue> createState() => _HoldCueState();
}

class _HoldCueState extends State<HoldCue> with SingleTickerProviderStateMixin {
  late final _breath = AnimationController(
    vsync: this,
    duration: HoldCue.breath ~/ 2,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(HoldCue old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    final breathe = widget.teaching && !MediaQuery.disableAnimationsOf(context);
    if (breathe && !_breath.isAnimating) {
      _breath.repeat(reverse: true);
    } else if (!breathe && _breath.isAnimating) {
      _breath.stop();
      _breath.value = 0;
    }
  }

  @override
  void dispose() {
    _breath.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final night = skin.night;
    final size = widget.size;
    final disc = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        // A veil over the card back: the night at 86%, so the thumbprint and
        // the ring read on any back.
        color: night.ground.withValues(alpha: 0.86),
        shape: BoxShape.circle,
      ),
      child: Icon(Icons.fingerprint, color: night.text, size: size * 0.5),
    );
    final ring = ScaleTransition(
      scale: Tween(
        begin: 1.0,
        end: HoldCue.breathScale,
      ).animate(CurvedAnimation(parent: _breath, curve: Curves.easeInOut)),
      child: Container(
        width: size,
        height: size,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.all(
            color: night.text,
            width: skin.shape.selectedRing,
            strokeAlign: BorderSide.strokeAlignOutside,
          ),
        ),
      ),
    );
    return FittedBox(
      fit: BoxFit.scaleDown,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        spacing: Space.sm,
        children: [
          Stack(
            alignment: Alignment.center,
            children: [disc, if (widget.teaching) ring],
          ),
          if (widget.teaching && widget.word)
            Container(
              padding: const EdgeInsets.symmetric(
                horizontal: Space.xs,
                vertical: Space.xxs,
              ),
              decoration: BoxDecoration(
                color: night.ground.withValues(alpha: 0.86),
                borderRadius: BorderRadius.circular(skin.shape.radiusSmall),
              ),
              child: Text(
                CommonCopy.hold,
                style: skin.typography.cue.copyWith(color: night.text),
              ),
            ),
        ],
      ),
    );
  }
}
