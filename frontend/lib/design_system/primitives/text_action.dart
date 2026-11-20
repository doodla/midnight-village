import 'package:flutter/material.dart';

import '../layout/space.dart';
import '../skin/skin.dart';
import 'fit_line.dart';

/// A quiet action said in words: its label in the action type and the
/// ground's text colour, with no fill and no outline, so it is never the
/// loudest thing on a screen (11's "Leave" for a guest, beside "{host} deals
/// next."). At least [minTap] square to touch; dims while pressed; faint and
/// inert with no [onPressed].
class TextAction extends StatefulWidget {
  const TextAction({super.key, required this.label, required this.onPressed});

  final String label;
  final VoidCallback? onPressed;

  /// The smallest touch target, both ways.
  static const minTap = 44.0;

  @override
  State<TextAction> createState() => _TextActionState();
}

class _TextActionState extends State<TextAction> {
  var _pressed = false;

  void _press(bool down) {
    if (widget.onPressed != null && _pressed != down) {
      setState(() => _pressed = down);
    }
  }

  @override
  Widget build(BuildContext context) {
    final ground = context.ground;
    final enabled = widget.onPressed != null;
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: widget.onPressed,
        onTapDown: (_) => _press(true),
        onTapUp: (_) => _press(false),
        onTapCancel: () => _press(false),
        child: ConstrainedBox(
          constraints: const BoxConstraints(
            minWidth: TextAction.minTap,
            minHeight: TextAction.minTap,
          ),
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.sm),
            child: Center(
              widthFactor: 1,
              child: AnimatedOpacity(
                opacity: _pressed ? context.skin.dimmed : 1,
                duration: Motion.press,
                child: FitWords(
                  widget.label,
                  maxLines: 1,
                  style: context.skin.typography.action.copyWith(
                    color: enabled ? ground.text : ground.faintText,
                    decoration: TextDecoration.underline,
                    decorationColor: enabled ? ground.quietText : null,
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
