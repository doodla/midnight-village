import 'dart:ui' show PathMetric, PointMode;

import 'package:flutter/material.dart';

import '../layout/space.dart';
import '../skin/ground.dart';
import '../skin/ground_scope.dart';
import '../skin/skin.dart';
import 'art_picture.dart';
import 'fit_line.dart';
import 'world_timer.dart';

/// What a [Band] is painted in.
enum BandTone {
  /// The night ground, on a day screen (the count's header, S10).
  night,

  /// Danger, with a curved foot (the winner's band when the Werewolves win,
  /// S11). Its content is on night.
  danger,
}

/// A strip across the top of a screen, edge to edge and under the status bar,
/// with its content inset by the gutter and the safe area. Put it in
/// `ScreenFrame.topSlot`. Its content is on night.
class Band extends StatelessWidget {
  const Band({super.key, required this.child, this.tone = BandTone.night});

  final Widget child;
  final BandTone tone;

  /// The mock's band padding (S10: 30 above, 20 below).
  static const _padding = EdgeInsets.fromLTRB(
    Space.gutter,
    Space.screenBottom + 2,
    Space.gutter,
    Space.lg + Space.xxs,
  );

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final top = MediaQuery.paddingOf(context).top;
    final night = skin.night;
    final content = Padding(
      padding: _padding.add(EdgeInsets.only(top: top)),
      child: GroundScope(ground: GroundKind.night, child: child),
    );
    return switch (tone) {
      BandTone.night => ColoredBox(color: night.ground, child: content),
      BandTone.danger => CustomPaint(
        painter: _ArchedFootPainter(
          fill: night.danger,
          shadow: night.elevation.primary.layers.first.color,
          ground: context.ground.ground,
          depth: Space.xxl * 1.5 * skin.shape.archRoundness,
          shadowDepth: Space.sm,
        ),
        child: Padding(
          padding: EdgeInsets.only(
            bottom: Space.xxl * 1.5 * skin.shape.archRoundness + Space.sm,
          ),
          child: content,
        ),
      ),
    };
  }
}

/// A band whose foot curves down in the middle, with a hard shadow below it.
class _ArchedFootPainter extends CustomPainter {
  _ArchedFootPainter({
    required this.fill,
    required this.shadow,
    required this.ground,
    required this.depth,
    required this.shadowDepth,
  });

  final Color fill;
  final Color shadow;
  final Color ground;
  final double depth;
  final double shadowDepth;

  Path _shape(Size size, double drop) {
    final foot = size.height - shadowDepth - depth;
    return Path()
      ..lineTo(size.width, 0)
      ..lineTo(size.width, foot + drop)
      ..quadraticBezierTo(
        size.width / 2,
        foot + depth * 2 + drop,
        0,
        foot + drop,
      )
      ..close();
  }

  @override
  void paint(Canvas canvas, Size size) {
    canvas
      ..drawRect(Offset.zero & size, Paint()..color = ground)
      ..drawPath(_shape(size, shadowDepth), Paint()..color = shadow)
      ..drawPath(_shape(size, 0), Paint()..color = fill);
  }

  @override
  bool shouldRepaint(_ArchedFootPainter old) =>
      old.fill != fill ||
      old.shadow != shadow ||
      old.ground != ground ||
      old.depth != depth ||
      old.shadowDepth != shadowDepth;
}

/// A day phase's countdown, edge to edge at the top of the screen (put it in
/// `ScreenFrame.topSlot`). It shows what it is given and stops at 0.
///
/// - [TimerBand.sun]: the talk (S08): the sky over the rooftops with the sun
///   [elapsed] of the way along its arc, fading into the day, then the large
///   number and its caption.
/// - [TimerBand.bar]: the vote (S09): a strip of night with the number and
///   caption, and a bar along its foot, [remaining] of it lit in the danger
///   line.
///
/// The number is set smaller rather than pushed off a narrow phone.
class TimerBand extends StatelessWidget {
  const TimerBand.sun({
    super.key,
    required this.secondsLeft,
    required this.elapsed,
    required this.caption,
    this.semanticLabel,
  }) : _sun = true,
       remaining = 0;

  const TimerBand.bar({
    super.key,
    required this.secondsLeft,
    required this.remaining,
    required this.caption,
    this.semanticLabel,
  }) : _sun = false,
       elapsed = 0;

  final int secondsLeft;
  final String caption;

  /// The sun: how far through the phase it is, 0 to 1.
  final double elapsed;

  /// The bar: how much of the phase is left, 0 to 1.
  final double remaining;

  /// Read out instead of the number and caption.
  final String? semanticLabel;
  final bool _sun;

  /// The sky's height below the status bar (S08).
  static const skyHeight = 250.0;

  /// The vote bar's thickness (S09).
  static const barHeight = 8.0;

  @override
  Widget build(BuildContext context) {
    final number = WorldTimer.format(secondsLeft);
    return Semantics(
      label: semanticLabel ?? '$number $caption',
      excludeSemantics: true,
      child: _sun ? _sky(context, number) : _bar(context, number),
    );
  }

  Widget _numberRow(BuildContext context, String number, TextStyle style) {
    final skin = context.skin;
    final ground = context.ground;
    // The number keeps its size up to 60% of the row, then shrinks; the
    // caption has the rest.
    return LayoutBuilder(
      builder: (context, constraints) => Row(
        crossAxisAlignment: CrossAxisAlignment.baseline,
        textBaseline: TextBaseline.alphabetic,
        spacing: Space.md,
        children: [
          ConstrainedBox(
            constraints: BoxConstraints(maxWidth: constraints.maxWidth * 0.6),
            child: FitLine(number, style: style),
          ),
          Expanded(
            child: FitWords(
              caption.toUpperCase(),
              style: skin.typography.label.copyWith(
                color: _sun ? ground.quietText : ground.text,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _sky(BuildContext context, String number) {
    final skin = context.skin;
    final ground = context.ground;
    final top = MediaQuery.paddingOf(context).top;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          height: skyHeight + top,
          child: Stack(
            fit: StackFit.expand,
            children: [
              ColoredBox(
                color: skin.night.ground,
                child: ArtPicture(skin.art.dawnGallows),
              ),
              Padding(
                padding: EdgeInsets.only(top: top),
                child: CustomPaint(
                  painter: _SunPainter(
                    elapsed: elapsed.clamp(0, 1),
                    sun: ground.mark,
                    line: ground.text,
                    lineWidth: skin.shape.ring,
                    outlineWidth: skin.shape.selectedRing,
                  ),
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    // The mock's fade: the last 70 of 250.
                    stops: const [0.72, 1],
                    colors: [ground.ground.withValues(alpha: 0), ground.ground],
                  ),
                ),
              ),
            ],
          ),
        ),
        Transform.translate(
          offset: const Offset(0, -Space.sm),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
            child: _numberRow(context, number, skin.typography.timer),
          ),
        ),
      ],
    );
  }

  Widget _bar(BuildContext context, String number) {
    final skin = context.skin;
    final night = skin.night;
    final top = MediaQuery.paddingOf(context).top;
    return GroundScope(
      ground: GroundKind.night,
      fill: true,
      child: Builder(
        builder: (context) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          spacing: Space.md,
          children: [
            Padding(
              padding: EdgeInsets.fromLTRB(
                Space.gutter,
                Space.xl + 2 + top,
                Space.gutter,
                0,
              ),
              child: _numberRow(context, number, skin.typography.timerVote),
            ),
            SizedBox(
              height: barHeight,
              child: ColoredBox(
                color: night.hairline,
                child: FractionallySizedBox(
                  alignment: AlignmentDirectional.centerStart,
                  widthFactor: remaining.clamp(0, 1),
                  child: ColoredBox(color: night.dangerLine),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The sun's path over the rooftops, dotted, and the sun [elapsed] along it
/// (the mock's `M20 190 Q195 -40 370 190` in a 390 x 250 sky).
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
