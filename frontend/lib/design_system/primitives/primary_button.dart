import 'package:flutter/material.dart';

import '../skin/elevation.dart';
import '../skin/skin.dart';
import 'cut_paper.dart';

/// The one main action of a screen: the ground's accent with a hard shadow,
/// pressed down while held. [onPressed] null disables it; [busy] keeps it
/// filled but shows that the action is on its way and ignores more taps.
class PrimaryButton extends StatefulWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
  });

  /// Minimum height; it grows with larger text.
  static const height = 56.0;

  final String label;
  final VoidCallback? onPressed;
  final bool busy;

  @override
  State<PrimaryButton> createState() => _PrimaryButtonState();
}

class _PrimaryButtonState extends State<PrimaryButton> {
  var _pressed = false;

  bool get _enabled => widget.onPressed != null && !widget.busy;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final ground = context.ground;
    final live = widget.onPressed != null;
    final fill = live ? ground.accent : ground.disabled;
    final ink = live ? ground.onAccent : ground.onDisabled;
    final keep = skin.shape.pressKeep;
    final rest = live ? ground.elevation.primary : Elevation.none;
    final down = _pressed && _enabled;

    return Semantics(
      button: true,
      enabled: _enabled,
      label: widget.label,
      value: widget.busy ? 'Working' : null,
      excludeSemantics: true,
      child: AnimatedContainer(
        duration: skin.motion.press,
        curve: skin.motion.curve,
        constraints: const BoxConstraints(minHeight: PrimaryButton.height),
        transform: Matrix4.translationValues(
          down ? rest.travel(keep).dx : 0,
          down ? rest.travel(keep).dy : 0,
          0,
        ),
        decoration: cutPaper(
          context,
          fill: fill,
          radius: BorderRadius.circular(skin.shape.radius),
          elevation: down ? rest.pressed(keep) : rest,
        ),
        child: Material(
          type: MaterialType.transparency,
          child: InkWell(
            onTap: _enabled ? widget.onPressed : null,
            onHighlightChanged: (value) => setState(() => _pressed = value),
            highlightColor: Colors.transparent,
            borderRadius: BorderRadius.circular(skin.shape.radius),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: skin.spacing.xl,
                vertical: skin.spacing.sm,
              ),
              child: Center(
                heightFactor: 1,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: skin.spacing.md,
                  children: [
                    Flexible(
                      child: Text(
                        widget.label,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: skin.typography.buttonLabel.copyWith(
                          color: widget.busy
                              ? ink.withValues(alpha: skin.dimmed)
                              : ink,
                        ),
                      ),
                    ),
                    if (widget.busy)
                      SizedBox.square(
                        dimension: skin.typography.buttonLabel.fontSize,
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
