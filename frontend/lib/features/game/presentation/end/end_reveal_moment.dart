import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/widgets.dart';

import '../../../../design_system/copy/copy.dart';
import '../../../../design_system/layout/space.dart';
import '../../../../design_system/primitives/board_pieces.dart';
import '../../../../design_system/primitives/death_mark.dart';
import '../../../../design_system/primitives/furled_scroll.dart';
import '../../../../design_system/primitives/sliced_art.dart';
import '../../../../design_system/skin/skin.dart';
import '../../domain/end_board.dart';
import '../../domain/end_reveal.dart';
import 'end_reveal.dart';

// The reveal's moment (split from end_reveal.dart): the board dimming, each
// dead card's twin up big in the lantern's light, the HANGED stamp landing on
// it, and the banner unrolling from its furl, once.

/// The board dims while the dead are up, over the board's frame: still seen,
/// as the mock's is.
class RevealDim extends StatelessWidget {
  const RevealDim({super.key, required this.driver});

  final EndRevealDriver driver;

  /// How dark the board is at its dimmest.
  static const shade = 0.4;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: revealPaint(
      driver,
      opacity: () =>
          driver.at(RevealBeat.dim) * (1 - driver.at(RevealBeat.undim)),
      child: ColoredBox(
        color: context.skin.parts.boardShade.withValues(alpha: shade),
      ),
    ),
  );
}

/// How far a dead card is up: 0 in its slot, 1 big in the middle.
double liftedOf(EndRevealDriver driver, int card) =>
    Motion.curve.transform(driver.at(RevealBeat.lift, card: card)) *
    (1 - Motion.curve.transform(driver.at(RevealBeat.drop, card: card)));

/// A dead card's twin, drawn over the board while it is up, in a box of
/// [EndReveal.up] (the card with its art filling it): it leaves its slot face
/// down, grows to the middle of the window ([EndReveal.big]) turning face up
/// and to a tilt of a few degrees on the way, in the lantern's warm light,
/// takes the stamp ([RevealStamp]), holds, and goes back down to its slot,
/// where the card itself takes over.
class RevealHanged extends StatelessWidget {
  const RevealHanged({
    super.key,
    required this.driver,
    required this.card,
    required this.face,
  });

  final EndRevealDriver driver;
  final EndCard card;

  /// The face, filling the box, untilted.
  final Widget face;

  @override
  Widget build(BuildContext context) {
    final c = card;
    final reveal = driver.reveal!;
    final box = reveal.up[c.id]!, big = reveal.big[c.id]!;
    final back = reveal.backs[c.id]!;
    final parts = context.skin.parts;
    return IgnorePointer(
      child: revealPaint(
        driver,
        opacity: () => driver.isUp(c.id) ? 1 - handOver(driver, c.id) : 0,
        transform: (size) {
          final up = liftedOf(driver, c.id);
          // It leaves at its back's tilt and lands at its own.
          final from = driver.at(RevealBeat.drop, card: c.id) > 0
              ? c.angle
              : backAngleOf(c);
          final turn = lerpDouble(from, reveal.bigTurn[c.id]!, up)!;
          final scale = lerpDouble(1, big.width / box.width, up)!;
          return Matrix4.translationValues(
            (big.center.dx - box.center.dx) * up,
            (big.center.dy - box.center.dy) * up,
            0,
          )..multiply(
            about(size.center(Offset.zero), scaled(scale)..rotateZ(turn)),
          );
        },
        child: RevealTurn(
          driver: driver,
          value: () => driver.at(RevealBeat.turn, card: c.id),
          backAt: back.shift(-box.topLeft),
          back: BoardCardBack(
            name: c.name,
            size: back.size,
            portraitWidth: reveal.backPortrait,
            rect: back,
            headerHeight: c.header,
          ),
          face: Stack(
            fit: StackFit.expand,
            children: [
              face,
              // The lantern's warm light on it, from the lantern's side.
              DecoratedBox(
                decoration: BoxDecoration(
                  backgroundBlendMode: BlendMode.screen,
                  gradient: RadialGradient(
                    center: _fromTheLantern,
                    radius: 1.1,
                    colors: [
                      parts.poolColor.withValues(alpha: parts.poolAlpha),
                      parts.poolColor.withValues(alpha: 0),
                    ],
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  static const _fromTheLantern = Alignment(0.6, -0.7);
}

/// HANGED landing on a dead card at its biggest: laid in a box of
/// [EndReveal.big], turned as the card is, across the card's lower edge under
/// the role's tab ([DeathMark.stampRect]), at its own size (the words at their
/// size, not grown with the card). It slams down from larger, and lifts off
/// as the card goes back.
class RevealStamp extends StatelessWidget {
  const RevealStamp({super.key, required this.driver, required this.card});

  final EndRevealDriver driver;
  final EndCard card;

  /// How large the stamp comes down from, a share of its size, and how much
  /// larger it grows as it lifts off.
  static const slamFrom = 1.8;
  static const liftGrowth = 0.3;

  /// The plate is this share of the big card's width (the mock's).
  static const plateShare = 0.62;

  /// How far the stamp has lifted off as the card goes back (it is gone in
  /// the drop's first [Motion.quick]).
  double _off() =>
      (driver.at(RevealBeat.drop, card: card.id) *
              Motion.settle.inMicroseconds /
              Motion.quick.inMicroseconds)
          .clamp(0.0, 1.0);

  /// The foot of the role's tab on the big card, down from its top: where
  /// the stamp hangs from ([DeathMark.stampRect]).
  static double tabFootOf(EndCard c, EndReveal reveal) {
    final big = reveal.big[c.id]!;
    final scale = big.width / reveal.up[c.id]!.width;
    return big.height - BoardCard.stripUp * scale;
  }

  @override
  Widget build(BuildContext context) {
    final reveal = driver.reveal!;
    return IgnorePointer(
      child: Transform.rotate(
        angle: reveal.bigTurn[card.id]!,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 0,
              right: 0,
              top: tabFootOf(card, reveal),
              child: Align(
                alignment: Alignment.topCenter,
                child: revealPaint(
                  driver,
                  opacity: () {
                    final s = driver.at(RevealBeat.stamp, card: card.id);
                    return s <= 0 ? 0 : math.min(1.0, s * 2) * (1 - _off());
                  },
                  transform: (size) {
                    final s = driver.at(RevealBeat.stamp, card: card.id);
                    // It lands hard: the landing's overshoot stops at its
                    // own size (its word is never drawn smaller).
                    final slam = math.max(
                      1.0,
                      lerpDouble(slamFrom, 1, Motion.land.transform(s))!,
                    );
                    return about(
                      size.center(Offset.zero),
                      scaled(slam * (1 + _off() * liftGrowth)),
                    );
                  },
                  child: InkStamp(
                    label: EndCopy.hangedStamp,
                    width: reveal.big[card.id]!.width * plateShare,
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The banner, furled at the start: a roll lying on the roof, under where
/// the banner hangs ([restDrop] below its top). On its beat the roll is taken
/// up to the banner's top and across, then unrolls down, once, the sentence
/// whole from the start (only more of it is seen), and the roll is gone as
/// it reaches the foot. [height] is the banner's.
Widget revealUnroll(
  EndRevealDriver driver,
  Widget banner, {
  required double width,
  required double height,
  required double restDrop,
}) {
  final rollWidth = width - 2 * BannerSlice.margin;
  double p() => driver.at(RevealBeat.banner);
  double taken() => Motion.curve.transform((p() / _takenUp).clamp(0.0, 1.0));
  double open() => Motion.curve.transform(
    ((p() - _takenUp) / (1 - _takenUp)).clamp(0.0, 1.0),
  );
  return Stack(
    clipBehavior: Clip.none,
    children: [
      RepaintBoundary(
        child: ClipRect(
          clipper: _Unrolled(driver, () => open() * height),
          child: RepaintBoundary(child: banner),
        ),
      ),
      Positioned(
        top: 0,
        left: BannerSlice.margin,
        width: rollWidth,
        child: revealPaint(
          driver,
          opacity: () =>
              1 - ((open() - _rollGoes) / (1 - _rollGoes)).clamp(0.0, 1.0),
          transform: (size) {
            final y =
                lerpDouble(restDrop, 0, taken())! +
                open() * (height - FurledScroll.thickness);
            return Matrix4.translationValues(0, y, 0)..multiply(
              about(
                size.center(Offset.zero),
                Matrix4.diagonal3Values(
                  lerpDouble(_restShare, 1, taken())!,
                  1,
                  1,
                ),
              ),
            );
          },
          child: FurledScroll(width: rollWidth),
        ),
      ),
    ],
  );
}

/// The share of the banner's beat that takes the roll up, how wide it lies
/// at rest (a share of the banner's), and how far down it starts to go.
const _takenUp = 0.3;
const _restShare = 0.5;
const _rollGoes = 0.8;

class _Unrolled extends CustomClipper<Rect> {
  _Unrolled(this.driver, this.down) : super(reclip: driver.clock);

  final EndRevealDriver driver;
  final double Function() down;

  @override
  Rect getClip(Size size) =>
      Rect.fromLTRB(-size.width, -size.height, size.width * 2, down());

  @override
  bool shouldReclip(_Unrolled old) => driver != old.driver;
}
