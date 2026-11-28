import 'package:flutter/material.dart';

import '../copy/copy.dart';
import '../feel/press.dart';
import '../layout/space.dart';
import '../skin/dress.dart';
import '../skin/skin.dart';
import 'fit_line.dart';
import 'secondary_button.dart' show BusyMark;

/// A quiet action said in words: its label in the small button type and
/// the ground's text colour, underlined, with no fill and no outline, so it
/// is never the loudest thing on a screen yet reads at a glance (a guest's
/// "Leave" on 02, at the foot, and on 11, beside "{host} deals next.";
/// playtest: a 16 px "Leave" read as tiny). At least [minTap] square to
/// touch; dims while pressed, from the frame the finger lands (`Pressable`,
/// by paint alone); faint and inert with no [onPressed].
class TextAction extends StatefulWidget {
  const TextAction({
    super.key,
    required this.label,
    required this.onPressed,
    this.busy = false,
    this.roomy = false,
    this.quiet = false,
  });

  final String label;
  final VoidCallback? onPressed;

  /// Tapped and on its way: the words keep their ink, a turning mark beside.
  final bool busy;

  /// A link alone on a line (01's "Get the app"): [roomyTap] high to touch.
  final bool roomy;

  /// Quieter still, to sit beside a line of text (01's "Get the app" beside
  /// "N at tables"): the lede's size and face, the ground's quiet ink.
  final bool quiet;

  /// The smallest touch target, both ways.
  static const minTap = 44.0;

  /// The height of a [roomy] one.
  static const roomyTap = 48.0;

  @override
  State<TextAction> createState() => _TextActionState();
}

class _TextActionState extends State<TextAction> {
  @override
  Widget build(BuildContext context) {
    final ground = context.ground;
    final busy = widget.busy;
    final enabled = widget.onPressed != null || busy;
    final type = context.skin.typography;
    // Dressed up a quiet action is plain serif words: no underline, no
    // outline, no fill (the paper's language, `dress_style.dart`).
    final style = context.dress.isPaper
        ? type.name.copyWith(color: enabled ? ground.text : ground.faintText)
        : (widget.quiet ? type.lede : type.buttonLabelSmall).copyWith(
            color: enabled
                ? (widget.quiet ? ground.quietText : ground.text)
                : ground.faintText,
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
      child: Pressable(
        enabled: widget.onPressed != null,
        builder: (context, press, _) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: busy ? null : widget.onPressed,
          child: ConstrainedBox(
            constraints: BoxConstraints(
              minWidth: TextAction.minTap,
              minHeight: widget.roomy ? TextAction.roomyTap : TextAction.minTap,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: Space.sm),
              child: Center(
                widthFactor: 1,
                child: FadeTransition(
                  opacity: press.drive(
                    Tween(begin: 1, end: context.skin.dimmed),
                  ),
                  // Busy: the lantern hangs off the end of the word, outside
                  // its box, so the word does not move.
                  child: Stack(
                    clipBehavior: Clip.none,
                    alignment: Alignment.center,
                    children: [
                      FitWords(widget.label, maxLines: 1, style: style),
                      if (busy)
                        PositionedDirectional(
                          end: -(Space.xl + Space.xs),
                          child: BusyMark(size: Space.xl, color: style.color),
                        ),
                    ],
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
