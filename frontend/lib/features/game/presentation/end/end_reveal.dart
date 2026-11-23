import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../../../../design_system/copy/copy.dart';
import '../../../../design_system/layout/space.dart';
import '../../../../design_system/primitives/death_mark.dart';
import '../../../../design_system/primitives/paper_flip.dart';
import '../../../../design_system/skin/skin.dart';
import '../../domain/end_board.dart';
import '../../domain/end_reveal.dart';
import '../../../../design_system/primitives/board_pieces.dart';

// The end board's reveal, in place (docs/specs/frontend/end-board.md, section
// 8): one clock ([EndRevealDriver]) and the timeline it runs (`revealOf`),
// read by the board's own pieces through [EndRevealScope]. With no driver in
// the scope (the board settled, or opened late) every piece is drawn exactly
// as the static board draws it.
//
// A frame of the reveal builds nothing and lays nothing out: each piece that
// moves is a [RevealPaint], a render object that listens to the clock itself
// and only paints its child again moved, scaled, faded or clipped; the child
// is a repaint boundary of its own, so the paper is painted once. (A widget
// rebuilt on each tick would lay the board out again: the board is built
// inside layout builders.)

/// The reveal's one clock: an [AnimationController] from 0 to 1 over the
/// whole [reveal], which is known once the board is planned.
class EndRevealDriver {
  EndRevealDriver(this.clock);

  final AnimationController clock;
  EndReveal? reveal;

  /// Where the reveal stands (the start until the board is planned).
  Duration get now {
    final r = reveal;
    return r == null ? Duration.zero : r.total * clock.value;
  }

  /// How far [kind] is now (0 before the board is planned).
  double at(RevealBeat kind, {int? card, int? row}) =>
      reveal?.at(kind, now, card: card, row: row) ?? 0;

  /// Whether the beat of [kind] is there at all.
  bool has(RevealBeat kind, {int? card}) =>
      reveal?.of(kind, card: card) != null;
}

/// The driver of the reveal playing under it; null when the board is settled.
class EndRevealScope extends InheritedWidget {
  const EndRevealScope({super.key, required this.driver, required super.child});

  final EndRevealDriver? driver;

  static EndRevealDriver? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<EndRevealScope>()?.driver;

  @override
  bool updateShouldNotify(EndRevealScope old) => driver != old.driver;
}

/// Its child painted, on each tick of [clock], through [transform] (in the
/// child's own coordinates; null for none) at [opacity] (0 paints nothing).
/// Nothing is built or laid out on a tick.
class RevealPaint extends SingleChildRenderObjectWidget {
  const RevealPaint({
    super.key,
    required this.clock,
    this.opacity,
    this.transform,
    super.child,
  });

  final Listenable clock;
  final double Function()? opacity;
  final Matrix4? Function(Size size)? transform;

  @override
  RenderRevealPaint createRenderObject(BuildContext context) =>
      RenderRevealPaint(clock, opacity, transform);

  @override
  void updateRenderObject(
    BuildContext context,
    RenderRevealPaint renderObject,
  ) => renderObject
    ..clock = clock
    ..opacity = opacity
    ..transform = transform;
}

class RenderRevealPaint extends RenderProxyBox {
  RenderRevealPaint(this._clock, this.opacity, this.transform);

  Listenable _clock;
  double Function()? opacity;
  Matrix4? Function(Size size)? transform;

  set clock(Listenable value) {
    if (identical(value, _clock)) return;
    if (attached) {
      _clock.removeListener(markNeedsPaint);
      value.addListener(markNeedsPaint);
    }
    _clock = value;
    markNeedsPaint();
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _clock.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _clock.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  bool get alwaysNeedsCompositing => child != null;

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child == null) return;
    final o = (opacity?.call() ?? 1).clamp(0.0, 1.0);
    if (o <= 0) return;
    final m = transform?.call(size);
    void moved(PaintingContext context, Offset offset) => m == null
        ? context.paintChild(child, offset)
        : context.pushTransform(
            true,
            offset,
            m,
            (context, offset) => context.paintChild(child, offset),
          );
    if (o >= 1) {
      moved(context, offset);
    } else {
      context.pushOpacity(offset, (o * 255).round(), moved);
    }
  }

  // The moving pieces are seen, not touched: a touch settles the reveal.
  @override
  bool hitTest(BoxHitTestResult result, {required Offset position}) => false;
}

/// [child] painted once, and moved, faded or clipped by the clock: a repaint
/// boundary inside and one outside, so neither it nor what lies beside it is
/// painted again on a tick.
Widget revealPaint(
  EndRevealDriver driver, {
  double Function()? opacity,
  Matrix4? Function(Size size)? transform,
  required Widget child,
}) => RepaintBoundary(
  child: RevealPaint(
    clock: driver.clock,
    opacity: opacity,
    transform: transform,
    child: RepaintBoundary(child: child),
  ),
);

/// [m] about [centre] (a point of the child).
Matrix4 about(Offset centre, Matrix4 m) =>
    Matrix4.translationValues(centre.dx, centre.dy, 0)
      ..multiply(m)
      ..multiply(Matrix4.translationValues(-centre.dx, -centre.dy, 0));

Matrix4 _scale(double s) => Matrix4.diagonal3Values(s, s, 1);

/// [child] coming in over [kind]: a fade.
Widget revealFade(
  EndRevealDriver driver,
  RevealBeat kind,
  Widget child, {
  int? card,
}) => revealPaint(
  driver,
  opacity: () => driver.at(kind, card: card),
  child: child,
);

/// A card turning over where it lies, driven by [value] (0 face down, 1 face
/// up) on the clock: [PaperFlip]'s turn (its lift, growth, perspective and
/// landing) without a controller of its own, and with no vibration.
class RevealTurn extends StatelessWidget {
  const RevealTurn({
    super.key,
    required this.driver,
    required this.value,
    required this.back,
    required this.face,
  });

  final EndRevealDriver driver;
  final double Function() value;
  final Widget back;
  final Widget face;

  double _v() {
    final t = value();
    return t <= 0
        ? 0.0
        : t >= 1
        ? 1.0
        : PaperFlip.landing.transform(t);
  }

  Matrix4 _matrix(Size size, double v, {required bool face}) {
    final angle = v * math.pi;
    final edgeOn = math.sin(angle.clamp(0.0, math.pi));
    final scale = 1 + PaperFlip.grow * edgeOn;
    final m = Matrix4.translationValues(0, -PaperFlip.lift * edgeOn, 0)
      ..setEntry(3, 2, PaperFlip.perspective)
      ..scaleByDouble(scale, scale, scale, 1)
      ..rotateY(face ? angle - math.pi : angle);
    return about(size.center(Offset.zero), m);
  }

  @override
  Widget build(BuildContext context) => Stack(
    clipBehavior: Clip.none,
    children: [
      revealPaint(
        driver,
        opacity: () => PaperFlip.isFaceUp(_v()) ? 0 : 1,
        transform: (size) => _matrix(size, _v(), face: false),
        child: back,
      ),
      Positioned.fill(
        child: revealPaint(
          driver,
          opacity: () => PaperFlip.isFaceUp(_v()) ? 1 : 0,
          transform: (size) => _matrix(size, _v(), face: true),
          child: face,
        ),
      ),
    ],
  );
}

/// A player's card turning on the clock: the night's back with the name, then
/// [face].
Widget revealCardTurn(EndRevealDriver driver, EndCard c, Widget face) =>
    RevealTurn(
      driver: driver,
      value: () => driver.at(RevealBeat.turn, card: c.id),
      back: BoardCardBack(
        name: c.name,
        size: c.rect.size,
        portraitWidth: c.portraitWidth,
        rect: c.rect,
        angle: c.angle,
        headerHeight: c.header,
      ),
      face: face,
    );

/// The card's whole box ([box], in the board's content) growing from the one
/// size every card starts at to its own, about the card's centre; a hanged
/// card's box stays hidden while its twin is up ([RevealHanged]).
Widget revealCardBox(
  EndRevealDriver driver,
  EndCard c,
  Rect box,
  Widget child,
) {
  bool lifted() => driver.reveal?.big.containsKey(c.id) ?? false;
  return revealPaint(
    driver,
    opacity: () => lifted() ? handOver(driver) : 1,
    transform: (size) {
      final from = driver.reveal?.startScale[c.id] ?? 1;
      if (from == 1 || lifted()) return null;
      final grown = Motion.curve.transform(driver.at(RevealBeat.grow));
      return about(
        c.rect.center - box.topLeft,
        _scale(lerpDouble(from, 1, grown)!),
      );
    },
    child: child,
  );
}

/// How far a hanged card's slot has taken over from its twin: 0 while the
/// twin is up, to 1 over the last of the drop, as it comes into the shadow.
double handOver(EndRevealDriver driver) =>
    ((driver.at(RevealBeat.drop) - _handOverFrom) / (1 - _handOverFrom)).clamp(
      0.0,
      1.0,
    );

const _handOverFrom = 0.6;

/// A mark pinned on as [kind] lands (a ribbon, a slip): it comes down onto
/// the card from a little larger.
Widget revealPinned(
  EndRevealDriver driver,
  RevealBeat kind,
  int card,
  Widget child,
) => revealPaint(
  driver,
  opacity: () => math.min(1, driver.at(kind, card: card) * 3),
  transform: (size) => about(
    size.center(Offset.zero),
    _scale(
      lerpDouble(
        _pinFrom,
        1,
        Motion.land.transform(driver.at(kind, card: card)),
      )!,
    ),
  ),
  child: child,
);

const _pinFrom = 1.5;

/// The others dim while the hanged are up, over the board's frame.
class RevealDim extends StatelessWidget {
  const RevealDim({super.key, required this.driver});

  final EndRevealDriver driver;

  /// How dark the board is at its dimmest.
  static const shade = 0.55;

  @override
  Widget build(BuildContext context) => IgnorePointer(
    child: revealPaint(
      driver,
      opacity: () =>
          driver.at(RevealBeat.dim) * (1 - driver.at(RevealBeat.drop)),
      child: ColoredBox(
        color: context.skin.parts.boardShade.withValues(alpha: shade),
      ),
    ),
  );
}

/// A hanged card's twin, drawn over the board while it is up: it leaves its
/// slot, grows to the middle of the window ([EndReveal.big]) turning face up
/// on the way, takes the stamp, holds, and goes back down to its slot, where
/// the card itself takes over.
class RevealHanged extends StatelessWidget {
  const RevealHanged({
    super.key,
    required this.driver,
    required this.card,
    required this.face,
  });

  final EndRevealDriver driver;
  final EndCard card;
  final Widget face;

  /// How large the stamp comes down from, a share of its size.
  static const stampFrom = 2.4;

  /// How far up the card is: 0 in its slot, 1 big in the middle.
  double _up() =>
      Motion.curve.transform(driver.at(RevealBeat.lift, card: card.id)) *
      (1 - Motion.curve.transform(driver.at(RevealBeat.drop)));

  /// How far the stamp has lifted off as the card goes back (it is gone in
  /// the drop's first [Motion.quick]).
  double _off() =>
      (driver.at(RevealBeat.drop) *
              Motion.settle.inMicroseconds /
              Motion.quick.inMicroseconds)
          .clamp(0.0, 1.0);

  @override
  Widget build(BuildContext context) {
    final c = card;
    // Where the stamp lies: across the portrait's lower third, where a face
    // has the least ([DeathMark.stampRect]), at the size that hides no more
    // than [DeathMark.maxCover] of it.
    final portrait = c.portrait.shift(-c.rect.topLeft);
    final at = DeathMark.stampRect(portrait, Size.zero).center;
    return IgnorePointer(
      child: revealPaint(
        driver,
        opacity: () => 1 - handOver(driver),
        transform: (size) {
          final big = driver.reveal?.big[c.id];
          if (big == null) return null;
          final up = _up();
          final scale = lerpDouble(1, big.width / c.rect.width, up)!;
          return Matrix4.translationValues(
            (big.center.dx - c.rect.center.dx) * up,
            (big.center.dy - c.rect.center.dy) * up,
            0,
          )..multiply(about(size.center(Offset.zero), _scale(scale)));
        },
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned.fill(child: revealCardTurn(driver, c, face)),
            Positioned(
              left: at.dx,
              top: at.dy,
              child: revealPaint(
                driver,
                // The stamp slams down, and lifts off as the card goes back.
                opacity: () {
                  final s = driver.at(RevealBeat.stamp);
                  return s <= 0 ? 0 : math.min(1.0, s * 2) * (1 - _off());
                },
                transform: (size) {
                  final s = driver.at(RevealBeat.stamp);
                  final slam = lerpDouble(
                    stampFrom,
                    1,
                    Motion.land.transform(s),
                  )!;
                  // About its centre, which is this box's corner.
                  return about(Offset.zero, _scale(slam * (1 + _off() * 0.3)));
                },
                child: const FractionalTranslation(
                  translation: Offset(-0.5, -0.5),
                  child: InkStamp(label: EndCopy.hangedStamp),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The banner unrolling from its middle out, its sentence whole from the
/// start (only more of it is seen).
Widget revealUnroll(EndRevealDriver driver, Widget banner) => RepaintBoundary(
  child: ClipRect(
    clipper: _FromMiddle(driver),
    child: RepaintBoundary(child: banner),
  ),
);

class _FromMiddle extends CustomClipper<Rect> {
  _FromMiddle(this.driver) : super(reclip: driver.clock);

  final EndRevealDriver driver;

  @override
  Rect getClip(Size size) => Rect.fromCenter(
    center: size.center(Offset.zero),
    width: size.width * Motion.curve.transform(driver.at(RevealBeat.banner)),
    height: size.height * 2,
  );

  @override
  bool shouldReclip(_FromMiddle old) => driver != old.driver;
}

/// A strand's twine drawn down from its pin as its tags arrive: [top] to
/// [bottom], in the layer's own coordinates.
Widget revealDrawnDown(
  EndRevealDriver driver, {
  required double top,
  required double bottom,
  required Widget child,
}) => RepaintBoundary(
  child: ClipRect(
    clipper: _DrawnDown(driver, top: top, bottom: bottom),
    child: RepaintBoundary(child: child),
  ),
);

class _DrawnDown extends CustomClipper<Rect> {
  _DrawnDown(this.driver, {required this.top, required this.bottom})
    : super(reclip: driver.clock);

  final EndRevealDriver driver;
  final double top;
  final double bottom;

  @override
  Rect getClip(Size size) => Rect.fromLTRB(
    -size.width,
    -size.height,
    size.width * 2,
    top + (bottom - top) * Motion.curve.transform(driver.at(RevealBeat.tags)),
  );

  @override
  bool shouldReclip(_DrawnDown old) =>
      driver != old.driver || top != old.top || bottom != old.bottom;
}

/// The lantern's pool coming on: the board's light without its pools, and
/// with them, crossfaded.
Widget revealPool(EndRevealDriver driver, Widget dark, Widget lit) => Stack(
  children: [
    Positioned.fill(child: revealFade(driver, RevealBeat.pool, lit)),
    Positioned.fill(
      child: revealPaint(
        driver,
        opacity: () => 1 - driver.at(RevealBeat.pool),
        child: dark,
      ),
    ),
  ],
);

/// A tag coming down its twine from the pin, [fall] above where it hangs.
Widget revealArriving(EndRevealDriver driver, double fall, Widget tag) =>
    revealPaint(
      driver,
      opacity: () => math.min(1, driver.at(RevealBeat.tags) * 3),
      transform: (size) => Matrix4.translationValues(
        0,
        -fall * (1 - Motion.land.transform(driver.at(RevealBeat.tags))),
        0,
      ),
      child: tag,
    );

/// A middle card turning with the last row.
Widget revealMiddleTurn(
  EndRevealDriver driver, {
  required Size size,
  required double portraitWidth,
  required double angle,
  required Widget face,
}) => RevealTurn(
  driver: driver,
  value: () => driver.at(RevealBeat.middle),
  back: BoardCardBack(
    size: size,
    portraitWidth: portraitWidth,
    rect: Offset.zero & size,
    angle: angle,
  ),
  face: face,
);
