import 'package:flutter/material.dart';

import '../layout/space.dart';
import '../skin/dress.dart';
import '../skin/dress_style.dart';
import '../skin/ground.dart';
import '../skin/skin.dart';
import 'cut_paper.dart';
import 'drawn.dart';
import 'paper_mark.dart';
import 'paper_piece.dart';
import 'primary_button.dart';

/// The four corners of a viewfinder, drawn as [inset] (a fraction of the
/// side) in from each edge, each an L of [arm] (a fraction of the side).
class ViewfinderBrackets extends CustomPainter {
  const ViewfinderBrackets({
    required this.color,
    required this.stroke,
    this.inset = 0,
    this.arm = 0.22,
  });

  final Color color;
  final double stroke;
  final double inset;
  final double arm;

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;
    final left = size.width * inset;
    final top = size.height * inset;
    final right = size.width - left;
    final bottom = size.height - top;
    final dx = size.width * arm;
    final dy = size.height * arm;
    canvas
      ..drawPath(
        Path()
          ..moveTo(left, top + dy)
          ..lineTo(left, top)
          ..lineTo(left + dx, top),
        paint,
      )
      ..drawPath(
        Path()
          ..moveTo(right - dx, top)
          ..lineTo(right, top)
          ..lineTo(right, top + dy),
        paint,
      )
      ..drawPath(
        Path()
          ..moveTo(right, bottom - dy)
          ..lineTo(right, bottom)
          ..lineTo(right - dx, bottom),
        paint,
      )
      ..drawPath(
        Path()
          ..moveTo(left + dx, bottom)
          ..lineTo(left, bottom)
          ..lineTo(left, bottom - dy),
        paint,
      );
  }

  @override
  bool shouldRepaint(ViewfinderBrackets old) =>
      color != old.color ||
      stroke != old.stroke ||
      inset != old.inset ||
      arm != old.arm;
}

/// 01's scan glyph: the viewfinder's own corners round a small code's three
/// finder squares and a dot, so the button and the screen it opens are one
/// picture. Drawn, because the skin's art set has no glyph for it.
class ScanGlyph extends StatelessWidget {
  const ScanGlyph({super.key, required this.color, this.size = 28});

  final Color color;
  final double size;

  @override
  Widget build(BuildContext context) => Drawn(
    DrawnKind.scanner,
    child: CustomPaint(
      size: Size.square(size),
      painter: _ScanGlyphPainter(
        color,
        stroke: context.skin.shape.stroke + 0.5,
      ),
    ),
  );
}

class _ScanGlyphPainter extends CustomPainter {
  const _ScanGlyphPainter(this.color, {required this.stroke});

  final Color color;
  final double stroke;

  @override
  void paint(Canvas canvas, Size size) {
    ViewfinderBrackets(
      color: color,
      stroke: stroke,
      arm: 0.3,
    ).paint(canvas, size);
    final fill = Paint()..color = color;
    final side = size.width * 0.17;
    final gap = size.width * 0.27;
    // Two finder squares across the top and one down the left, as a code
    // has; and the dot where its fourth corner has none.
    for (final (x, y) in [(0.0, 0.0), (1.0, 0.0), (0.0, 1.0)]) {
      canvas.drawRRect(
        RRect.fromRectAndRadius(
          Rect.fromLTWH(
            gap + x * (size.width - 2 * gap - side),
            gap + y * (size.height - 2 * gap - side),
            side,
            side,
          ),
          Radius.circular(side * 0.25),
        ),
        fill,
      );
    }
    canvas.drawCircle(
      Offset(size.width - gap - side / 2, size.height - gap - side / 2),
      side * 0.32,
      fill,
    );
  }

  @override
  bool shouldRepaint(_ScanGlyphPainter old) =>
      color != old.color || stroke != old.stroke;
}

/// A square action on the ground that is a glyph and no words: outlined like
/// [SecondaryButton], the same height as the button of its [size] beside it,
/// pressed to a hairline fill. [semanticLabel] is what it is to a screen
/// reader. [lit] shows a switch that is on (lift and outline, never amber).
class GlyphButton extends StatefulWidget {
  const GlyphButton({
    super.key,
    required this.glyph,
    required this.semanticLabel,
    required this.onPressed,
    this.size = ButtonSize.large,
    this.lit = false,
  });

  /// Draws the glyph in the ink it is given.
  final Widget Function(Color ink) glyph;
  final String semanticLabel;
  final VoidCallback? onPressed;
  final ButtonSize size;
  final bool lit;

  @override
  State<GlyphButton> createState() => _GlyphButtonState();
}

class _GlyphButtonState extends State<GlyphButton> {
  var _pressed = false;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final ground = context.ground;
    final enabled = widget.onPressed != null;
    final radius = BorderRadius.circular(skin.shape.radius);
    final side = widget.size.secondaryHeight;
    final ink = enabled ? ground.text : ground.faintText;
    return Semantics(
      button: true,
      enabled: enabled,
      selected: widget.lit,
      label: widget.semanticLabel,
      onTap: widget.onPressed,
      excludeSemantics: true,
      child: context.dress.isPaper
          ? _scrap(context, side, enabled)
          : AnimatedContainer(
              duration: Motion.press,
              curve: Motion.curve,
              width: side,
              height: side,
              decoration: BoxDecoration(
                color: _pressed || widget.lit
                    ? ground.hairline
                    : Colors.transparent,
                borderRadius: radius,
                border: Border.all(
                  color: enabled ? ground.outline : ground.hairline,
                  width: skin.shape.stroke,
                ),
              ),
              child: Material(
                type: MaterialType.transparency,
                child: InkWell(
                  onTap: widget.onPressed,
                  onHighlightChanged: (value) =>
                      setState(() => _pressed = value),
                  highlightColor: Colors.transparent,
                  borderRadius: radius,
                  child: Center(child: widget.glyph(ink)),
                ),
              ),
            ),
    );
  }

  /// Dressed up: a bone scrap with the glyph on it; a switch that is on is
  /// lifted and wears the paper mark (never a ring).
  Widget _scrap(BuildContext context, double side, bool enabled) {
    final ink = PaperPiece.inkOf(context, PaperPart.scrap, locked: !enabled);
    return PaperMarkCorner(
      shown: widget.lit,
      child: SizedBox.square(
        dimension: side,
        child: PaperPiece(
          part: PaperPart.scrap,
          id: widget.semanticLabel,
          pressed: _pressed,
          lifted: widget.lit,
          enabled: enabled,
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: widget.onPressed,
              onHighlightChanged: (value) => setState(() => _pressed = value),
              highlightColor: Colors.transparent,
              focusColor: Colors.transparent,
              hoverColor: Colors.transparent,
              splashColor: Colors.transparent,
              borderRadius: BorderRadius.circular(context.skin.shape.radius),
              child: Center(child: widget.glyph(ink)),
            ),
          ),
        ),
      ),
    );
  }
}

/// The scanner's window: a piece of paper raised off the ground, the
/// camera's view (or what stands in for it) set into it, and the viewfinder's
/// corners over that. [found] draws the corners in close round the code, so
/// "that is the one" is something the window does, not a sentence.
class Viewfinder extends StatelessWidget {
  const Viewfinder({
    super.key,
    required this.child,
    this.found = false,
    this.maxSide = Sizes.viewfinderLargest,
  });

  final Widget child;
  final bool found;
  final double maxSide;

  /// The corners' distance from the window's edge, looking and found.
  static const _lookingInset = 0.12;
  static const _foundInset = 0.04;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final ground = context.ground;
    final outer = BorderRadius.circular(skin.shape.radius);
    final inner = BorderRadius.circular(skin.shape.radius * 0.6);
    final ink = context.skin.ground(GroundKind.paper).text;
    return LayoutBuilder(
      builder: (context, room) {
        var side = room.maxWidth < maxSide ? room.maxWidth : maxSide;
        if (room.hasBoundedHeight && room.maxHeight < side) {
          side = room.maxHeight;
        }
        return SizedBox.square(
          dimension: side,
          child: DecoratedBox(
            decoration: cutPaper(
              context,
              fill: ground.paper,
              radius: outer,
              elevation: ground.elevation.slab,
            ),
            child: Padding(
              padding: const EdgeInsets.all(Space.md),
              child: ClipRRect(
                borderRadius: inner,
                child: Stack(
                  fit: StackFit.expand,
                  children: [
                    ColoredBox(
                      color: found ? ground.paper : ground.ground,
                      child: child,
                    ),
                    IgnorePointer(
                      // Looking: the corners stand off, in the paper's
                      // cream over the picture. Found: they close in and
                      // turn to ink, round the code on its paper.
                      child: TweenAnimationBuilder<double>(
                        tween: Tween(end: found ? 1.0 : 0.0),
                        duration: Motion.within(context, Motion.quick),
                        curve: Motion.curve,
                        builder: (context, t, _) => Drawn(
                          DrawnKind.scanner,
                          child: CustomPaint(
                            painter: ViewfinderBrackets(
                              color: Color.lerp(ground.paper, ink, t)!,
                              stroke: skin.shape.stroke + 1.5,
                              inset:
                                  _lookingInset +
                                  (_foundInset - _lookingInset) * t,
                            ),
                          ),
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}

/// A closed window, cut from paper: a frame, two shutter leaves with slats and
/// a latch across them. It stands where the camera would be when the camera
/// is off (01b), so "no camera" is a shuttered window of the village, not a
/// stock icon. Drawn in code from the ground's own paper, edge and shadow.
class ShutteredWindow extends StatelessWidget {
  const ShutteredWindow({super.key});

  static const _slats = 6;
  static const _width = 0.5;
  static const _aspect = 1.15;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final ground = context.ground;
    final radius = BorderRadius.circular(skin.shape.radius * 0.5);
    final stroke = skin.shape.stroke;
    Widget leaf() => Expanded(
      child: DecoratedBox(
        decoration: cutPaper(
          context,
          fill: ground.paper,
          radius: radius,
          elevation: ground.elevation.card,
        ),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: Space.sm),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              for (var i = 0; i < _slats; i++)
                Container(height: stroke, color: ground.paperEdge),
            ],
          ),
        ),
      ),
    );
    return LayoutBuilder(
      builder: (context, room) {
        final width = room.maxWidth * _width;
        return Center(
          child: SizedBox(
            width: width,
            height: width * _aspect,
            child: DecoratedBox(
              // Dressed up the closed window is a recess of paper, not an
              // outline.
              decoration: context.dress.isPaper
                  ? BoxDecoration(borderRadius: radius, color: ground.panel)
                  : BoxDecoration(
                      borderRadius: radius,
                      border: Border.all(
                        color: ground.outline,
                        width: stroke * 2,
                      ),
                    ),
              child: Padding(
                padding: const EdgeInsets.all(Space.xs),
                child: Stack(
                  alignment: Alignment.center,
                  children: [
                    Row(spacing: Space.xxs, children: [leaf(), leaf()]),
                    // The latch, across the two leaves.
                    Container(
                      width: width * 0.3,
                      height: Space.xs,
                      decoration: BoxDecoration(
                        color: ground.outline,
                        borderRadius: BorderRadius.circular(Space.xxs),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
