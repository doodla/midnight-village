import 'dart:math' as math;

import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';

import '../layout/space.dart';

/// Draws a part's own answer to a finger: [press] runs from 0 (at rest) to 1
/// (all the way down). Hand it to a paint-only layer ([PressSink], a
/// `FadeTransition`, a `CustomPainter`'s `repaint:`), never to a rebuild of
/// [child]: the builder runs when the part is built, not on every frame.
typedef PressBuilder =
    Widget Function(
      BuildContext context,
      Animation<double> press,
      Widget? child,
    );

/// The one press of the kit (`docs/design/feel.md`, principle 1): the frame
/// a finger lands, the part shows it is down; it comes back up on the lift,
/// on a cancel, and when the finger slides off.
///
/// It watches the pointer only (a [Listener]): it never takes the tap, never
/// joins the gesture arena and never delays an event. What a tap, a long
/// press or a hold commits stays with the detector inside it (an `InkWell`,
/// a `GestureDetector`, `HoldToReveal`), which fires exactly when it would
/// without it.
///
/// Down: the press is set in the pointer-down handler itself, one frame of
/// [Motion.press] already in, so the very next frame draws it, and goes the
/// rest of the way on [Motion.curve]. Up: back to rest over [Motion.quick] on
/// [Motion.land], so the paper springs a little past rest (under a tenth: the
/// value dips just under 0) and settles. With reduce motion it is a cut: 1
/// on the frame the finger lands, 0 on the lift, nothing in between, and the
/// part shows the state with no travel ([PressSink] moves nothing then).
///
/// A part that cannot act yet (a locked button) keeps [enabled]: its press
/// still answers and its words say what is missing. Only a part that must
/// not move at all (a dimmed vote row) turns [enabled] off.
///
/// It is its own [RepaintBoundary]: a press repaints the pressed part only.
class Pressable extends StatefulWidget {
  const Pressable({
    super.key,
    required this.builder,
    this.child,
    this.enabled = true,
    this.holds = false,
  });

  /// The part drawn with its press; [child] is passed through untouched.
  final PressBuilder builder;
  final Widget? child;

  /// Whether a finger presses it at all.
  final bool enabled;

  /// A hold (`HoldToReveal`): the press lasts until the finger lifts or is
  /// cancelled, wherever it wanders. A tap (the default) also comes back up
  /// when the finger travels past the tap's own slop (`computeHitSlop`) from
  /// where it landed, measured on the screen as the tap inside measures it:
  /// the point where that tap is cancelled and a scroll may take over. A
  /// finger just past the part's edge but within the slop still taps, so it
  /// stays down.
  final bool holds;

  @override
  State<Pressable> createState() => _PressableState();
}

class _PressableState extends State<Pressable>
    with SingleTickerProviderStateMixin {
  // Unbounded: the settle dips just under rest.
  late final AnimationController _press = AnimationController.unbounded(
    vsync: this,
  );

  /// The finger that pressed (the first one down; others are ignored), and
  /// where on the screen it landed.
  int? _pointer;
  Offset _from = Offset.zero;

  // Read when they change, never in a pointer handler.
  var _reduced = false;
  DeviceGestureSettings? _gestures;
  var _rate = 0.0;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _reduced = MediaQuery.maybeDisableAnimationsOf(context) ?? false;
    _gestures = MediaQuery.maybeGestureSettingsOf(context);
    _rate = View.maybeOf(context)?.display.refreshRate ?? 0;
  }

  /// The share of [Motion.press] one frame of this display takes: where the
  /// press stands on the first frame drawn after the finger lands. A display
  /// that does not say its rate gets the whole press at once.
  double get _firstFrame {
    final rate = _rate;
    if (rate <= 0) return 1;
    final frame = Duration.microsecondsPerSecond / rate;
    return math.min(1, frame / Motion.press.inMicroseconds);
  }

  void _down(PointerDownEvent event) {
    if (!widget.enabled || _pointer != null) return;
    if (event.buttons & kPrimaryButton == 0) return;
    _pointer = event.pointer;
    _from = event.position;
    if (_reduced) {
      _press.value = 1;
      return;
    }
    final from = _press.value;
    final head = _firstFrame;
    final start = Motion.curve.transform(head);
    _press.value = from + (1 - from) * start;
    if (head >= 1) return;
    _press.animateTo(
      1,
      duration: Motion.press * (1 - head),
      curve: _Rest(Motion.curve, head, start),
    );
  }

  void _move(PointerMoveEvent event) {
    if (event.pointer != _pointer || widget.holds) return;
    // The tap's own slop for this kind of pointer, on the screen: past it the
    // tap inside is cancelled, so the press comes up with it.
    if ((event.position - _from).distance >
        computeHitSlop(event.kind, _gestures)) {
      _release();
    }
  }

  void _end(PointerEvent event) {
    if (event.pointer == _pointer) _release();
  }

  void _release() {
    _pointer = null;
    if (_reduced) {
      _press.value = 0;
      return;
    }
    _press.animateTo(0, duration: Motion.quick, curve: Motion.land);
  }

  @override
  void didUpdateWidget(Pressable oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!widget.enabled && _pointer != null) _release();
  }

  @override
  void dispose() {
    _press.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: Listener(
      onPointerDown: _down,
      onPointerMove: _move,
      onPointerUp: _end,
      onPointerCancel: _end,
      child: widget.builder(context, _press.view, widget.child),
    ),
  );
}

/// The rest of [curve] after its first [head] of time (where it stood at
/// [start]), stretched to run 0 to 1: the press after its first frame.
class _Rest extends Curve {
  const _Rest(this.curve, this.head, this.start);

  final Curve curve;
  final double head;
  final double start;

  @override
  double transformInternal(double t) =>
      (curve.transform(head + (1 - head) * t) - start) / (1 - start);
}

/// The common paper answer to a press, drawn by paint alone: the part sinks
/// by [by] (into its shadow) and shrinks by [shrink] of its size, both times
/// the press. Nothing below it is rebuilt or laid out again, and its hit
/// area and layout stay where they rest. With reduce motion nothing moves:
/// pair it with a colour change (a tint, a `FadeTransition`) the part draws
/// itself.
class PressSink extends SingleChildRenderObjectWidget {
  const PressSink({
    super.key,
    required this.press,
    this.by = Offset.zero,
    this.shrink = 0,
    super.child,
  });

  final Animation<double> press;
  final Offset by;
  final double shrink;

  /// The kit's small dip, for a part with no shadow to sink into (an
  /// outlined button, a glyph): down by a hairline (`feel.md`, "Dip 2 px").
  static const dip = Offset(0, Space.hairline);

  bool _still(BuildContext context) =>
      MediaQuery.maybeDisableAnimationsOf(context) ?? false;

  @override
  RenderObject createRenderObject(BuildContext context) => RenderPressSink(
    press: press,
    by: by,
    shrink: shrink,
    still: _still(context),
  );

  @override
  void updateRenderObject(BuildContext context, RenderPressSink renderObject) {
    renderObject
      ..press = press
      ..by = by
      ..shrink = shrink
      ..still = _still(context);
  }
}

/// [PressSink]'s render object: it repaints when the press moves, and only
/// then; it never lays out again.
class RenderPressSink extends RenderProxyBox {
  RenderPressSink({
    required Animation<double> press,
    required Offset by,
    required double shrink,
    required bool still,
  }) : _press = press,
       _by = by,
       _shrink = shrink,
       _still = still;

  Animation<double> _press;
  set press(Animation<double> value) {
    if (value == _press) return;
    if (attached) _press.removeListener(markNeedsPaint);
    _press = value;
    if (attached) _press.addListener(markNeedsPaint);
    markNeedsPaint();
  }

  Offset _by;
  set by(Offset value) {
    if (value == _by) return;
    _by = value;
    markNeedsPaint();
  }

  double _shrink;
  set shrink(double value) {
    if (value == _shrink) return;
    _shrink = value;
    markNeedsPaint();
  }

  bool _still;
  set still(bool value) {
    if (value == _still) return;
    _still = value;
    markNeedsPaint();
  }

  final _layer = LayerHandle<TransformLayer>();

  @override
  void attach(PipelineOwner owner) {
    super.attach(owner);
    _press.addListener(markNeedsPaint);
  }

  @override
  void detach() {
    _press.removeListener(markNeedsPaint);
    super.detach();
  }

  @override
  void dispose() {
    _layer.layer = null;
    super.dispose();
  }

  /// Where the child is drawn now: null at rest (and with reduce motion).
  Matrix4? get _transform {
    final press = _still ? 0.0 : _press.value;
    if (press == 0 || (_by == Offset.zero && _shrink == 0)) return null;
    final centre = size.center(Offset.zero);
    final scale = 1 - _shrink * press;
    final moved = centre + _by * press;
    return Matrix4.translationValues(moved.dx, moved.dy, 0)
      ..multiply(Matrix4.diagonal3Values(scale, scale, 1))
      ..multiply(Matrix4.translationValues(-centre.dx, -centre.dy, 0));
  }

  /// The child is placed where it is drawn (an overlay that follows it, a
  /// test that reads where it is); it is still hit where it rests.
  @override
  void applyPaintTransform(RenderBox child, Matrix4 transform) {
    if (_transform case final moved?) transform.multiply(moved);
  }

  @override
  void paint(PaintingContext context, Offset offset) {
    final child = this.child;
    if (child == null) return;
    final transform = _transform;
    if (transform == null) {
      _layer.layer = null;
      context.paintChild(child, offset);
      return;
    }
    _layer.layer = context.pushTransform(
      needsCompositing,
      offset,
      transform,
      (context, offset) => context.paintChild(child, offset),
      oldLayer: _layer.layer,
    );
  }
}
