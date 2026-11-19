import 'dart:ui' show PathMetric, PointMode;

import 'package:flutter/material.dart';

import '../skin/art_set.dart';
import '../skin/skin.dart';
import 'cut_paper.dart';

/// A countdown told by the world: a candle at night, the sun climbing over
/// the rooftops by day, with the number beside it. It shows what it is given
/// and stops at 0; the server says when the phase actually ends.
///
/// - [WorldTimer.candle]: the night's timer in its own panel.
/// - [WorldTimer.candleCompact]: a small candle and number for a screen's
///   corner.
/// - [WorldTimer.sun]: the day's timer: the sky, the sun on its arc
///   ([elapsed] of the way across), then the number.
class WorldTimer extends StatelessWidget {
  const WorldTimer.candle({
    super.key,
    required this.secondsLeft,
    required this.caption,
    this.semanticLabel,
  }) : _kind = _Kind.candle,
       elapsed = 0;

  const WorldTimer.candleCompact({
    super.key,
    required this.secondsLeft,
    this.semanticLabel,
  }) : _kind = _Kind.candleCompact,
       caption = null,
       elapsed = 0;

  const WorldTimer.sun({
    super.key,
    required this.secondsLeft,
    required this.elapsed,
    required this.caption,
    this.semanticLabel,
  }) : _kind = _Kind.sun;

  final int secondsLeft;

  /// Words beside the number, set as a label ("seconds of night").
  final String? caption;

  /// For the sun: how far through the phase it is, 0 to 1.
  final double elapsed;

  /// Read out instead of the number and caption.
  final String? semanticLabel;

  final _Kind _kind;

  /// The sky's height above the number.
  static const skyHeight = 250.0;

  /// Seconds as the mocks write them: "19" under a minute, "4:12" above.
  static String format(int seconds) {
    final s = seconds < 0 ? 0 : seconds;
    if (s < 60) return '$s';
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final number = format(secondsLeft);
    return Semantics(
      label: semanticLabel ?? [number, ?caption].join(' '),
      excludeSemantics: true,
      child: switch (_kind) {
        _Kind.candle => _candle(context, number),
        _Kind.candleCompact => _compact(context, number),
        _Kind.sun => _sun(context, number),
      },
    );
  }

  Widget _art(BuildContext context, ArtImage art, Size size, {Color? ring}) {
    final skin = context.skin;
    final radius = BorderRadius.circular(skin.shape.radiusSmall);
    return Container(
      width: size.width,
      height: size.height,
      foregroundDecoration: ring == null
          ? null
          : ringDecoration(color: ring, width: skin.shape.ring, radius: radius),
      child: ClipRRect(
        borderRadius: radius,
        child: Image(
          image: art.provider,
          fit: BoxFit.cover,
          alignment: art.focus,
        ),
      ),
    );
  }

  Widget _caption(BuildContext context, Color color) => Text(
    caption!.toUpperCase(),
    style: context.skin.typography.label.copyWith(color: color),
  );

  Widget _candle(BuildContext context, String number) {
    final skin = context.skin;
    final ground = context.ground;
    final radius = BorderRadius.circular(skin.shape.radius);
    return Container(
      padding: EdgeInsets.fromLTRB(
        skin.spacing.md,
        skin.spacing.md,
        skin.spacing.xl,
        skin.spacing.md,
      ),
      decoration: BoxDecoration(color: ground.panel, borderRadius: radius),
      foregroundDecoration: ringDecoration(
        color: ground.hairline,
        width: skin.shape.ring,
        radius: radius,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          _art(context, skin.art.candle, const Size(66, 88)),
          SizedBox(width: skin.spacing.lg),
          Text(number, style: skin.typography.timerSmall),
          SizedBox(width: skin.spacing.lg),
          Flexible(child: _caption(context, ground.quietText)),
        ],
      ),
    );
  }

  Widget _compact(BuildContext context, String number) {
    final skin = context.skin;
    final ground = context.ground;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        _art(
          context,
          skin.art.candle,
          const Size(44, 58),
          ring: ground.hairline,
        ),
        SizedBox(width: skin.spacing.md),
        Text.rich(
          TextSpan(
            text: number,
            style: skin.typography.display.copyWith(height: 1),
            children: [
              TextSpan(
                text: ' s',
                style: skin.typography.caption.copyWith(
                  color: ground.quietText,
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  Widget _sun(BuildContext context, String number) {
    final skin = context.skin;
    final ground = context.ground;
    final sky = skin.art.dawnGallows;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: skyHeight,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(
                color: skin.night.ground,
                child: Image(
                  image: sky.provider,
                  fit: BoxFit.cover,
                  alignment: sky.focus,
                ),
              ),
              CustomPaint(
                painter: _SunPainter(
                  elapsed: elapsed.clamp(0, 1),
                  sun: ground.mark,
                  line: ground.text,
                  lineWidth: skin.shape.ring,
                  outlineWidth: skin.shape.selectedRing,
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    stops: const [0.72, 1],
                    colors: [ground.ground.withValues(alpha: 0), ground.ground],
                  ),
                ),
              ),
            ],
          ),
        ),
        Transform.translate(
          offset: Offset(0, -skin.spacing.sm),
          child: Padding(
            padding: EdgeInsets.symmetric(horizontal: skin.spacing.gutter),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.baseline,
              textBaseline: TextBaseline.alphabetic,
              children: [
                Text(number, style: skin.typography.timer),
                SizedBox(width: skin.spacing.md),
                Expanded(child: _caption(context, ground.quietText)),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

enum _Kind { candle, candleCompact, sun }

/// The sun's path over the rooftops, dotted, and the sun [elapsed] along it.
class _SunPainter extends CustomPainter {
  _SunPainter({
    required this.elapsed,
    required this.sun,
    required this.line,
    required this.lineWidth,
    required this.outlineWidth,
  });

  final double elapsed;
  final Color sun;
  final Color line;
  final double lineWidth;
  final double outlineWidth;

  @override
  void paint(Canvas canvas, Size size) {
    // The mock's arc: from low left over the roofs to low right.
    final arc = Path()
      ..moveTo(size.width * 0.05, size.height * 0.76)
      ..quadraticBezierTo(
        size.width / 2,
        -size.height * 0.16,
        size.width * 0.95,
        size.height * 0.76,
      );
    final metric = arc.computeMetrics().first;
    _dots(canvas, metric);

    final position = metric.getTangentForOffset(metric.length * elapsed)!;
    final radius = size.height * 0.076;
    canvas
      ..drawCircle(position.position, radius, Paint()..color = sun)
      ..drawCircle(
        position.position,
        radius,
        Paint()
          ..color = line
          ..style = PaintingStyle.stroke
          ..strokeWidth = outlineWidth,
      );
  }

  void _dots(Canvas canvas, PathMetric metric) {
    final dot = Paint()
      ..color = line.withValues(alpha: 0.55)
      ..strokeWidth = lineWidth
      ..strokeCap = StrokeCap.round;
    const step = 11.0;
    for (var d = 0.0; d < metric.length; d += step) {
      final p = metric.getTangentForOffset(d)!.position;
      canvas.drawPoints(PointMode.points, [p], dot);
    }
  }

  @override
  bool shouldRepaint(_SunPainter old) =>
      old.elapsed != elapsed ||
      old.sun != sun ||
      old.line != line ||
      old.lineWidth != lineWidth ||
      old.outlineWidth != outlineWidth;
}
