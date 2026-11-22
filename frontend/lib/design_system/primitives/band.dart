import 'dart:math' as math;
import 'dart:ui' show PathMetric, PointMode;

import 'package:flutter/material.dart';

import '../layout/space.dart';
import '../skin/ground.dart';
import '../skin/ground_scope.dart';
import '../skin/skin.dart';
import 'art_picture.dart';
import 'scene_arrival.dart';
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
/// - [TimerBand.sun]: the talk (S08): the sky over the rooftops with the pale
///   sun [elapsed] of the way along its arc, fading into the day, then the
///   large number.
/// - [TimerBand.bar]: the vote (S09): a strip of night with the number, and
///   a bar along its foot, [remaining] of it lit in the danger line.
///
/// The digits stand alone: the mocks' captions ("left to talk", "seconds to
/// choose") are cut (first-time play spec, copy rule 9). The number is set
/// smaller rather than pushed off a narrow phone. The screen's [title] sits
/// beside the number, on two lines at most, where the two fit side by side,
/// and under it where they do not (large text, a narrow phone).
///
/// Nothing is drawn that is not known: with no share of the stage (null
/// [elapsed] or [remaining]: an untimed stage) the sun
/// stands at one fixed place and the bar is unlit; with no deadline (null
/// [secondsLeft]) there is no number either.
class TimerBand extends StatelessWidget {
  const TimerBand.sun({
    super.key,
    required this.secondsLeft,
    required this.elapsed,
    this.title,
    this.semanticLabel,
  }) : _sun = true,
       remaining = null;

  const TimerBand.bar({
    super.key,
    required this.secondsLeft,
    required this.remaining,
    this.title,
    this.semanticLabel,
  }) : _sun = false,
       elapsed = null;

  /// Null: the stage has no deadline, and nothing is counted.
  final int? secondsLeft;

  /// The sun: how far through the phase it is, 0 to 1; null when unknown.
  final double? elapsed;

  /// The bar: how much of the phase is left, 0 to 1; null when unknown.
  final double? remaining;

  /// The screen's headline, beside or under the number.
  final String? title;

  /// Read out instead of the number.
  final String? semanticLabel;
  final bool _sun;

  /// The sky's height below the status bar (S08), on a phone of the mock's
  /// height; a shorter phone gets [skyShare] of its height at most, so the
  /// talk's body keeps room for My night and the deck.
  static const skyHeight = 250.0;
  static const skyShare = 0.3;

  /// The sky drawn on a screen [screenHeight] tall.
  static double skyFor(double screenHeight) =>
      math.min(skyHeight, screenHeight * skyShare);

  /// The vote bar's thickness (S09).
  static const barHeight = 8.0;

  /// Where the sun stands when the share of the talk is not known (the
  /// mock's place, about a third of the way along).
  static const restingSun = 0.3;

  @override
  Widget build(BuildContext context) {
    final seconds = secondsLeft;
    final number = seconds == null ? null : WorldTimer.format(seconds);
    return _sun ? _sky(context, number) : _bar(context, number);
  }

  /// The number and the title: side by side when the title fits beside the
  /// number on two lines, else the title under it.
  Widget _heading(
    BuildContext context,
    String? number,
    TextStyle numberStyle,
    Color titleColor,
  ) {
    final title = this.title;
    final spoken = semanticLabel ?? number;
    Widget digits(String number, {double? width}) => Semantics(
      label: spoken,
      excludeSemantics: true,
      child: width == null
          ? Align(
              alignment: AlignmentDirectional.centerStart,
              child: _Figure(number, style: numberStyle),
            )
          : SizedBox(
              width: width,
              child: _Figure(number, style: numberStyle),
            ),
    );
    if (title == null) {
      return number == null ? const SizedBox.shrink() : digits(number);
    }
    final titleStyle = context.skin.typography.screenTitle.copyWith(
      color: titleColor,
    );
    final head = Semantics(
      header: true,
      child: FitWords(title, style: titleStyle, maxLines: 2),
    );
    if (number == null) return head;
    return LayoutBuilder(
      builder: (context, room) {
        final scaler = MediaQuery.textScalerOf(context);
        // Side by side or stacked is decided on the number's shape
        // ("0:00"): the band's height holds still while the clock ticks (a
        // narrower "4:54" no longer stacks or unstacks the title, and with
        // it moves the body under the band). The number itself takes its own
        // width.
        final shapeWidth = _Figure.width(
          _Figure.shape(number),
          numberStyle,
          scaler,
        ).ceilToDouble();
        final numberWidth = _Figure.width(
          number,
          numberStyle,
          scaler,
        ).ceilToDouble();
        final beside = room.maxWidth - shapeWidth - Space.lg;
        if (_fitsTwoLines(title, titleStyle, scaler, beside)) {
          return Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            spacing: Space.lg,
            children: [
              digits(number, width: numberWidth),
              Expanded(child: head),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          mainAxisSize: MainAxisSize.min,
          spacing: Space.xs,
          children: [digits(number), head],
        );
      },
    );
  }

  static double _width(String text, TextStyle style, TextScaler scaler) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
      maxLines: 1,
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width;
  }

  /// [text] wraps between words into [room] on two lines at most.
  static bool _fitsTwoLines(
    String text,
    TextStyle style,
    TextScaler scaler,
    double room,
  ) {
    if (room <= 0) return false;
    final longestWord = text
        .split(' ')
        .map((w) => _width(w, style, scaler))
        .fold<double>(0, (a, b) => a > b ? a : b);
    if (longestWord > room) return false;
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
    )..layout(maxWidth: room);
    final lines = painter.computeLineMetrics().length;
    painter.dispose();
    return lines <= 2;
  }

  Widget _sky(BuildContext context, String? number) {
    final skin = context.skin;
    final ground = context.ground;
    final top = MediaQuery.paddingOf(context).top;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      mainAxisSize: MainAxisSize.min,
      children: [
        ExcludeSemantics(
          child: SizedBox(
            height: skyFor(MediaQuery.sizeOf(context).height) + top,
            child: Stack(
              fit: StackFit.expand,
              children: [
                // The night's ground is the sky's window; the rooftops and the
                // sun, one piece, rise into it when a scene brings this
                // screen in (the dawn): from below the window, the whole of
                // its height, the text under it not moving at all.
                ColoredBox(color: skin.night.ground),
                ClipRect(
                  child: ArrivalShift(
                    travel: 1,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        ArtPicture(skin.art.dawnGallows),
                        Padding(
                          padding: EdgeInsets.only(top: top),
                          child: CustomPaint(
                            painter: _SunPainter(
                              elapsed: elapsed?.clamp(0, 1).toDouble(),
                              // The pale sun: bone, never amber (copy rule 10).
                              sun: skin.night.text,
                              line: ground.text,
                              lineWidth: skin.shape.ring,
                              outlineWidth: skin.shape.selectedRing,
                            ),
                          ),
                        ),
                      ],
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
                      colors: [
                        ground.ground.withValues(alpha: 0),
                        ground.ground,
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
        Transform.translate(
          offset: const Offset(0, -Space.sm),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.gutter),
            child: _heading(
              context,
              number,
              skin.typography.timer,
              ground.text,
            ),
          ),
        ),
      ],
    );
  }

  Widget _bar(BuildContext context, String? number) {
    final skin = context.skin;
    final night = skin.night;
    final top = MediaQuery.paddingOf(context).top;
    final lit = remaining;
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
              child: _heading(
                context,
                number,
                skin.typography.timerVote,
                night.text,
              ),
            ),
            SizedBox(
              height: barHeight,
              child: ColoredBox(
                color: night.hairline,
                child: FractionallySizedBox(
                  alignment: AlignmentDirectional.centerStart,
                  widthFactor: number == null || lit == null
                      ? 0
                      : lit.clamp(0, 1).toDouble(),
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

  /// Null: not known; the sun stands at [TimerBand.restingSun].
  final double? elapsed;

  /// How far along the path the sun is at the start (and short of its end
  /// at the finish).
  static const rise = 0.12;

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

    // The sun rises clear of the rooftops and sets before it reaches them
    // again: the ends of the path are the horizon, not the talk.
    final along = rise + (1 - 2 * rise) * (elapsed ?? TimerBand.restingSun);
    final position = metric.getTangentForOffset(metric.length * along)!;
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

/// A clock's figure on one line, set smaller rather than broken: the number
/// at [style], and its unit ("14 s": the space and what follows) at a fraction
/// of it, so a hero-size number does not carry a hero-size "s".
class _Figure extends StatelessWidget {
  const _Figure(this.text, {required this.style});

  final String text;
  final TextStyle style;

  /// The unit's size against the number's.
  static const unitShare = 0.4;

  /// The figure as spans: the number, then the unit set smaller.
  static TextSpan span(String text, TextStyle style) {
    final space = text.lastIndexOf(' ');
    final size = style.fontSize;
    if (space < 0 || size == null) return TextSpan(text: text);
    // The space goes with the unit, at its size: a hero-size gap would
    // part them.
    return TextSpan(
      text: text.substring(0, space),
      children: [
        TextSpan(
          text: text.substring(space),
          style: TextStyle(fontSize: size * unitShare),
        ),
      ],
    );
  }

  /// [text] with every digit a zero: the clock's shape, whatever it reads
  /// (a digit wider than the zero is set a touch smaller in that room).
  static String shape(String text) => text.replaceAll(RegExp(r'\d'), '0');

  /// The figure's natural width, measured as it is drawn.
  static double width(String text, TextStyle style, TextScaler scaler) {
    final painter = TextPainter(
      text: TextSpan(style: style, children: [span(text, style)]),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
      maxLines: 1,
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width;
  }

  @override
  Widget build(BuildContext context) {
    return FittedBox(
      fit: BoxFit.scaleDown,
      alignment: AlignmentDirectional.centerStart,
      child: Text.rich(
        span(text, style),
        maxLines: 1,
        softWrap: false,
        style: style,
      ),
    );
  }
}
