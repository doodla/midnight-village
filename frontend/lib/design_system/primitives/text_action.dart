import 'package:flutter/material.dart';

import '../copy/copy.dart';
import '../layout/space.dart';
import '../skin/skin.dart';
import 'fit_line.dart';
import 'secondary_button.dart' show BusyMark;

/// A quiet action said in words: its label in the small button type and
/// the ground's text colour, underlined, with no fill and no outline, so it
/// is never the loudest thing on a screen yet reads at a glance (a guest's
/// "Leave" on 02, at the foot, and on 11, beside "{host} deals next.";
/// playtest: a 16 px "Leave" read as tiny). At least [minTap] square to
/// touch; dims while pressed; faint and inert with no [onPressed].
class TextAction extends StatefulWidget {
  const TextAction({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
  });

  final String label;
  final VoidCallback? onPressed;

  /// Tapped and on its way: the words keep their ink, a turning mark beside.
  final bool busy;

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
    final busy = widget.busy;
    final enabled = widget.onPressed != null || busy;
    final style = context.skin.typography.buttonLabelSmall.copyWith(
      color: enabled ? ground.text : ground.faintText,
      decoration: TextDecoration.underline,
      decorationColor: enabled ? ground.quietText : null,
    );
    return Semantics(
      button: true,
      enabled: enabled,
      label: widget.label,
      value: busy ? SpokenCopy.working : null,
      // The words are this node's own, and so is the tap (the gesture's tap
      // is left out with its words): a screen reader can press it.
      onTap: busy ? null : widget.onPressed,
      excludeSemantics: true,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: busy ? null : widget.onPressed,
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
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  spacing: Space.sm,
                  children: [
                    Flexible(
                      child: FitWords(widget.label, maxLines: 1, style: style),
                    ),
                    if (busy)
                      BusyMark(size: style.fontSize, color: style.color),
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
