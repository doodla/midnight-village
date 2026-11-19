import 'package:flutter/material.dart';

import '../skin/skin.dart';

/// A second, quieter action beside or below the primary one: an outline on
/// the ground ("Do nothing tonight", "Change the deck"). [onPressed] null
/// disables it.
class SecondaryButton extends StatefulWidget {
  const SecondaryButton({
    super.key,
    required this.label,
    required this.onPressed,
  });

  /// Minimum height; it grows with larger text.
  static const height = 48.0;

  final String label;
  final VoidCallback? onPressed;

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

    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: skin.motion.press,
        constraints: const BoxConstraints(minHeight: SecondaryButton.height),
        decoration: BoxDecoration(
          color: _pressed ? ground.hairline : Colors.transparent,
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
            onHighlightChanged: (value) => setState(() => _pressed = value),
            highlightColor: Colors.transparent,
            borderRadius: radius,
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: skin.spacing.lg,
                vertical: skin.spacing.sm,
              ),
              child: Center(
                heightFactor: 1,
                child: Text(
                  widget.label,
                  textAlign: TextAlign.center,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: skin.typography.action.copyWith(
                    color: enabled ? ground.text : ground.faintText,
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
