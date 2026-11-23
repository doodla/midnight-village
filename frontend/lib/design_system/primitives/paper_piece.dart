import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../layout/space.dart';
import '../skin/dress_style.dart';
import '../skin/elevation.dart';
import '../skin/skin.dart';
import '../skin/skin_tilt.dart';
import 'deckled_paper.dart';
import 'tilted_paper.dart';

/// The body of every paper component: flat matte paper with a deckled edge
/// and the paper shadow of the screen's light, in the look the skin's table
/// gives its [part] (`DressStyle`). It draws NO stroke, outline or inset line;
/// its edge is its shape and its shadow. The component's own words and marks
/// are its [child], level on the tilted paper. A paper component builds its
/// body here and nowhere else.
///
/// States, all the paper's, and none of them changes WHAT the piece is (the
/// same part, tear, tilt, grain and shadow; `paper_material_test.dart` holds
/// it): [pressed] sinks it into its shadow, [lifted] (a pick, or keyboard
/// focus) raises it, [locked] (and [enabled] false, a piece nothing can be
/// done with) dims its own paper (the amber to ochre) and its words say why,
/// still at 4.5:1. Only the colour moves.
class PaperPiece extends StatelessWidget {
  const PaperPiece({
    super.key,
    required this.part,
    required this.id,
    required this.child,
    this.pressed = false,
    this.lifted = false,
    this.enabled = true,
    this.locked = false,
    this.duration = Motion.press,
    this.fill,
  });

  final PaperPart part;

  /// Seeds its tear and its tilt (the label): the same on every build.
  final Object id;
  final Widget child;
  final bool pressed;
  final bool lifted;
  final bool enabled;

  /// Dimmed to say "not yet" but still tapped (a gate): it sinks under a
  /// finger as a live piece does.
  final bool locked;
  final Duration duration;

  /// A colour of its own (the danger tag); the part's paper where null.
  final Color? fill;

  /// The paper's colour for [part] on the current ground.
  static Color fillOf(BuildContext context, PaperPart part) {
    final ground = context.ground;
    return switch (DressStyle.paper(part).fill) {
      PaperFill.amber => ground.accent,
      // Bone: the lightest paper the ground has (on a paper ground, where the
      // paper is the ground's own tone, the ground's lighter bone), so a scrap
      // always stands off what it lies on.
      PaperFill.bone =>
        ground.paper.computeLuminance() >= ground.ground.computeLuminance()
            ? ground.paper
            : ground.ground,
      PaperFill.inset => ground.panel,
      PaperFill.ink => ground.text,
    };
  }

  /// [fill] as a locked piece's paper: the same paper with most of its colour
  /// gone and laid toward a pale sand (`PaperParts.lockedSaturation`,
  /// `lockedPale`), so a locked amber button is clearly lighter and greyer than
  /// a live one even when none is beside it. Its words stay at 4.5:1 or more
  /// ([ink]).
  static Color dimmed(BuildContext context, Color fill, Color ink) {
    final parts = context.skin.parts;
    final hsl = HSLColor.fromColor(fill);
    final grey = hsl.withSaturation(hsl.saturation * parts.lockedSaturation);
    // Pale on a dark ground; on a light one (where pale would not stand off
    // it) a mid sand, still without its colour.
    final onLight = context.ground.ground.computeLuminance() > 0.35;
    final target = onLight ? parts.lockedMid : parts.lockedPale;
    var t = parts.lockedPaleMix;
    var out = Color.lerp(grey.toColor(), target, t)!;
    while (t > 0.02 && _contrast(ink, out) < 4.6) {
      t -= 0.02;
      out = Color.lerp(grey.toColor(), target, t)!;
    }
    return out;
  }

  /// A locked piece lies flat and casts less: no backing under it (the paper's
  /// own thickness is what lifts a live amber piece), and its lift and the ink
  /// of its shadow are the skin's share of a live piece's.
  static Elevation flattened(BuildContext context, Elevation live) {
    final parts = context.skin.parts;
    return Elevation([
      for (final layer in live.layers)
        if (!layer.edge)
          layer
              .withOffset(layer.offset * parts.lockedLift)
              .withColor(
                layer.color.withValues(
                  alpha: layer.color.a * parts.lockedShadow,
                ),
              ),
    ]);
  }

  static double _contrast(Color a, Color b) {
    final la = a.computeLuminance();
    final lb = b.computeLuminance();
    return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
  }

  /// The ink of the words on [part]'s paper: the paper's own text on bone
  /// paper (whatever ground it lies on), the ground's elsewhere. A locked
  /// piece keeps it (its paper is dimmed to hold it, [dimmed]).
  static Color inkOf(
    BuildContext context,
    PaperPart part, {
    bool enabled = true,
  }) {
    final ground = context.ground;
    return switch (DressStyle.paper(part).fill) {
      PaperFill.amber => ground.onAccent,
      PaperFill.bone => context.skin.paper.text,
      PaperFill.inset => ground.text,
      PaperFill.ink => ground.ground,
    };
  }

  Elevation _elevation(BuildContext context, PaperRaise raise) {
    final e = context.ground.elevation;
    return switch (raise) {
      PaperRaise.primary => e.primary,
      PaperRaise.card => e.card,
      PaperRaise.badge => e.badge,
      PaperRaise.lifted => e.selected,
      PaperRaise.none => Elevation.none,
    };
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final ground = context.ground;
    final look = DressStyle.paper(part);
    final forced = PaperStateOverride.maybeOf(context);
    final pressed = this.pressed || (forced?.pressed ?? false);
    final lifted = this.lifted || (forced?.focused ?? false);
    final keep = skin.shape.pressKeep;
    final rest = _elevation(context, look.raise);
    final raised = lifted ? ground.elevation.selected : rest;
    final flat = locked || !enabled;
    // A locked piece lies flat and casts less (see [flattened]).
    final shown = flat
        ? flattened(context, pressed && enabled ? rest.pressed(keep) : rest)
        : pressed && enabled
        ? rest.pressed(keep)
        : raised;
    final sink = pressed && enabled
        ? rest.travel(keep)
        : lifted
        ? const Offset(0, -Space.xxs)
        : Offset.zero;
    final base = fill ?? fillOf(context, part);
    final paint = flat ? dimmed(context, base, inkOf(context, part)) : base;
    final parts = skin.parts;
    final (depth, step) = switch (look.edge) {
      PaperEdge.standard => (parts.deckleDepth, parts.deckleStep),
      PaperEdge.plaque => (parts.plaqueDepth, parts.plaqueStep),
      PaperEdge.pinned => (parts.pinnedDepth, parts.pinnedStep),
    };
    final decoration = deckledPaper(
      context,
      fill: paint,
      id: (id, part),
      elevation: shown,
      depth: look.blob
          ? parts.waxDepth
          : look.round
          ? parts.discDepth
          : depth,
      step: look.blob
          ? parts.waxStep
          : look.round
          ? parts.discStep
          : step,
      round: look.round,
      blob: look.blob,
      edgeLine: false,
      side: BorderSide.none,
    );
    return AnimatedContainer(
      duration: duration,
      curve: Motion.curve,
      transform: Matrix4.translationValues(sink.dx, sink.dy, 0),
      child: TiltedPaper(
        angle: look.tilted ? skin.tilt.angle(Tilt.seededRow(id)) : 0,
        duration: duration,
        decoration: decoration,
        child: child,
      ),
    );
  }
}

/// Forces the state of every [PaperPiece] below it (the parts page shows each
/// component pressed and focused at a glance; nothing in the app uses it).
class PaperStateOverride extends InheritedWidget {
  const PaperStateOverride({
    super.key,
    this.pressed = false,
    this.focused = false,
    required super.child,
  });

  final bool pressed;
  final bool focused;

  static PaperStateOverride? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PaperStateOverride>();

  @override
  bool updateShouldNotify(PaperStateOverride old) =>
      pressed != old.pressed || focused != old.focused;
}
