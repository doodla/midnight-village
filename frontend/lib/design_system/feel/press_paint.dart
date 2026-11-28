import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../layout/space.dart';
import '../primitives/deckle.dart';

/// A part's paper under a finger, drawn by paint alone: [rest] at rest,
/// [down] all the way down, and in between the two blended by the press
/// (`Pressable`'s animation, 0 to 1, a hair under 0 as it settles). The
/// shadow a press tightens is here; the sink itself is a `PressSink`.
///
/// A press repaints this box only: nothing is built or laid out again, and
/// the [child] is painted as it is. A change of [rest] or [down] that is not
/// a finger's (a button going busy, a pick, a gate opening) eases over
/// [duration] on [curve], as an `AnimatedContainer` does. With reduce motion
/// the press is a cut, and the pressed paper still shows (a shadow is not a
/// travel).
class PressDecoration extends ImplicitlyAnimatedWidget {
  const PressDecoration({
    super.key,
    required this.press,
    required this.rest,
    required this.down,
    super.duration = Motion.press,
    super.curve = Motion.curve,
    this.child,
  });

  final Animation<double> press;
  final Decoration rest;
  final Decoration down;
  final Widget? child;

  @override
  AnimatedWidgetBaseState<PressDecoration> createState() =>
      _PressDecorationState();
}

class _PressDecorationState extends AnimatedWidgetBaseState<PressDecoration> {
  DecorationTween? _rest;
  DecorationTween? _down;

  @override
  void forEachTween(TweenVisitor<dynamic> visitor) {
    _rest =
        visitor(
              _rest,
              widget.rest,
              (value) => DecorationTween(begin: value as Decoration),
            )
            as DecorationTween?;
    _down =
        visitor(
              _down,
              widget.down,
              (value) => DecorationTween(begin: value as Decoration),
            )
            as DecorationTween?;
  }

  @override
  Widget build(BuildContext context) {
    final rest = _rest!.evaluate(animation);
    final child = widget.child;
    return _PressBox(
      press: widget.press,
      rest: rest,
      down: _down!.evaluate(animation),
      // Inside its border, as a `Container`'s decoration keeps its child.
      child: child == null || rest.padding == EdgeInsets.zero
          ? child
          : Padding(padding: rest.padding, child: child),
    );
  }
}

class _PressBox extends SingleChildRenderObjectWidget {
  const _PressBox({
    required this.press,
    required this.rest,
    required this.down,
    super.child,
  });

  final Animation<double> press;
  final Decoration rest;
  final Decoration down;

  @override
  RenderPressDecoration createRenderObject(BuildContext context) =>
      RenderPressDecoration(
        press: press,
        rest: rest,
        down: down,
        configuration: createLocalImageConfiguration(context),
      );

  @override
  void updateRenderObject(
    BuildContext context,
    RenderPressDecoration renderObject,
  ) {
    renderObject
      ..press = press
      ..rest = rest
      ..down = down
      ..configuration = createLocalImageConfiguration(context);
  }
}

/// [PressDecoration]'s render object: a `DecoratedBox` whose decoration is
/// the press's blend of two. It repaints when the press moves and never lays
/// out again; it is hit where its resting paper is, as a `DecoratedBox` is.
class RenderPressDecoration extends RenderProxyBox {
  RenderPressDecoration({
    required Animation<double> press,
    required Decoration rest,
    required Decoration down,
    required ImageConfiguration configuration,
  }) : _press = press,
       _rest = rest,
       _down = down,
       _configuration = configuration;

  Animation<double> _press;
  set press(Animation<double> value) {
    if (value == _press) return;
    if (attached) _press.removeListener(markNeedsPaint);
    _press = value;
    if (attached) _press.addListener(markNeedsPaint);
    markNeedsPaint();
  }

  Decoration _rest;
  set rest(Decoration value) {
    if (value == _rest) return;
    _rest = value;
    _drop();
  }

  Decoration _down;
  set down(Decoration value) {
    if (value == _down) return;
    _down = value;
    _drop();
  }

  ImageConfiguration _configuration;
  set configuration(ImageConfiguration value) {
    if (value == _configuration) return;
    _configuration = value;
    markNeedsPaint();
  }

  /// The painters for the two ends (kept), and for the blend last painted.
  BoxPainter? _restPainter;
  BoxPainter? _downPainter;
  BoxPainter? _between;
  double? _betweenAt;

  void _drop() {
    _restPainter?.dispose();
    _downPainter?.dispose();
    _between?.dispose();
    _restPainter = _downPainter = _between = null;
    _betweenAt = null;
    markNeedsPaint();
  }

  BoxPainter _painterAt(double t) {
    if (t == 0 || _rest == _down) {
      return _restPainter ??= _rest.createBoxPainter(markNeedsPaint);
    }
    if (t == 1) return _downPainter ??= _down.createBoxPainter(markNeedsPaint);
    if (_betweenAt != t) {
      _between?.dispose();
      _between = Decoration.lerp(
        _rest,
        _down,
        t,
      )!.createBoxPainter(markNeedsPaint);
      _betweenAt = t;
    }
    return _between!;
  }

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _press.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _press.removeListener(markNeedsPaint);
    _drop();
    super.detach();
  }

  @override
  void dispose() {
    _drop();
    super.dispose();
  }

  /// Whether it draws paper blended toward the pressed one now (a test
  /// reads it).
  @visibleForTesting
  bool get drawsPressed => _press.value > 0 && _rest != _down;

  @override
  bool hitTestSelf(Offset position) => _rest.hitTest(
    size,
    position,
    textDirection: _configuration.textDirection,
  );

  @override
  void paint(PaintingContext context, Offset offset) {
    final t = _press.value;
    void draw() => _painterAt(
      t,
    ).paint(context.canvas, offset, _configuration.copyWith(size: size));
    // On its way between rest and down, a torn edge is moved, not torn.
    if (t == 0 || t == 1) {
      draw();
    } else {
      DeckleBorder.whileMoving(draw);
    }
    super.paint(context, offset);
  }
}
