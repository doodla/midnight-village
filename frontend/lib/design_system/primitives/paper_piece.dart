import 'package:flutter/widgets.dart';

import '../feel/press.dart';
import '../layout/space.dart';
import '../skin/dress_style.dart';
import '../skin/elevation.dart';
import '../skin/ground.dart';
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
/// same part, tear, tilt, grain and shadow; `paper_rules_test.dart`, "material", holds
/// it): [pressed] sinks it into its shadow, [lifted] (a pick, or keyboard
/// focus) raises it, [locked] (and [enabled] false, a piece nothing can be
/// done with) becomes the one locked paper (dark indigo, barely lifted, the
/// quietest form of a button: [lockedPaper]) and its words say why, the
/// ground's own text. Only the colour and the lift move.
///
/// Given a [press] (`Pressable`'s, the finger's), the piece sinks into its
/// shadow from the frame the finger lands, by paint alone (`PressSink`, and
/// its paper [PressDecoration]), to the look [pressed] has; a locked or
/// disabled piece sinks too (a touch that is ignored still answers).
/// [pressed] stays for a press that is not a finger's (a busy button).
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
    this.press,
  });

  final PaperPart part;

  /// Seeds its tear and its tilt (the label): the same on every build.
  final Object id;
  final Widget child;
  final bool pressed;
  final Animation<double>? press;
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
      PaperFill.sunk => ground.ground,
      PaperFill.navy => context.skin.night.panel,
    };
  }

  /// A locked piece's paper, whatever it is a piece of: the ground's own
  /// well (`PaperParts.lockedWell`), dark and quiet, the same on every part.
  static Color lockedPaper(BuildContext context) {
    final ground = context.ground;
    final parts = context.skin.parts;
    // On a light ground (the day, the paper) the well is no darker than the
    // amber: the paper is laid toward the ground's ink instead, so a locked
    // piece is still the darkest button on it.
    return _light(ground)
        ? Color.lerp(ground.ground, ground.text, parts.lockedDark)!
        : Color.lerp(ground.ground, ground.panel, parts.lockedWell)!;
  }

  static bool _light(Ground ground) => ground.ground.computeLuminance() > 0.35;

  /// A locked piece lies flat and casts less: no backing under it (the paper's
  /// own thickness is what lifts a live amber piece), and its lift and the ink
  /// of its shadow are the skin's share of a scrap's ([PaperRaise.card]).
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

  /// The ink of the words on [part]'s paper: the paper's own text on bone
  /// paper (whatever ground it lies on), the ground's elsewhere. A [locked]
  /// piece (dark paper, [lockedPaper]) and a [disabled] one (sunk into its
  /// panel) hold the ground's own text (the day's: its light).
  static Color inkOf(
    BuildContext context,
    PaperPart part, {
    bool locked = false,
    bool disabled = false,
  }) {
    final ground = context.ground;
    if (locked) return _light(ground) ? ground.ground : ground.text;
    if (disabled) return ground.text;
    return switch (DressStyle.paper(part).fill) {
      PaperFill.amber => ground.onAccent,
      PaperFill.bone => context.skin.paper.text,
      PaperFill.inset => ground.text,
      PaperFill.ink => ground.ground,
      PaperFill.sunk => ground.text,
      PaperFill.navy => context.skin.night.text,
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
    final style = DressStyle.paper(part);
    final forced = PaperStateOverride.maybeOf(context);
    final pressed = this.pressed || (forced?.pressed ?? false);
    final lifted = this.lifted || (forced?.focused ?? false);
    final keep = skin.shape.pressKeep;
    final rest = _elevation(context, style.raise);
    final raised = lifted ? ground.elevation.selected : rest;
    final flat = locked || !enabled;
    // A locked piece lies flat and casts less (see [flattened]), whatever
    // part it is: one locked form.
    final low = _elevation(context, PaperRaise.card);
    (Elevation, Offset) look(bool sunk) => (
      flat
          ? flattened(context, sunk ? low.pressed(keep) : low)
          : sunk
          ? rest.pressed(keep)
          : raised,
      sunk
          ? rest.travel(keep)
          : lifted
          ? const Offset(0, -Space.xxs)
          : Offset.zero,
    );
    final (shown, sink) = look(pressed && enabled);
    final finger = press;
    final base = fill ?? fillOf(context, part);
    // A locked piece is the one quiet form; a disc that cannot be used (a
    // stepper's end of the range, always on a panel) is sunk into it, the
    // well's own paper.
    final paint = locked || (!enabled && !style.round)
        ? lockedPaper(context)
        : !enabled
        ? fillOf(context, PaperPart.well)
        : base;
    final parts = skin.parts;
    final (depth, step) = switch (style.edge) {
      PaperEdge.standard => (parts.deckleDepth, parts.deckleStep),
      PaperEdge.plaque => (parts.plaqueDepth, parts.plaqueStep),
      PaperEdge.pinned => (parts.pinnedDepth, parts.pinnedStep),
    };
    Decoration paper(Elevation elevation) => deckledPaper(
      context,
      fill: paint,
      id: (id, part),
      elevation: elevation,
      depth: style.blob
          ? parts.waxDepth
          : style.round
          ? parts.discDepth
          : depth,
      step: style.blob
          ? parts.waxStep
          : style.round
          ? parts.discStep
          : step,
      round: style.round,
      blob: style.blob,
      edgeLine: false,
      side: BorderSide.none,
    );
    final down = finger == null ? null : look(true);
    Widget body = TiltedPaper(
      angle: style.tilted ? skin.tilt.angle(Tilt.seededRow(id)) : 0,
      duration: duration,
      decoration: paper(shown),
      press: finger,
      pressed: down == null ? null : paper(down.$1),
      child: child,
    );
    if (finger != null && down != null) {
      body = PressSink(press: finger, by: down.$2 - sink, child: body);
    }
    return AnimatedContainer(
      duration: duration,
      curve: Motion.curve,
      transform: Matrix4.translationValues(sink.dx, sink.dy, 0),
      child: body,
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
