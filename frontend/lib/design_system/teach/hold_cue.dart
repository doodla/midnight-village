import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../copy/copy.dart';
import '../layout/space.dart';
import '../primitives/hold_to_reveal.dart';
import '../skin/skin.dart';

/// The press-and-hold cue on a face-down card (the `hold` cue, first-time
/// play spec, section 2): while [teaching], a plain ring on a veil of the
/// night with the word "Hold" in it; the ring breathes (scale 1.00 to 1.06,
/// a 1.4 s loop) and, while the card is held, fills clockwise in the time a
/// reveal takes to count. Once learned, nothing: the card is a card. With
/// reduced motion the ring stands still and fills at once.
///
/// The word is left out ([word]) where its holder sets it elsewhere, and
/// where the ring is too small to keep it at [wordFloor].
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

  /// Draw "Hold" in the ring.
  final bool word;

  /// The ring's diameter at most.
  final double size;

  /// The hero card's (S07's 132 disc).
  static const maxSize = 132.0;

  /// One breath, in and out.
  static const breath = Duration(milliseconds: 1400);
  static const breathScale = 1.06;

  /// The word is never set smaller than this (the reading floor for a
  /// caption on a card): a ring too small for it goes without.
  static const wordFloor = ReadingFloor.caption;

  /// The word's share of the ring's width at most.
  static const _wordShare = 0.72;

  @override
  State<HoldCue> createState() => _HoldCueState();
}

class _HoldCueState extends State<HoldCue> with TickerProviderStateMixin {
  late final _breath = AnimationController(
    vsync: this,
    duration: HoldCue.breath ~/ 2,
  );
  late final _fill = AnimationController(
    vsync: this,
    // From the face showing to the reveal counting.
    duration: HoldToReveal.revealedAfter,
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
    final still = MediaQuery.disableAnimationsOf(context);
    final breathe = widget.teaching && !still;
    if (breathe && !_breath.isAnimating) {
      _breath.repeat(reverse: true);
    } else if (!breathe && _breath.isAnimating) {
      _breath.stop();
      _breath.value = 0;
    }
    final held = widget.teaching && HoldPress.of(context);
    if (held && _fill.status != AnimationStatus.forward && _fill.value == 0) {
      still ? _fill.value = 1 : _fill.forward();
    } else if (!held) {
      _fill.value = 0;
    }
  }

  @override
  void dispose() {
    _breath.dispose();
    _fill.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    if (!widget.teaching) return const SizedBox.shrink();
    final skin = context.skin;
    final night = skin.night;
    final cue = skin.typography.cue;
    final size = widget.size;
    return LayoutBuilder(
      builder: (context, room) {
        final ring = [
          size,
          if (room.hasBoundedWidth) room.maxWidth,
          if (room.hasBoundedHeight) room.maxHeight,
        ].reduce(math.min);
        // The word at its size, set smaller to fit the ring, or left out.
        final scaler = MediaQuery.textScalerOf(context);
        final painter = TextPainter(
          text: TextSpan(text: CommonCopy.hold, style: cue),
          textScaler: scaler,
          textDirection: TextDirection.ltr,
        )..layout();
        final fit = math.min(1.0, ring * HoldCue._wordShare / painter.width);
        painter.dispose();
        final drawn = scaler.scale(cue.fontSize!) * fit;
        final showWord = widget.word && drawn >= HoldCue.wordFloor;
        return ScaleTransition(
          scale: Tween(
            begin: 1.0,
            end: HoldCue.breathScale,
          ).animate(CurvedAnimation(parent: _breath, curve: Curves.easeInOut)),
          child: SizedBox.square(
            dimension: ring,
            child: CustomPaint(
              painter: HoldRingPainter(
                fill: _fill,
                veil: night.ground.withValues(alpha: _veil),
                track: night.text.withValues(alpha: _track),
                ink: night.text,
                width: skin.shape.selectedRing,
              ),
              child: showWord
                  ? Center(
                      child: Text(
                        CommonCopy.hold,
                        style: cue.copyWith(
                          color: night.text,
                          fontSize: cue.fontSize! * fit,
                        ),
                      ),
                    )
                  : null,
            ),
          ),
        );
      },
    );
  }

  /// A veil over the card back, so the ring and the word read on any back.
  static const _veil = 0.86;

  /// The ring before it fills.
  static const _track = 0.45;
}

/// The ring: a veiled disc, its track, and the arc filled so far from the
/// top, clockwise ([fill]).
class HoldRingPainter extends CustomPainter {
  HoldRingPainter({
    required this.fill,
    required this.veil,
    required this.track,
    required this.ink,
    required this.width,
  }) : super(repaint: fill);

  final Animation<double> fill;
  final Color veil;
  final Color track;
  final Color ink;
  final double width;

  @override
  void paint(Canvas canvas, Size size) {
    final centre = size.center(Offset.zero);
    final radius = size.shortestSide / 2;
    canvas.drawCircle(centre, radius, Paint()..color = veil);
    final line = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = width
      ..strokeCap = StrokeCap.round;
    final rim = radius - width / 2;
    canvas.drawCircle(centre, rim, line..color = track);
    if (fill.value > 0) {
      canvas.drawArc(
        Rect.fromCircle(center: centre, radius: rim),
        -math.pi / 2,
        2 * math.pi * fill.value,
        false,
        line..color = ink,
      );
    }
  }

  @override
  bool shouldRepaint(HoldRingPainter old) =>
      old.veil != veil ||
      old.track != track ||
      old.ink != ink ||
      old.width != width;
}
