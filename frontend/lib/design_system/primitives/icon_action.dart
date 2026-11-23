import 'package:flutter/material.dart';

import '../skin/dress.dart';
import '../layout/space.dart';
import '../skin/skin.dart';
import 'secondary_button.dart';

/// An action that is only a glyph (the table's Share): the platform's glyph in
/// a Material icon button on a plain screen, exactly as it was; on a paper one
/// a bone scrap with the glyph on it (a [PaperPiece]). [label] is spoken (and
/// the plain tooltip).
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

  @override
  State<IconAction> createState() => _IconActionState();
}

class _IconActionState extends State<IconAction> {
  var _pressed = false;
  var _focused = false;

  @override
  Widget build(BuildContext context) {
    final ground = context.ground;
    if (!context.dress.isPaper) {
      return IconButton(
        onPressed: widget.onPressed,
        tooltip: widget.label,
        color: ground.text,
        icon: Icon(widget.icon),
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
          child: Material(
            type: MaterialType.transparency,
            child: InkWell(
              onTap: widget.onPressed,
              onHighlightChanged: (v) => setState(() => _pressed = v),
              onFocusChange: (v) => setState(() => _focused = v),
              highlightColor: Colors.transparent,
              focusColor: Colors.transparent,
              hoverColor: Colors.transparent,
              splashColor: Colors.transparent,
              borderRadius: BorderRadius.circular(context.skin.shape.radius),
              child: AnimatedScale(
                duration: Motion.press,
                scale: _focused && !_pressed ? 1.12 : 1,
                child: Icon(
                  widget.icon,
                  color: context.skin.paper.text.withValues(
                    alpha: _pressed ? 0.6 : 1,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
