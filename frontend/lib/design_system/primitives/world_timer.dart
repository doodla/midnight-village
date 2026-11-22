import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../copy/copy.dart';
import '../layout/space.dart';
import '../skin/art_set.dart';
import '../skin/skin.dart';
import 'art_picture.dart';
import 'candle_gauge.dart';
import 'cut_paper.dart';

/// The night's countdown, told by a candle, with the number beside it. It
/// shows what it is given and stops at 0; the server says when the phase
/// actually ends. (The day's timers run edge to edge: `TimerBand`.)
///
/// - [WorldTimer.candle]: in its own panel (S05).
/// - [WorldTimer.candleCompact]: a drawn candle ([CandleGauge]: its flame and
///   wax shrink with the window, stepping with the number) and the number,
///   beside the night board's title (S06).
///
/// The mocks' "seconds of night" is cut (first-time play spec, copy rule 9);
/// under a minute the number keeps its unit ("14 s"), which a bare number did
/// not say (cold read on the real screens). On a narrow phone or with large text
/// the candle and the number shrink rather than push the panel past the
/// screen.
class WorldTimer extends StatelessWidget {
  const WorldTimer.candle({
    super.key,
    required this.secondsLeft,
    this.semanticLabel,
  }) : _compact = false,
       share = null,
       candleHeight = 90,
       lineHeight = null,
       lift = 0;

  const WorldTimer.candleCompact({
    super.key,
    required this.secondsLeft,
    this.share,
    this.candleHeight = 90,
    this.lineHeight,
    this.lift = 0,
    this.semanticLabel,
  }) : _compact = true;

  /// Null while the phone does not know the deadline yet (05 while `/me/`
  /// loads): the candle alone, no number made up.
  final int? secondsLeft;

  /// How much of the window is left, 0 to 1, for the compact candle (null:
  /// the candle whole, the server did not say how long the window is).
  final double? share;

  /// The compact candle's height.
  final double candleHeight;

  /// The height of the title's first line beside the compact timer: the
  /// number sits in it, level with the title, the candle standing from its top.
  /// Null: the number is centred on the candle.
  final double? lineHeight;

  /// How far the candle stands above the number's line (the candle's top is
  /// the unit's top; the number sits [lift] lower).
  final double lift;

  /// The corner number's size, of the skin's `timerCompact`: smaller than it
  /// was drawn when it sat in a 46 px unit (27 px), so the unit is narrow
  /// enough to leave the title all the width it had; the candle carries the
  /// drama, the number the fact.
  static const cornerNumberScale = 0.6;

  /// Read out instead of the number.
  final String? semanticLabel;

  final bool _compact;

  /// The candle picture's size in the panel (S05).
  static const candleSize = Size(66, 88);

  /// Seconds as a clock: "19 s" under a minute, "4:12" from a minute.
  static String format(int seconds) {
    final s = seconds < 0 ? 0 : seconds;
    if (s < 60) return CommonCopy.seconds.fill({'n': s});
    return '${s ~/ 60}:${(s % 60).toString().padLeft(2, '0')}';
  }

  @override
  Widget build(BuildContext context) {
    final seconds = secondsLeft;
    final number = seconds == null ? null : format(seconds);
    return Semantics(
      label: semanticLabel ?? number,
      excludeSemantics: true,
      // In a row that gives it unbounded width (a header beside a title) it
      // takes its mock size; given a width, its parts shrink to fit it.
      child: LayoutBuilder(
        builder: (context, constraints) => _compact
            ? _corner(context, number, constraints.hasBoundedWidth)
            : _panel(context, number),
      ),
    );
  }

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
      foregroundDecoration: ringDecoration(
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

  Widget _corner(BuildContext context, String? number, bool bounded) {
    final style = context.skin.typography.timerCompact;
    final numberStyle = style.copyWith(
      fontSize: style.fontSize! * cornerNumberScale,
    );
    final candle = CandleGauge(share: share, height: candleHeight);
    if (number == null) return candle;
    // The number is the unit's own size, whatever the text size (the title
    // beside it stops growing, and must not give way to the seconds): its slot
    // is as wide as the widest it can read in its form, its right edge a gap
    // (the width of its "s") from the candle, so nothing shifts as a ten turns
    // into a nine and nothing touches the flame or the wax.
    final slot = _slot(numberStyle, number);
    final line = lineHeight ?? candleHeight;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: _width('s', numberStyle) + 1,
      children: [
        Padding(
          padding: EdgeInsets.only(top: lift),
          child: SizedBox(
            width: slot,
            height: line,
            child: Align(
              alignment: Alignment.centerRight,
              child: Text(
                number,
                textScaler: TextScaler.noScaling,
                style: numberStyle,
              ),
            ),
          ),
        ),
        candle,
      ],
    );
  }

  static double _width(String text, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
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
