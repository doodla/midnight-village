import 'package:flutter/material.dart';

import '../copy/copy.dart';
import '../layout/space.dart';
import '../skin/elevation.dart';
import '../skin/skin.dart';
import '../skin/skin_type.dart';
import 'cut_paper.dart';
import 'fit_line.dart';
import 'secondary_button.dart' show BusyMark;

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

  /// Done: its label is the state in one word ("Chosen", "Locked",
  /// "Ready ✓"). Settled: no fill and no outline, only a check and the word
  /// in quiet ink where the button was, so it reads neither as a [locked]
  /// gate nor as something to tap. (08's "Ready ✓" is a toggle, [quiet]:
  /// still a button, outlined, with the same check before the word.)
  done,

  /// It acts, but is never amber: a button that must not be the loudest
  /// thing (08's "Ready to vote", which a bored player would tap to end the
  /// talk).
  quiet,
}

/// The one main action of a screen: lantern amber with a hard shadow (and an
/// ink edge on day grounds), pressed down while held, when [phase] is ready.
/// Waiting, locked and quiet are an outline with no fill; done is no
/// button at all, a check and its word in quiet ink: so the only amber on a
/// screen is a button that acts, and a finished step never looks like a gate
/// or a thing to tap. A label ending in [checkMark] is drawn with the check
/// before the words, in every phase. [busy] keeps a ready button filled and
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

  /// A check mark at the end of a label ("Ready ✓"): the skin's fonts have
  /// no such glyph, so it is drawn as an icon after the words, the same on
  /// every phone (a device's fallback font would draw its own).
  static const checkMark = ' ✓';

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

  Widget _label(TextStyle style) {
    final label = widget.label;
    Widget words(String text) =>
        FitWords(text, textAlign: TextAlign.center, maxLines: 2, style: style);
    final check = Icon(
      Icons.check,
      color: style.color,
      size: MediaQuery.textScalerOf(context).scale(style.fontSize!),
    );
    final bare = label.endsWith(PrimaryButton.checkMark)
        ? label.substring(0, label.length - PrimaryButton.checkMark.length)
        : label;
    if (widget.phase == ButtonPhase.done ||
        label.endsWith(PrimaryButton.checkMark)) {
      // The check first: one form of "Ready ✓" everywhere.
      return Row(
        mainAxisSize: MainAxisSize.min,
        spacing: Space.xs,
        children: [
          check,
          Flexible(child: words(bare)),
        ],
      );
    }
    return words(label);
  }

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
    // Busy, it stays pressed into its shadow while it works.
    final down = (_pressed && _acts) || widget.busy;
    final ink = switch (widget.phase) {
      ButtonPhase.ready => ground.onAccent,
      ButtonPhase.waiting => ground.quietText,
      // Done says something true ("Nothing to do", "Locked"): full ink;
      // with no outline it still reads as nothing to press (playtest: the
      // quiet ink read as too pale).
      ButtonPhase.done ||
      ButtonPhase.locked ||
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
        : widget.phase == ButtonPhase.done
        ? const BoxDecoration()
        : BoxDecoration(
            borderRadius: radius,
            border: Border.all(color: ground.outline, width: skin.shape.stroke),
          );

    return Semantics(
      button: true,
      enabled: _acts,
      label: widget.label,
      value: widget.busy ? SpokenCopy.working : null,
      // The words are this node's own, and so is the tap (the ink's tap is
      // left out with its words): a screen reader can press it.
      onTap: _onTap,
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
            child: Stack(
              alignment: Alignment.center,
              children: [
                Padding(
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
                        Flexible(child: _label(style.copyWith(color: ink))),
                      ],
                    ),
                  ),
                ),
                // Busy: the mark turns in the button's own end padding, so
                // the label keeps its place and its line (it never wraps
                // for the mark).
                if (widget.busy)
                  PositionedDirectional(
                    end: Space.sm,
                    child: BusyMark(size: Space.xl, color: ink),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
