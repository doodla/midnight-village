import 'package:flutter/material.dart';

import '../copy/copy.dart';
import '../layout/space.dart';
import '../skin/dress.dart';
import '../skin/dress_style.dart';
import '../skin/skin.dart';
import 'cut_paper.dart';
import 'fit_line.dart';
import 'paper_lantern.dart';
import 'paper_piece.dart';
import 'primary_button.dart';

/// A second, quieter action beside or below the primary one: an outline on
/// the ground ("Do nothing tonight", "Take out of deck"). Like the primary
/// button it is never silently disabled: it acts, or it is
/// [SecondaryButton.locked] (a tap leads to what it lacks, and it is not drawn
/// dimmed), or [SecondaryButton.waiting] (a change of this phone's is on its
/// way elsewhere; [reason] says so to a screen reader). There is no `onPressed`
/// of null.
///
/// [SecondaryButton.paper] is a piece of paper instead, raised off the ground,
/// labelled in the primary button's face (S01 "Join"): an action beside a
/// field that is not the screen's main one.
class SecondaryButton extends StatefulWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    required VoidCallback this.onPressed,
    this.size = ButtonSize.regular,
    this.busy = false,
  }) : onLockedTap = null,
       reason = null,
       _paper = false;

  const SecondaryButton.paper({
    super.key,
    required this.label,
    required VoidCallback this.onPressed,
    this.size = ButtonSize.compact,
  }) : onLockedTap = null,
       reason = null,
       _paper = true,
       busy = false;

  /// What it needs is missing: drawn as it is when it acts, and a tap calls
  /// [onLockedTap] (the field it lacks takes the cursor and a nudge) instead.
  const SecondaryButton.locked({
    super.key,
    required this.label,
    required VoidCallback this.onLockedTap,
    this.size = ButtonSize.regular,
  }) : onPressed = null,
       reason = null,
       busy = false,
       _paper = false;

  /// A change of this phone's is on its way (another button of the screen is
  /// busy): dimmed, taking no tap, [reason] spoken.
  const SecondaryButton.waiting({
    super.key,
    required this.label,
    required String this.reason,
    this.size = ButtonSize.regular,
  }) : onPressed = null,
       onLockedTap = null,
       busy = false,
       _paper = false;

  /// The regular minimum height.
  static const height = 48.0;

  final String label;
  final VoidCallback? onPressed;
  final VoidCallback? onLockedTap;
  final String? reason;
  final ButtonSize size;
  final bool _paper;

  /// Tapped and on its way (02's "Leave"): the label keeps its ink, a turning
  /// mark beside it, and a second tap does nothing.
  final bool busy;

  @override
  State<SecondaryButton> createState() => _SecondaryButtonState();
}

class _SecondaryButtonState extends State<SecondaryButton> {
  var _pressed = false;
  var _focused = false;

  VoidCallback? get _onTap => widget.onPressed ?? widget.onLockedTap;

  @override
  Widget build(BuildContext context) {
    if (context.dress.isPaper) return _scrap(context);
    final skin = context.skin;
    final ground = context.ground;
    final busy = widget.busy;
    final enabled =
        widget.onPressed != null || widget.onLockedTap != null || busy;
    final radius = BorderRadius.circular(skin.shape.radius);
    final paper = widget._paper;

    final Decoration decoration;
    final TextStyle style;
    if (paper) {
      final rest = ground.elevation.raised;
      decoration = cutPaper(
        context,
        fill: enabled ? ground.paper : ground.disabled,
        radius: radius,
        elevation: enabled && !_pressed
            ? rest
            : rest.pressed(skin.shape.pressKeep),
      );
      style = widget.size
          .label(skin.typography)
          .copyWith(color: enabled ? skin.paper.text : ground.onDisabled);
    } else {
      decoration = BoxDecoration(
        color: _pressed ? ground.hairline : Colors.transparent,
        borderRadius: radius,
        border: Border.all(
          color: enabled ? ground.outline : ground.hairline,
          width: skin.shape.stroke,
        ),
      );
      // A button's label is the buttons' one size (15), outlined or paper.
      style = widget.size
          .label(skin.typography)
          .copyWith(color: enabled ? ground.text : ground.faintText);
    }

    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      hint: widget.reason,
      value: busy ? SpokenCopy.working : null,
      // The words are this node's own, and so is the tap (the ink's tap is
      // left out with its words): a screen reader can press it.
      onTap: busy ? null : _onTap,
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: Motion.press,
        curve: Motion.curve,
        constraints: BoxConstraints(
          minHeight: widget.size.secondaryHeight,
          minWidth: widget.size.minWidth,
        ),
        decoration: decoration,
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: busy ? null : _onTap,
            onHighlightChanged: (value) => setState(() => _pressed = value),
            highlightColor: Colors.transparent,
            borderRadius: radius,
            child: Stack(
              alignment: Alignment.center,
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: Space.lg,
                    vertical: Space.sm,
                  ),
                  child: Center(
                    heightFactor: 1,
                    widthFactor: 1,
                    child: FitWords(
                      widget.label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      style: style,
                    ),
                  ),
                ),
                // Busy: the lantern burns in the button's own end padding,
                // so the words stay where they are.
                if (busy)
                  PositionedDirectional(
                    end: Space.smPlus,
                    child: BusyMark(size: Space.xl, color: style.color),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }

  /// Dressed up, every secondary action is a bone scrap of paper (a
  /// [PaperPiece]: deckled, lying on the ground, no outline and no pin).
  Widget _scrap(BuildContext context) {
    final skin = context.skin;
    final busy = widget.busy;
    final enabled =
        widget.onPressed != null || widget.onLockedTap != null || busy;
    final radius = BorderRadius.circular(skin.shape.radius);
    final style = widget.size
        .label(skin.typography)
        .copyWith(
          color: PaperPiece.inkOf(context, PaperPart.scrap, locked: !enabled),
        );
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      hint: widget.reason,
      value: busy ? SpokenCopy.working : null,
      // The words are this node's own, and so is the tap (the ink's tap is
      // left out with its words): a screen reader can press it.
      onTap: busy ? null : _onTap,
      excludeSemantics: true,
      child: ConstrainedBox(
        constraints: BoxConstraints(
          minHeight: widget.size.secondaryHeight,
          minWidth: widget.size.minWidth,
        ),
        child: PaperPiece(
          part: PaperPart.scrap,
          id: widget.label,
          pressed: _pressed,
          lifted: _focused && !_pressed,
          enabled: enabled,
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: busy ? null : _onTap,
              onHighlightChanged: (value) => setState(() => _pressed = value),
              onFocusChange: (value) => setState(() => _focused = value),
              focusColor: Colors.transparent,
              hoverColor: Colors.transparent,
              highlightColor: Colors.transparent,
              splashColor: Colors.transparent,
              borderRadius: radius,
              child: Stack(
                alignment: Alignment.center,
                children: [
                  Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: Space.lg,
                      vertical: Space.sm,
                    ),
                    child: Center(
                      heightFactor: 1,
                      widthFactor: 1,
                      child: FitWords(
                        widget.label,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        style: style,
                      ),
                    ),
                  ),
                  // Busy: the lantern burns in the button's own end padding,
                  // so the words stay where they are.
                  if (busy)
                    PositionedDirectional(
                      end: Space.smPlus,
                      child: BusyMark(size: Space.xl, color: style.color),
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

/// The mark beside a button's words while its tap is on its way: a small
/// lantern in the label's ink, its flame breathing (`LanternMark`).
class BusyMark extends StatelessWidget {
  const BusyMark({super.key, required this.size, this.color});

  final double? size;
  final Color? color;

  @override
  Widget build(BuildContext context) =>
      LanternMark(size: size ?? 16, color: color);
}
