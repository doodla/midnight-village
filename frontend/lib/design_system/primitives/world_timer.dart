import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../copy/copy.dart';
import '../layout/space.dart';
import '../skin/art_set.dart';
import '../skin/skin.dart';
import 'art_picture.dart';
import 'band.dart';
import 'candle_gauge.dart';
import 'countdown.dart';
import 'cut_paper.dart';

// A clock is handed what it counts; the seconds stay inside it.
export 'countdown.dart' show Countdown, StageShare;

/// The night's countdown, told by a candle, with the number beside it. It
/// shows what it is given and stops at 0; the server says when the phase
/// actually ends. (The day's timers run edge to edge: `TimerBand`.)
///
/// - [WorldTimer.candle]: in its own panel (S05).
/// - [WorldTimer.candleCompact]: a drawn candle ([CandleGauge]: its flame and
///   wax shrink with the window, stepping with the number) and the number
///   in the one timer style (`timerSmall`), beside the night board's title
///   (S06).
///
/// The mocks' "seconds of night" is cut (first-time play spec, copy rule 9);
/// under a minute the number keeps its unit ("14 s"), which a bare number did
/// not say (cold read on the real screens). On a narrow phone or with large text
/// the candle and the number shrink rather than push the panel past the
/// screen.
class WorldTimer extends StatelessWidget {
  const WorldTimer.candle({
    super.key,
    required this.countdown,
    this.semanticLabel,
  }) : _compact = false,
       candleHeight = 90,
       lineHeight = null,
       maxNumberWidth = null;

  const WorldTimer.candleCompact({
    super.key,
    required this.countdown,
    this.candleHeight = 90,
    this.lineHeight,
    this.maxNumberWidth,
    this.semanticLabel,
  }) : _compact = true;

  /// What it counts down ([ClockTick] reads it, nothing else). Null while
  /// the phone does not know the deadline yet (05 while `/me/` loads): the
  /// candle alone, no number made up. The compact candle burns down with
  /// the stage's share left; with no share (the server did not say how long
  /// the window is) it stands whole.
  final Countdown? countdown;

  /// The compact candle's height.
  final double candleHeight;

  /// The height of the number's room beside the compact candle: the number
  /// is centred in it. Null: the candle's height.
  final double? lineHeight;

  /// The most room the number may take: where its slot is wider (a narrow
  /// phone with minutes on the clock) it is set smaller to fit, so the title
  /// beside it keeps its room. Null: the slot is the number's own.
  final double? maxNumberWidth;

  /// Read out instead of the number.
  final String? semanticLabel;

  final bool _compact;

  /// The candle picture's size in the panel (S05).
  static const candleSize = Size(66, 88);

  /// The least line the compact number may be given (its [lineHeight]): the
  /// unit ("s", at [ClockFigure.unitShare] of the number) still at the
  /// reading floor. A quiet clock beside a screen's title (04) stands this
  /// high; the night board's stands at its own size.
  static const quietLine = ReadingFloor.act / ClockFigure.unitShare;

  /// Seconds as a clock: "19 s" under a minute, "4:12" from a minute.
  static String format(int seconds) {
    final s = seconds < 0 ? 0 : seconds;
    if (s < 60) return CommonCopy.seconds.fill({'n': s});
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) => ClockTick(
    countdown: countdown,
    builder: (context, reading) {
      final seconds = reading.seconds;
      final number = seconds == null ? null : format(seconds);
      return Semantics(
        label: semanticLabel ?? number,
        excludeSemantics: true,
        // In a row that gives it unbounded width (a header beside a title)
        // it takes its mock size; given a width, its parts shrink to fit it.
        child: _compact
            ? _corner(context, number, reading.share)
            : _panel(context, number),
      );
    },
  );

  Widget _panel(BuildContext context, String? number) {
    final skin = context.skin;
    final ground = context.ground;
    final radius = BorderRadius.circular(skin.shape.radius);
    return Container(
      padding: const EdgeInsets.fromLTRB(
        Space.smPlus,
        Space.smPlus,
        Space.xl - 2,
        Space.smPlus,
      ),
      decoration: BoxDecoration(color: ground.panel, borderRadius: radius),
      foregroundDecoration: frameRing(
        context,
        color: ground.hairline,
        width: skin.shape.ring,
        radius: radius,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        spacing: Space.lg,
        children: [
          Flexible(flex: 2, child: _Candle(size: candleSize)),
          if (number != null)
            Flexible(
              flex: 3,
              child: FittedBox(
                fit: BoxFit.scaleDown,
                child: Text(number, style: skin.typography.timerSmall),
              ),
            ),
        ],
      ),
    );
  }

  Widget _corner(BuildContext context, String? number, double? share) {
    // The night's timer is the one timer style (`timerSmall`, the number as
    // the vote's and the talk's are drawn: the unit at a share of it), at its
    // own size whatever the text size.
    final numberStyle = context.skin.typography.timerSmall;
    final candle = CandleGauge(share: share, height: candleHeight);
    if (number == null) return candle;
    // The number's slot is as wide as the widest it can read in its form, its
    // right edge a gap from the candle, so nothing shifts as a ten turns into
    // a nine and nothing touches the flame or the wax.
    final line = lineHeight ?? candleHeight;
    // In a line lower than the number's own, the number is set smaller to
    // fit it, and its slot with it (no room left empty beside the title).
    final fit = math.min(
      1.0,
      line / (numberStyle.fontSize! * (numberStyle.height ?? 1)),
    );
    final slot = _slot(numberStyle, number) * fit;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.center,
      spacing: Space.sm,
      children: [
        SizedBox(
          width: maxNumberWidth == null
              ? slot
              : math.min(slot, maxNumberWidth!),
          height: line,
          child: ClockFigure(
            number,
            style: numberStyle,
            alignment: Alignment.centerRight,
            textScaler: TextScaler.noScaling,
          ),
        ),
        candle,
      ],
    );
  }

  static double _width(String text, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(style: style, children: [ClockFigure.span(text, style)]),
      textDirection: TextDirection.ltr,
      textScaler: TextScaler.noScaling,
    )..layout();
    final w = painter.width;
    painter.dispose();
    return w;
  }

  /// The width of the widest the number can read in the form it is in: two
  /// of the widest digit and the unit ("88 s") under a minute, minutes and
  /// seconds ("8:88") from a minute. The digits are not all one width, and
  /// the candle beside them must not move as they change.
  double _slot(TextStyle style, String number) {
    final digit = [
      for (var d = 0; d < 10; d++) _width('$d', style),
    ].reduce(math.max);
    return number.contains(':')
        ? math.max(3 * digit + _width(':', style), _width(number, style))
        : 2 * digit + _width(format(0).substring(1), style);
  }
}

/// The candle picture, at most [size], keeping its shape.
class _Candle extends StatelessWidget {
  const _Candle({required this.size});

  final Size size;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: size.width),
      child: AspectRatio(
        aspectRatio: size.aspectRatio,
        child: ClipRRect(
          borderRadius: BorderRadius.circular(skin.shape.radiusSmall),
          child: ArtPicture(skin.art.scene(Scene.candle)),
        ),
      ),
    );
  }
}
