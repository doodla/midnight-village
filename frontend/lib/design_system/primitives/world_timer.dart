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

  /// The corner number's size, of the skin's `timerCompact`: what it was drawn
  /// at when it sat in a 46 px unit (the board's numbers run no bigger than
  /// that); the candle carries the drama, the number the fact.
  static const cornerNumberScale = 0.8;

  /// How far the number reaches into the candle's empty margin.
  static const cornerOverlap = 6.0;

  /// Read out instead of the number.
  final String? semanticLabel;

  final bool _compact;

  /// The candle's size in the panel and in the corner (S05, S06).
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
    final size = style.fontSize! * cornerNumberScale;
    final candle = CandleGauge(share: share, height: candleHeight);
    if (number == null) return candle;
    // The number is the unit's own size, whatever the text size (the title
    // beside it stops growing, and must not give way to the seconds): its slot
    // is as wide as the widest it can read, its right edge against the
    // candle, so nothing shifts as a ten turns into a nine.
    final slot = _slot(style.copyWith(fontSize: size), number);
    final line = lineHeight ?? candleHeight;
    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.start,
      // Laid out right to left, the candle first: it is painted under the
      // number, whose end reaches over its empty margin.
      textDirection: TextDirection.rtl,
      children: [
        candle,
        // The candle's picture has empty paper to the left of its dish: the
        // number's box is that much narrower than the number, which reaches
        // into it.
        Padding(
          padding: EdgeInsets.only(top: lift),
          child: SizedBox(
            width: slot - cornerOverlap,
            height: line,
            child: OverflowBox(
              alignment: Alignment.centerLeft,
              minWidth: slot,
              maxWidth: slot,
              child: Align(
                alignment: Alignment.centerRight,
                child: Text(
                  number,
                  textScaler: TextScaler.noScaling,
                  style: style.copyWith(fontSize: size),
                ),
              ),
            ),
          ),
        ),
      ],
    );
  }

  /// The width of the widest the number can read in the form it is in: two
  /// of the widest digit and the unit ("88 s") under a minute, minutes and
  /// seconds ("8:88") from a minute. The digits are not all one width, and
  /// the candle beside them must not move as they change.
  double _slot(TextStyle style, String number) {
    double width(String text) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: TextDirection.ltr,
        textScaler: TextScaler.noScaling,
      )..layout();
      final w = painter.width;
      painter.dispose();
      return w;
    }

    final digit = [for (var d = 0; d < 10; d++) width('$d')].reduce(math.max);
    return number.contains(':')
        ? math.max(3 * digit + width(':'), width(number))
        : 2 * digit + width(format(0).substring(1));
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
