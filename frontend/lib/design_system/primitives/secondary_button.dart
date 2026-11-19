import 'package:flutter/material.dart';

import '../layout/space.dart';
import '../skin/skin.dart';
import 'cut_paper.dart';
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
  }) : _paper = false;

  const SecondaryButton.paper({
    super.key,
    required this.label,
    required this.onPressed,
    this.size = ButtonSize.compact,
  }) : _paper = true;

  /// The regular minimum height.
  static const height = 48.0;

  final String label;
  final VoidCallback? onPressed;
  final ButtonSize size;
  final bool _paper;

  @override
  State<SecondaryButton> createState() => _SecondaryButtonState();
}

class _SecondaryButtonState extends State<SecondaryButton> {
  var _pressed = false;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final ground = context.ground;
    final enabled = widget.onPressed != null;
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
      style = skin.typography.action.copyWith(
        color: enabled ? ground.text : ground.faintText,
      );
    }

    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
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
            onTap: widget.onPressed,
            onHighlightChanged: (value) => setState(() => _pressed = value),
            highlightColor: Colors.transparent,
            borderRadius: radius,
            child: Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: Space.lg,
                vertical: Space.sm,
              ),
              child: Center(
                heightFactor: 1,
                widthFactor: 1,
                child: Text(
                  widget.label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: style,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
