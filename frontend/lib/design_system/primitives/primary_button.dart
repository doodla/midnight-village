import 'package:flutter/material.dart';

import '../layout/space.dart';
import '../skin/elevation.dart';
import '../skin/skin.dart';
import '../skin/skin_type.dart';
import 'cut_paper.dart';
import 'fit_line.dart';

/// The mocks' button sizes.
enum ButtonSize {
  /// The screen's one big moment (S01 "Start a table", S04 "I know my card",
  /// S11 "Play again"): 60 tall.
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

/// The one main action of a screen: the ground's accent with a hard shadow,
/// pressed down while held. [onPressed] null disables it; [busy] keeps it
/// filled and readable but shows that the action is on its way and ignores
/// more taps.
class PrimaryButton extends StatefulWidget {
  const PrimaryButton({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
    this.size = ButtonSize.regular,
  });

  /// The regular minimum height.
  static const height = 56.0;

  final String label;
  final VoidCallback? onPressed;
  final bool busy;
  final ButtonSize size;

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
    final rest = live
        ? ground.elevation.primary.scaled(widget.size.shadow)
        : Elevation.none;
    final down = _pressed && _enabled;
    final style = widget.size.label(skin.typography);

    return Semantics(
      button: true,
      enabled: _enabled,
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
