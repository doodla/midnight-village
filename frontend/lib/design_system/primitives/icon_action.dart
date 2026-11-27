import 'package:flutter/material.dart';

import '../feel/press.dart';
import '../skin/dress.dart';
import '../layout/space.dart';
import '../skin/skin.dart';
import 'secondary_button.dart';

/// An action that is only a glyph (the table's Share): the platform's glyph in
/// a Material icon button on a plain screen, exactly as it was; on a paper one
/// a bone scrap with the glyph on it (a [PaperPiece]). [label] is spoken (and
/// the plain tooltip). A finger presses it from the frame it lands
/// (`Pressable`): the glyph dims.
class IconAction extends StatefulWidget {
  const IconAction({
    super.key,
    required this.icon,
    required this.label,
    required this.onPressed,
  });

  final IconData icon;
  final String label;
  final VoidCallback? onPressed;

  /// The side of its touch target (Material's icon button's).
  static const side = SecondaryButton.height;

  /// The glyph's ink while pressed, and its size focused (dressed up).
  static const pressedInk = 0.6;
  static const focusedScale = 1.12;

  @override
  State<IconAction> createState() => _IconActionState();
}

class _IconActionState extends State<IconAction> {
  var _focused = false;

  @override
  Widget build(BuildContext context) {
    final ground = context.ground;
    if (!context.dress.isPaper) {
      return Pressable(
        enabled: widget.onPressed != null,
        builder: (context, press, child) =>
            PressFade(press: press, to: IconAction.pressedInk, child: child),
        child: IconButton(
          onPressed: widget.onPressed,
          tooltip: widget.label,
          color: ground.text,
          icon: Icon(widget.icon),
        ),
      );
    }
    // Dressed up: a bare glyph in ink, nothing laid under it (it sits on a
    // notice of paper already); a press dims it, focus lifts it.
    final enabled = widget.onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      excludeSemantics: true,
      onTap: widget.onPressed,
      child: Tooltip(
        message: widget.label,
        excludeFromSemantics: true,
        child: SizedBox.square(
          dimension: IconAction.side,
          child: Pressable(
            enabled: enabled,
            builder: (context, press, child) => PressFade(
              press: press,
              to: IconAction.pressedInk,
              child: child,
            ),
            child: Material(
              type: MaterialType.transparency,
              child: InkWell(
                onTap: widget.onPressed,
                onFocusChange: (v) => setState(() => _focused = v),
                highlightColor: Colors.transparent,
                focusColor: Colors.transparent,
                hoverColor: Colors.transparent,
                splashColor: Colors.transparent,
                borderRadius: BorderRadius.circular(context.skin.shape.radius),
                child: AnimatedScale(
                  duration: Motion.press,
                  scale: _focused ? IconAction.focusedScale : 1,
                  child: Icon(widget.icon, color: context.skin.paper.text),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
