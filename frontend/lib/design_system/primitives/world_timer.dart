import 'package:flutter/material.dart';

import '../copy/copy.dart';
import '../layout/space.dart';
import '../skin/art_set.dart';
import '../skin/skin.dart';
import 'art_picture.dart';
import 'cut_paper.dart';

/// The night's countdown, told by a candle, with the number beside it. It
/// shows what it is given and stops at 0; the server says when the phase
/// actually ends. (The day's timers run edge to edge: `TimerBand`.)
///
/// - [WorldTimer.candle]: in its own panel (S05).
/// - [WorldTimer.candleCompact]: a small candle and the number, for a
///   screen's corner (S06).
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
  }) : _compact = false;

  const WorldTimer.candleCompact({
    super.key,
    required this.secondsLeft,
    this.semanticLabel,
  }) : _compact = true;

  /// Null while the phone does not know the deadline yet (05 while `/me/`
  /// loads): the candle alone, no number made up.
  final int? secondsLeft;

  /// Read out instead of the number.
  final String? semanticLabel;

  final bool _compact;

  /// The candle's size in the panel and in the corner (S05, S06).
  static const candleSize = Size(66, 88);
  static const compactCandleSize = Size(44, 58);

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
    final skin = context.skin;
    return Row(
      mainAxisSize: MainAxisSize.min,
      spacing: Space.smPlus,
      children: [
        _flex(
          bounded,
          1,
          _Candle(size: compactCandleSize, ring: context.ground.hairline),
        ),
        if (number != null)
          _flex(
            bounded,
            2,
            FittedBox(
              fit: BoxFit.scaleDown,
              child: Text(number, style: skin.typography.timerCompact),
            ),
          ),
      ],
    );
  }
}

Widget _flex(bool bounded, int flex, Widget child) =>
    bounded ? Flexible(flex: flex, child: child) : child;

/// The candle picture, at most [size], keeping its shape.
class _Candle extends StatelessWidget {
  const _Candle({required this.size, this.ring});

  final Size size;
  final Color? ring;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final radius = BorderRadius.circular(skin.shape.radiusSmall);
    return ConstrainedBox(
      constraints: BoxConstraints(maxWidth: size.width),
      child: AspectRatio(
        aspectRatio: size.aspectRatio,
        child: Container(
          foregroundDecoration: ring == null
              ? null
              : ringDecoration(
                  color: ring!,
                  width: skin.shape.ring,
                  radius: radius,
                ),
          child: ClipRRect(
            borderRadius: radius,
            child: ArtPicture(skin.art.scene(Scene.candle)),
          ),
        ),
      ),
    );
  }
}
