import 'package:flutter/material.dart';

import '../copy/copy.dart';
import '../layout/space.dart';
import '../skin/skin.dart';
import 'cut_paper.dart';
import 'fit_line.dart';
import 'paper_lantern.dart';
import 'primary_button.dart';

/// A second, quieter action beside or below the primary one: an outline on
/// the ground ("Do nothing tonight", "Take out of deck"). [onPressed] null
/// disables it.
///
/// [SecondaryButton.paper] is a piece of paper instead, raised off the ground,
/// labelled in the primary button's face (S01 "Join"): an action beside a
/// field that is not the screen's main one.
class SecondaryButton extends StatefulWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.size = ButtonSize.regular,
    this.busy = false,
  }) : _paper = false;

  const SecondaryButton.paper({
    super.key,
    required this.label,
    required this.onPressed,
    this.size = ButtonSize.compact,
  }) : _paper = true,
       busy = false;

  /// The regular minimum height.
  static const height = 48.0;

  final String label;
  final VoidCallback? onPressed;
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

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final ground = context.ground;
    final busy = widget.busy;
    final enabled = widget.onPressed != null || busy;
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
      value: busy ? SpokenCopy.working : null,
      // The words are this node's own, and so is the tap (the ink's tap is
      // left out with its words): a screen reader can press it.
      onTap: busy ? null : widget.onPressed,
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
            onTap: busy ? null : widget.onPressed,
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
