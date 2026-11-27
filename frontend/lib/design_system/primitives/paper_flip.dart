import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../feel/press.dart';
import '../layout/space.dart';
import '../skin/dress.dart';
import '../skin/skin.dart';

/// A card turning over like a piece of cut paper: the one turn-over the
/// design system has (`docs/design/feel.md`, "Your card"). [back] is what
/// lies face down and sets the size; [face] is what shows when [turned].
///
/// - The paper is lifted by a thumb: it rises a little ([lift], [grow]) and
///   its shadow falls further away ([drop]) as it goes through the edge, and
///   it comes down on the other side with a small settle ([settle]: it
///   swings a few degrees past flat and back, inside the same turn).
/// - The face is turned the right way round (never mirrored) and is built
///   offstage from the moment it is [turned], and shown only once past the
///   edge. Offstage it is not painted and not in the semantics tree, so a
///   hidden secret is not visible to anyone.
/// - It never makes anything wait. Turning to the face takes [turn], back
///   [turnBack]; a turn let go of half way goes back from where it is, in
///   proportion to what is left of it; taken again, goes on from there.
///   Under reduce motion it is a cut to the end state.
/// - [pressed] (a finger on the card, before it is a hold) dips the back a
///   little ([dip]) and gives it back as the turn begins; or [press], a
///   finger's own press (`Pressable`), which dips it in the frame the finger
///   lands. No dip under reduce motion.
/// - [onLanded] is told each time the face lands (the end of the turn to it,
///   a cut included): the card's one vibration goes here.
///
/// It lays out once: a turn only changes the matrix its two sides are drawn
/// with, each kept in its own repaint boundary, so a frame of the turn is
/// two transforms and no layout.
class PaperFlip extends StatefulWidget {
  const PaperFlip({
    super.key,
    required this.turned,
    required this.back,
    required this.face,
    this.pressed = false,
    this.press,
    this.onLanded,
  });

  final bool turned;
  final bool pressed;
  final Animation<double>? press;
  final Widget back;

  /// The face, at the back's size. Called from the moment the card is
  /// [turned] (built offstage), and again each time the card is rebuilt.
  final WidgetBuilder face;

  final VoidCallback? onLanded;

  /// How far the paper rises at the edge, and how much larger it is there.
  static const lift = Space.sm;
  static const grow = 0.03;

  /// How much further its shadow falls at the edge, beyond the lift.
  static const drop = Space.xs;

  /// How dark the shadow block is while the card is off the table on a
  /// dressed screen (a plain one's is solid).
  static const shadowAlpha = 0.55;

  /// How far a finger presses the back down (a share of its size).
  static const dip = 0.02;

  /// How far past flat the paper swings as it lands, a share of the turn.
  static const settle = 0.03;

  /// Perspective: the near side of the turning card is larger.
  static const perspective = 0.001;

  /// To the face, and back to the cover (the same as the fade it replaces:
  /// letting go hides it as fast as before).
  static const turn = Motion.quick;
  static const turnBack = Motion.press;

  /// A thumb sets the paper going quickly and it eases down onto the table,
  /// settling a few degrees past flat.
  static const landing = Cubic(0.3, 0.55, 0.35, 1 + 4 * settle);

  /// Whether the card is face up at [value] of the turn (0 face down, 1 up).
  static bool isFaceUp(double value) => value >= 0.5;

  @override
  State<PaperFlip> createState() => _PaperFlipState();
}

class _PaperFlipState extends State<PaperFlip> with TickerProviderStateMixin {
  /// How far the card has turned: 0 face down, 1 face up; a little over 1
  /// while it settles.
  late final AnimationController _turn = AnimationController.unbounded(
    vsync: this,
    value: widget.turned ? 1 : 0,
  );

  /// A finger's dip: 0 up, 1 pressed down.
  late final AnimationController _press = AnimationController(
    vsync: this,
    duration: Motion.press,
  );

  Widget? _face;
  var _still = false;

  @override
  void initState() {
    super.initState();
    _turn.addStatusListener(_landed);
    _turn.addListener(_dropFace);
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _still = MediaQuery.disableAnimationsOf(context);
  }

  @override
  void didUpdateWidget(PaperFlip old) {
    super.didUpdateWidget(old);
    if (widget.turned != old.turned) _go(widget.turned);
    if (widget.pressed != old.pressed) _dip(widget.pressed);
  }

  @override
  void dispose() {
    _turn.dispose();
    _press.dispose();
    super.dispose();
  }

  void _go(bool turned) {
    final at = _turn.value;
    if (_still) {
      _turn.value = turned ? 1 : 0;
      if (turned) widget.onLanded?.call();
      return;
    }
    if (turned) {
      if (at >= 1) {
        _turn.stop();
        return;
      }
      _turn.animateTo(
        1,
        duration: PaperFlip.turn * (1 - math.max(0.0, at)),
        curve: PaperFlip.landing,
      );
    } else {
      if (at <= 0) {
        _turn.stop();
        return;
      }
      _turn.animateTo(
        0,
        duration: PaperFlip.turnBack * math.min(1.0, at),
        curve: Motion.curve,
      );
    }
  }

  void _dip(bool pressed) {
    if (_still) return;
    if (pressed) {
      _press.forward();
    } else {
      _press.reverse();
    }
  }

  void _landed(AnimationStatus status) {
    if (status == AnimationStatus.completed && widget.turned) {
      widget.onLanded?.call();
    }
  }

  /// Once the card is back past the edge nothing of the face is kept.
  void _dropFace() {
    if (_face != null && !widget.turned && !PaperFlip.isFaceUp(_turn.value)) {
      setState(() => _face = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    // The face is made when it is wanted, never before, and stays the same
    // widget through the turn so a frame of it re-lays-out nothing.
    _face = widget.turned || PaperFlip.isFaceUp(_turn.value)
        ? RepaintBoundary(child: widget.face(context))
        : null;
    final press = widget.press;
    // A finger's own press dips the back by paint alone (nothing rebuilt).
    final Widget back = press == null
        ? RepaintBoundary(child: widget.back)
        : PressSink(
            press: press,
            shrink: PaperFlip.dip,
            child: RepaintBoundary(child: widget.back),
          );
    final face = _face;
    final skin = context.skin;
    final elevation = context.ground.elevation.heroSlab;
    final shadow = elevation.layers.isEmpty ? null : elevation.layers.last;
    final radius = BorderRadius.circular(skin.shape.radius);
    return LayoutBuilder(
      builder: (context, _) => AnimatedBuilder(
        animation: Listenable.merge([_turn, _press]),
        builder: (context, _) {
          final value = _turn.value;
          final angle = value * math.pi;
          final up = PaperFlip.isFaceUp(value);
          // 0 flat, 1 edge on: the lift, the growth and the fall of the
          // shadow all follow it.
          final edgeOn = math.sin(angle.clamp(0.0, math.pi));
          final dip = _press.value * (1 - (value * 2).clamp(0.0, 1.0));
          final scale = 1 + PaperFlip.grow * edgeOn - PaperFlip.dip * dip;
          Matrix4 matrix(double dy, double scale, double turn) =>
              Matrix4.translationValues(0, dy, 0)
                ..setEntry(3, 2, PaperFlip.perspective)
                ..scaleByDouble(scale, scale, scale, 1)
                ..rotateY(turn);
          final lifted = -PaperFlip.lift * edgeOn;
          return Stack(
            clipBehavior: Clip.none,
            children: [
              // Its shadow on the table: it stays down while the card rises,
              // so the two part.
              Positioned.fill(
                child: shadow == null || edgeOn == 0
                    ? const SizedBox.shrink()
                    : Transform(
                        alignment: Alignment.center,
                        transform: matrix(
                          shadow.offset.dy + PaperFlip.drop * edgeOn,
                          1,
                          angle,
                        ),
                        child: DecoratedBox(
                          decoration: BoxDecoration(
                            color: context.dress.isPaper
                                ? shadow.color.withValues(
                                    alpha: PaperFlip.shadowAlpha,
                                  )
                                : shadow.color,
                            borderRadius: radius,
                          ),
                        ),
                      ),
              ),
              // The back sets the size, seen or not (kept laid out, not drawn).
              Visibility(
                visible: !up,
                maintainState: true,
                maintainAnimation: true,
                maintainSize: true,
                child: Transform(
                  alignment: Alignment.center,
                  transform: matrix(lifted, scale, angle),
                  child: back,
                ),
              ),
              Positioned.fill(
                child: face == null
                    ? const SizedBox.shrink()
                    : Offstage(
                        offstage: !up,
                        child: Transform(
                          alignment: Alignment.center,
                          transform: matrix(lifted, scale, angle - math.pi),
                          child: face,
                        ),
                      ),
              ),
            ],
          );
        },
      ),
    );
  }
}
