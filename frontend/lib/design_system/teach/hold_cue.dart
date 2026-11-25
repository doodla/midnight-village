import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../copy/copy.dart';
import '../feel/ambient.dart';
import '../layout/space.dart';
import '../primitives/hold_to_reveal.dart';
import '../skin/skin.dart';
import '../primitives/paper_light.dart';
import '../primitives/paper_piece.dart';
import '../skin/dress.dart';
import '../skin/dress_style.dart';
import 'teach_once.dart';

/// The press-and-hold cue on a face-down card (the `hold` cue, first-time
/// play spec, section 2): while [teaching], a plain ring on a veil of the
/// night with the word "Hold" in it; the ring breathes [breaths] times
/// (scale 1.00 to 1.06, 1.4 s each) and then stands still, the same sign at
/// rest; it breathes once more after a tap on the screen's locked gate before
/// a hold ([CueReplay]). While the card is held it fills
/// clockwise in the time a reveal takes to count. Once learned, nothing: the
/// card is a card. With reduced motion the ring stands still and fills at
/// once.
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

  /// Breaths when it first shows; then it rests until asked again.
  static const breaths = 3;

  /// The word is never set smaller than this (the reading floor for a
  /// caption on a card): a ring too small for it goes without.
  static const wordFloor = ReadingFloor.caption;

  /// The word's share of the ring's width at most.
  static const _wordShare = 0.72;

  @override
  State<HoldCue> createState() => _HoldCueState();
}

class _HoldCueState extends State<HoldCue> with SingleTickerProviderStateMixin {
  /// One more breath: a tap on the screen's locked gate before a hold.
  final _again = AmbientCue();
  CueReplay? _replay;
  late final _fill = AnimationController(
    vsync: this,
    // From the face showing to the reveal counting.
    duration: HoldToReveal.revealedAfter,
  );

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final replay = CueReplay.of(context);
    if (replay != _replay) {
      _replay?.removeListener(_breatheAgain);
      _replay = replay?..addListener(_breatheAgain);
    }
    _sync();
  }

  void _breatheAgain() {
    if (widget.teaching) _again.again();
  }

  @override
  void didUpdateWidget(HoldCue old) {
    super.didUpdateWidget(old);
    _sync();
  }

  void _sync() {
    final still = MediaQuery.disableAnimationsOf(context);
    final held = widget.teaching && HoldPress.of(context);
    if (held && _fill.status != AnimationStatus.forward && _fill.value == 0) {
      still ? _fill.value = 1 : _fill.forward();
    } else if (!held) {
      _fill.value = 0;
    }
  }

  @override
  void dispose() {
    _replay?.removeListener(_breatheAgain);
    _again.dispose();
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
        // Its own layer (`Ambient`'s): the breathing ring repaints itself,
        // never the paper round it (`paint_cache_test.dart`).
        return Ambient(
          id: 'hold-cue',
          still: 0,
          period: HoldCue.breath ~/ 2,
          curve: Curves.easeInOut,
          cycles: HoldCue.breaths,
          cue: _again,
          builder: (context, breath, child) => ScaleTransition(
            scale: Tween(begin: 1.0, end: HoldCue.breathScale).animate(breath),
            child: child,
          ),
          // The disc itself is one more layer inside it: breathing moves
          // the layer, it does not paint the disc again.
          child: RepaintBoundary(
            child: SizedBox.square(
              dimension: ring,
              child: context.dress.isPaper
                  ? _paper(context, ring, showWord, cue, fit)
                  : CustomPaint(
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
          ),
        );
      },
    );
  }

  /// Dressed up: a navy paper disc with the word on it, and the hold's
  /// progress an amber paper arc round it (a filled band that grows clockwise
  /// from the top over the same time, casting the paper shadow of the
  /// screen's light), no stroke anywhere.
  Widget _paper(
    BuildContext context,
    double ring,
    bool showWord,
    TextStyle cue,
    double fit,
  ) {
    final skin = context.skin;
    final night = skin.night;
    final parts = skin.parts;
    final band = math.max(parts.holdBandLeast, ring * parts.holdBand);
    return Stack(
      fit: StackFit.expand,
      children: [
        CustomPaint(
          painter: HoldArcPainter(
            fill: _fill,
            amber: night.accent,
            shadow: night.elevation.badge.layers.first.color,
            lean: PaperLight.of(context),
            band: band,
            drop: parts.holdDrop,
            castAlpha: parts.holdArcAlpha,
          ),
        ),
        Padding(
          padding: EdgeInsets.all(band + parts.holdBandGap),
          child: PaperPiece(
            part: PaperPart.disc,
            id: 'hold',
            fill: night.panel,
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
                : const SizedBox.expand(),
          ),
        ),
      ],
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

/// The hold's progress, dressed up: a band of paper round the disc, the part
/// filled so far in amber paper from the top clockwise ([fill], 0 to 1), cast
/// with a hard two-step shadow away from the screen's light ([lean]). Only filled shapes:
/// no stroke.
class HoldArcPainter extends CustomPainter {
  HoldArcPainter({
    required this.fill,
    required this.amber,
    required this.shadow,
    required this.lean,
    required this.band,
    required this.drop,
    required this.castAlpha,
  }) : super(repaint: fill);

  final Animation<double> fill;
  final Color amber;
  final Color shadow;
  final double lean;
  final double band;

  /// How far the arc's shadow drops (down; sideways it leans with [lean] by
  /// as much).
  final double drop;
  final double castAlpha;

  Path _band(Rect outer, double sweep) {
    final inner = outer.deflate(band);
    return Path()
      ..arcTo(outer, -math.pi / 2, sweep, true)
      ..arcTo(inner, -math.pi / 2 + sweep, -sweep, false)
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    final outer = Offset.zero & size;
    final full = 2 * math.pi - 0.0001;
    final offset = Offset(lean * drop, drop);
    // No track under the arc: a dark band round the disc read as a stroked
    // inner ring (art director, 23 November 2026). The disc is the disc; only
    // the amber fill is drawn, and only while the finger is down.
    if (fill.value > 0) {
      final arc = _band(outer, math.min(full, 2 * math.pi * fill.value));
      canvas.drawPath(
        arc.shift(offset),
        Paint()..color = shadow.withValues(alpha: castAlpha),
      );
      canvas.drawPath(arc, Paint()..color = amber);
    }
  }

  @override
  bool shouldRepaint(HoldArcPainter old) =>
      old.amber != amber ||
      old.shadow != shadow ||
      old.lean != lean ||
      old.band != band;
}
