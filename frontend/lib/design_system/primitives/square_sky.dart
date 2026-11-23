import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../layout/space.dart';
import '../skin/art_set.dart';
import '../skin/end_art.dart';
import '../skin/skin.dart';
import 'end_lantern.dart';
import 'layered_art.dart';
import 'sliced_art.dart';
import 'band.dart';
import 'world_timer.dart';

/// 08's band over the square: one strip of night sky over the far roofs and
/// the gallows (the dawn's own layers, under a veil of the night so the clock
/// is the loudest thing), the clock large in its middle, the wall lantern
/// hung at its right (the square's one light), and the board's roof along
/// its foot. With no deadline ([secondsLeft] null) there is no number. The
/// screen's [title] is spoken, a header for a screen reader, and not drawn:
/// the clock says it. It lays out the status bar's inset itself.
class SquareSky extends StatelessWidget {
  const SquareSky({
    super.key,
    required this.secondsLeft,
    required this.title,
    this.semanticLabel,
  });

  final int? secondsLeft;
  final String title;

  /// Read out instead of the number.
  final String? semanticLabel;

  /// The sky's share of a phone's height below the status bar, and the most
  /// it takes on a tall one.
  static const share = 0.128;
  static const tallest = 100.0;

  /// From the sky's top to the number's.
  static const numberTop = Space.xl + Space.xs;

  /// The band's height below the status bar on a phone [screenHeight] tall,
  /// for a clock [numberHeight] tall: the sky's share, or as tall as the
  /// clock and the roof need.
  static double heightFor(double screenHeight, {double numberHeight = 0}) =>
      math.max(
        math.min(screenHeight * share, tallest),
        numberTop + numberHeight + Space.xs + SliceArt.roof.natural.height / 2,
      );

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final ground = context.ground;
    final safeTop = MediaQuery.paddingOf(context).top;
    final screen = MediaQuery.sizeOf(context);
    final seconds = secondsLeft;
    final number = seconds == null ? null : WorldTimer.format(seconds);
    final style = skin.typography.timer.copyWith(color: ground.text);
    final scaler = MediaQuery.textScalerOf(context);
    final line = (TextPainter(
      text: TextSpan(text: '0:00', style: style),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
      maxLines: 1,
    )..layout());
    final numberHeight = line.height;
    line.dispose();
    final height =
        safeTop + heightFor(screen.height, numberHeight: numberHeight);
    final roof = SliceArt.roof.natural.height;
    final lantern = EndArt.lanternSize * skin.parts.squareLantern;
    return SizedBox(
      height: height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned.fill(
            bottom: roof / 2,
            child: ExcludeSemantics(
              child: LayeredArt(
                LayeredSceneId.dawnGallows,
                slots: {'sun': (context, geometry, slot, arrival) => _veil},
              ),
            ),
          ),
          Positioned.fill(
            bottom: roof / 2,
            child: IgnorePointer(
              child: ColoredBox(
                color: ground.ground.withValues(alpha: skin.parts.squareVeil),
              ),
            ),
          ),
          Positioned(left: 0, right: 0, bottom: 0, child: const BoardRoof()),
          Positioned(
            right: Space.lg,
            top: safeTop - Space.hairline,
            child: EndLantern(scale: skin.parts.squareLantern),
          ),
          Positioned(
            left: lantern.width + Space.lg,
            right: lantern.width + Space.lg,
            top: safeTop + numberTop,
            child: Semantics(
              header: true,
              label: title,
              child: number == null
                  ? const SizedBox.shrink()
                  : Semantics(
                      label: semanticLabel ?? number,
                      excludeSemantics: true,
                      child: ClockFigure(
                        number,
                        style: style,
                        alignment: Alignment.center,
                      ),
                    ),
            ),
          ),
        ],
      ),
    );
  }

  /// Nothing in the dawn's sun slot: the square is lit by its lantern.
  static const Widget _veil = SizedBox.shrink();
}
