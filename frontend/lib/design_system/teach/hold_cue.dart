import 'dart:math' as math;

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
/// sets it beside the card. With [wordInside] (a card on the night board)
/// the print and the word are one upright seal in a breathing ring, set
/// smaller to fit the card ([size] is then its width at most); once
/// learned, the round thumbprint alone.
///
/// It is drawn in the night's colours on any ground: it always lies on a
/// card back.
class HoldCue extends StatefulWidget {
  const HoldCue({
    super.key,
    required this.teaching,
    this.size = maxSize,
    this.word = true,
    this.wordInside = false,
  });

  final bool teaching;

  /// Draw "Hold" with the thumbprint while teaching.
  final bool word;

  /// The word inside the disc, under the thumbprint, rather than under the
  /// disc: on a card whose lower edge carries its owner's token.
  final bool wordInside;

  /// The ring's diameter at most.
  final double size;

  /// The hero card's (S07's 132 disc).
  static const maxSize = 132.0;

  /// One breath, in and out.
  static const breath = Duration(milliseconds: 1400);
  static const breathScale = 1.06;

  /// The word is never set smaller than this (the reading floor for what a
  /// player reads to act): a seal that would set it smaller is left out.
  static const wordFloor = 16.0;

  /// The seal's print to its word's size, and the room round them.
  static const _sealPrint = 1.4;

  /// The print alone, on a card that carries the seal, to the seal's width.
  static const _printShare = 0.6;
  static const _sealPadding = EdgeInsets.symmetric(
    horizontal: Space.sm,
    vertical: Space.smPlus,
  );

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
    final showWord = widget.teaching && widget.word;
    final word = Text(
      CommonCopy.hold,
      style: skin.typography.cue.copyWith(color: night.text),
    );
    // A veil over the card back: the night at 86%, so the thumbprint, the
    // word and the ring read on any back.
    final veil = night.ground.withValues(alpha: 0.86);
    Widget breathing(Widget child) => ScaleTransition(
      scale: Tween(
        begin: 1.0,
        end: HoldCue.breathScale,
      ).animate(CurvedAnimation(parent: _breath, curve: Curves.easeInOut)),
      child: child,
    );
    final edge = BorderSide(
      color: night.text,
      width: skin.shape.selectedRing,
      strokeAlign: BorderSide.strokeAlignOutside,
    );

    // Beside a seal's width, the print alone is a smaller disc.
    final round = widget.wordInside ? size * HoldCue._printShare : size;
    final disc = Container(
      width: round,
      height: round,
      decoration: BoxDecoration(color: veil, shape: BoxShape.circle),
      child: Icon(Icons.fingerprint, color: night.text, size: round * 0.5),
    );
    final ring = breathing(
      Container(
        width: round,
        height: round,
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          border: Border.fromBorderSide(edge),
        ),
      ),
    );
    final ringed = Stack(
      alignment: Alignment.center,
      children: [disc, if (widget.teaching) ring],
    );
    final label = Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Space.xs,
        vertical: Space.xxs,
      ),
      decoration: BoxDecoration(
        color: veil,
        borderRadius: BorderRadius.circular(skin.shape.radiusSmall),
      ),
      child: word,
    );
    final plain = FittedBox(fit: BoxFit.scaleDown, child: ringed);
    if (!widget.wordInside) {
      return FittedBox(
        fit: BoxFit.scaleDown,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          spacing: Space.sm,
          children: [ringed, if (showWord) label],
        ),
      );
    }
    if (!showWord) return plain;

    // One upright seal: the print over the word, in a ring that breathes.
    final print = skin.typography.cue.fontSize! * HoldCue._sealPrint;
    final seal = Stack(
      alignment: Alignment.center,
      children: [
        Container(
          padding: HoldCue._sealPadding,
          decoration: ShapeDecoration(
            color: veil,
            shape: const StadiumBorder(),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(Icons.fingerprint, color: night.text, size: print),
              word,
            ],
          ),
        ),
        Positioned.fill(
          child: breathing(
            DecoratedBox(
              decoration: ShapeDecoration(shape: StadiumBorder(side: edge)),
            ),
          ),
        ),
      ],
    );
    // The seal where its word stays at the floor; else the print alone,
    // still breathing.
    return LayoutBuilder(
      builder: (context, room) {
        final scaler = MediaQuery.textScalerOf(context);
        final painter = TextPainter(
          text: TextSpan(text: CommonCopy.hold, style: skin.typography.cue),
          textScaler: scaler,
          textDirection: TextDirection.ltr,
        )..layout();
        final natural = Size(
          painter.width + HoldCue._sealPadding.horizontal,
          painter.height + print + HoldCue._sealPadding.vertical,
        );
        painter.dispose();
        final fit = [
          1.0,
          size / natural.width,
          room.maxWidth / natural.width,
          room.maxHeight / natural.height,
        ].reduce(math.min);
        final drawn = scaler.scale(skin.typography.cue.fontSize!) * fit;
        if (drawn < HoldCue.wordFloor) return plain;
        return ConstrainedBox(
          constraints: BoxConstraints(maxWidth: size),
          child: FittedBox(fit: BoxFit.scaleDown, child: seal),
        );
      },
    );
  }
}
