import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../../../../design_system/layout/space.dart';
import '../../../../design_system/primitives/board_pieces.dart';
import '../../../../design_system/primitives/paper_flip.dart';
import '../../domain/end_board.dart';
import '../../domain/end_board_metrics.dart';
import '../../domain/end_reveal.dart';

export 'end_reveal_moment.dart';

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
// inside layout builders.) Nothing is drawn smaller than it is: a back grows
// into its face as it turns, and the dead and the winners only ever grow.

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

  /// Whether the dead card [id] is out of its slot now.
  bool isUp(int id) => reveal?.isUp(id, now) ?? false;
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

  /// How much of the child is seen now (0: it is not painted at all).
  double get seen => (opacity?.call() ?? 1).clamp(0.0, 1.0);

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

  // The child is drawn through the transform: whatever asks where a piece is
  // on the screen, or how large its words are drawn (the reading floor's
  // guard), is told the truth.
  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    final m = this.transform?.call(size);
    if (m != null) transform.multiply(m);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child == null) return;
    final o = seen;
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

Matrix4 scaled(double s) => Matrix4.diagonal3Values(s, s, 1);

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
/// landing) without a controller of its own, and with no vibration. The face
/// fills the box; the back lies at [backAt] in it (every back of a board has
/// one size) and grows to the face's height as it comes edge on, so the card
/// changes size where nobody sees it and nothing is drawn smaller than it is.
class RevealTurn extends StatelessWidget {
  const RevealTurn({
    super.key,
    required this.driver,
    required this.value,
    required this.back,
    required this.backAt,
    required this.face,
  });

  final EndRevealDriver driver;
  final double Function() value;
  final Widget back;
  final Rect backAt;
  final Widget face;

  double _v() {
    final t = value();
    return t <= 0
        ? 0.0
        : t >= 1
        ? 1.0
        : PaperFlip.landing.transform(t);
  }

  static Matrix4 _matrix(
    Size size,
    double v, {
    required double growth,
    required bool face,
  }) {
    final angle = v * math.pi;
    final edgeOn = math.sin(angle.clamp(0.0, math.pi));
    final scale = (1 + PaperFlip.grow * edgeOn) * growth;
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
      Positioned.fromRect(
        rect: backAt,
        child: revealPaint(
          driver,
          opacity: () => PaperFlip.isFaceUp(_v()) ? 0 : 1,
          transform: (size) {
            final v = _v();
            // The back's height, to the face's by the time it is edge on.
            final to = math.max(1.0, _height / backAt.height);
            final growth = lerpDouble(1, to, math.min(1, v * 2))!;
            return _matrix(size, v, growth: growth, face: false);
          },
          child: back,
        ),
      ),
      Positioned.fill(
        child: revealPaint(
          driver,
          opacity: () => PaperFlip.isFaceUp(_v()) ? 1 : 0,
          transform: (size) => _matrix(size, _v(), growth: 1, face: true),
          child: face,
        ),
      ),
    ],
  );

  /// The face's height: the box's (the back is centred in it).
  double get _height => backAt.center.dy * 2;
}

/// A player's card turning on the clock: its back with the name (one size
/// for every card of the board), then [face].
Widget revealCardTurn(EndRevealDriver driver, EndCard c, Widget face) {
  final reveal = driver.reveal!;
  final back = reveal.backs[c.id]!;
  return RevealTurn(
    driver: driver,
    value: () => driver.at(RevealBeat.turn, card: c.id),
    backAt: back.shift(-c.rect.topLeft),
    back: BoardCardBack(
      name: c.name,
      size: back.size,
      portraitWidth: reveal.backPortrait,
      rect: back,
      angle: backAngleOf(c),
      headerHeight: c.header,
    ),
    face: face,
  );
}

/// How a card's back is tilted: as any card that is not hanged (a hanged
/// card's own tilt is larger, and would say who hangs).
double backAngleOf(EndCard c) => EndMetrics.angleOf(c.id, hanged: false);

/// The card's whole box ([box], in the board's content) in its slot: a dead
/// card's is hidden while its twin is up ([RevealHanged]) and takes over as
/// it lands; with nobody hanged the winners rise where they lie, and settle.
Widget revealCardBox(
  EndRevealDriver driver,
  EndCard c,
  Rect box,
  Widget child,
) {
  final dead = driver.has(RevealBeat.lift, card: c.id);
  final rises = c.won && driver.has(RevealBeat.rise);
  if (!dead && !rises) return child;
  return revealPaint(
    driver,
    opacity: dead ? () => driver.isUp(c.id) ? handOver(driver, c.id) : 1 : null,
    transform: rises
        ? (size) {
            final h = risen(driver);
            if (h == 0) return null;
            return Matrix4.translationValues(0, -RevealMetrics.rise * h, 0)
              ..multiply(
                about(
                  c.rect.center - box.topLeft,
                  scaled(1 + RevealMetrics.riseGrowth * h),
                ),
              );
          }
        : null,
    child: child,
  );
}

/// How far the winners stand risen when nobody is hanged: 0 to 1 and back.
double risen(EndRevealDriver driver) =>
    Motion.curve.transform(driver.at(RevealBeat.rise)) *
    (1 - Motion.curve.transform(driver.at(RevealBeat.lower)));

/// How far a dead card's slot has taken over from its twin: 0 while the twin
/// is up, to 1 over the last of its drop, as it comes into the shadow.
double handOver(EndRevealDriver driver, int card) =>
    ((driver.at(RevealBeat.drop, card: card) - _handOverFrom) /
            (1 - _handOverFrom))
        .clamp(0.0, 1.0);

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
    // The landing's overshoot stops at its own size: a slip's words are
    // never drawn smaller.
    scaled(
      math.max(
        1.0,
        lerpDouble(
          _pinFrom,
          1,
          Motion.land.transform(driver.at(kind, card: card)),
        )!,
      ),
    ),
  ),
  child: child,
);

const _pinFrom = 1.5;

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
}) => SizedBox.fromSize(
  size: size,
  child: RevealTurn(
    driver: driver,
    value: () => driver.at(RevealBeat.middle),
    backAt: Offset.zero & size,
    back: BoardCardBack(
      size: size,
      portraitWidth: portraitWidth,
      rect: Offset.zero & size,
      angle: angle,
    ),
    face: face,
  ),
);
