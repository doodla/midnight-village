import 'package:flutter/material.dart';

import '../layout/space.dart';
import '../skin/elevation.dart';
import '../skin/skin.dart';
import '../skin/skin_type.dart';
import 'cut_paper.dart';
import 'fit_line.dart';

/// The mocks' button sizes.
enum ButtonSize {
  /// The screen's one big moment (S01, S04, S11 "Play again"): 60 tall.
  large(primaryHeight: 60, secondaryHeight: 60, shadow: 1.2, minWidth: 0),

  /// Everywhere else: 56 tall (a secondary button 48).
  regular(primaryHeight: 56, secondaryHeight: 48, shadow: 1, minWidth: 0),

  /// In a sheet or beside a field (S03b "Close", S01 "Join"): 52 tall, at
  /// least 104 wide.
  compact(primaryHeight: 52, secondaryHeight: 52, shadow: 0.8, minWidth: 104);

  const ButtonSize({
    required this.primaryHeight,
    required this.secondaryHeight,
    required this.shadow,
    required this.minWidth,
  });

  /// Minimum heights; a button grows with larger text.
  final double primaryHeight;
  final double secondaryHeight;

  /// The ground's primary shadow, times this (5,5 regular: 6,6 and 4,4).
  final double shadow;
  final double minWidth;

  /// The primary button's label at this size.
  TextStyle label(SkinType type) => switch (this) {
    large => type.buttonLabelLarge,
    regular => type.buttonLabel,
    compact => type.buttonLabelSmall,
  };
}

/// What a [PrimaryButton] can do now (first-time play spec, copy rule 4).
enum ButtonPhase {
  /// It acts: the screen's one amber fill.
  ready,

  /// Waiting for input; its label names what is missing ("Pick a name").
  waiting,

  /// A gate: it keeps the label of what it will do ("Ready", "Choose
  /// Cleo") until the thing that unlocks it is done; a tap on it replays the
  /// screen's cue (`TeachOnce`).
  locked,

  /// Done: its label is the state in one word ("Chosen", "Ready ✓").
  done,

  /// It acts, but is never amber: a button that must not be the loudest
  /// thing (08's "Ready to vote", which a bored player would tap to end the
  /// talk).
  quiet,
}

/// The one main action of a screen: lantern amber with a hard shadow (and an
/// ink edge on day grounds), pressed down while held, when [phase] is ready.
/// Every other phase is an outline with no fill, so the only amber on a
/// screen is a button that acts. [busy] keeps a ready button filled and
/// readable but shows that the action is on its way and ignores more taps.
class PrimaryButton extends StatefulWidget {
  /// Ready when [onPressed] is given, else waiting.
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
    this.size = ButtonSize.regular,
    this.icon,
  }) : onLockedTap = null,
       _phase = null;

  /// A gate, locked: a tap calls [onLockedTap] (replay the cue) and does not
  /// act.
  const PrimaryButton.locked({
    super.key,
    required this.label,
    required VoidCallback this.onLockedTap,
    this.size = ButtonSize.regular,
    this.icon,
  }) : onPressed = null,
       busy = false,
       _phase = ButtonPhase.locked;

  /// It acts, outlined: never the screen's amber.
  const PrimaryButton.quiet({
    super.key,
    required this.label,
    required VoidCallback this.onPressed,
    this.size = ButtonSize.regular,
  }) : onLockedTap = null,
       icon = null,
       busy = false,
       _phase = ButtonPhase.quiet;

  /// After the action: [label] says the state, and it stays disabled.
  const PrimaryButton.done({
    super.key,
    required this.label,
    this.size = ButtonSize.regular,
  }) : onPressed = null,
       icon = null,
       onLockedTap = null,
       busy = false,
       _phase = ButtonPhase.done;

  /// The regular minimum height.
  static const height = 56.0;

  final String label;
  final VoidCallback? onPressed;
  final VoidCallback? onLockedTap;
  final bool busy;
  final ButtonSize size;

  /// A glyph before the label (the padlock of "Lock in Cleo").
  final IconData? icon;
  final ButtonPhase? _phase;

  ButtonPhase get phase =>
      _phase ?? (onPressed == null ? ButtonPhase.waiting : ButtonPhase.ready);

  @override
  State<PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<PrimaryButton> {
  var _pressed = false;

  bool get _acts =>
      (widget.phase == ButtonPhase.ready && !widget.busy) ||
      widget.phase == ButtonPhase.quiet;

  VoidCallback? get _onTap => switch (widget.phase) {
    ButtonPhase.ready => widget.busy ? null : widget.onPressed,
    ButtonPhase.quiet => widget.onPressed,
    ButtonPhase.locked => widget.onLockedTap,
    ButtonPhase.waiting || ButtonPhase.done => null,
  };

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final ground = context.ground;
    final filled = widget.phase == ButtonPhase.ready;
    final radius = BorderRadius.circular(skin.shape.radius);
    final keep = skin.shape.pressKeep;
    final rest = filled
        ? ground.elevation.primary.scaled(widget.size.shadow)
        : Elevation.none;
    final down = _pressed && _acts;
    final ink = switch (widget.phase) {
      ButtonPhase.ready => ground.onAccent,
      ButtonPhase.waiting => ground.quietText,
      ButtonPhase.locked ||
      ButtonPhase.done ||
      ButtonPhase.quiet => ground.text,
    };
    final style = widget.size.label(skin.typography);
    final edge = ground.accentEdge;
    final decoration = filled
        ? cutPaper(
            context,
            fill: ground.accent,
            radius: radius,
            elevation: down ? rest.pressed(keep) : rest,
          ).copyWith(
            border: edge != null && skin.shape.edgeWidth == 0
                ? Border.all(color: edge, width: skin.shape.stroke)
                : null,
          )
        : BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: ground.outline, width: skin.shape.stroke),
          );

    return Semantics(
      button: true,
      enabled: _acts,
      label: widget.label,
      value: widget.busy ? 'Working' : null,
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: Motion.press,
        curve: Motion.curve,
        constraints: BoxConstraints(
          minHeight: widget.size.primaryHeight,
          minWidth: widget.size.minWidth,
        ),
        transform: Matrix4.translationValues(
          down ? rest.travel(keep).dx : 0,
          down ? rest.travel(keep).dy : 0,
          0,
        ),
        decoration: decoration,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: _onTap,
            onHighlightChanged: (value) => setState(() => _pressed = value),
            highlightColor: Colors.transparent,
            splashColor: Colors.transparent,
            borderRadius: radius,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Space.xl,
                vertical: Space.sm,
              ),
              child: Center(
                heightFactor: 1,
                widthFactor: 1,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: Space.md,
                  children: [
                    if (widget.icon case final icon?)
                      Icon(icon, color: ink, size: style.fontSize),
                    Flexible(
                      child: FitWords(
                        widget.label,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        style: style.copyWith(color: ink),
                      ),
                    ),
                    if (widget.busy)
                      SizedBox.square(
                        dimension: style.fontSize,
                        child: CircularProgressIndicator(
                          strokeWidth: skin.shape.stroke,
                          color: ink,
                        ),
                      ),
                  ],
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
