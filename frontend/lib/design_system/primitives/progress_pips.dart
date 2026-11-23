import 'package:flutter/widgets.dart';

import '../layout/space.dart';
import '../skin/dress.dart';
import '../skin/dress_style.dart';
import '../skin/skin.dart';
import 'paper_piece.dart';

/// "3 of 5" as a row of plain pips and the words. Plain on purpose: no token,
/// no name, so progress never says who is slow (first-time play spec, copy
/// rule 8). In a skin whose pips stretch, they share the row's width as
/// bars.
class ProgressPips extends StatelessWidget {
  const ProgressPips({
    super.key,
    required this.done,
    required this.total,
    required this.label,
    this.centred = false,
  });

  /// How many of [total] are filled.
  final int done;
  final int total;

  /// The words after the pips ("3 of 5 ready", `CommonCopy.progress`), also
  /// what is read out.
  final String label;

  /// Centred under a centred screen (S04); otherwise from the start.
  final bool centred;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final words = Padding(
      padding: const EdgeInsetsDirectional.only(start: Space.xs),
      child: Text(
        label,
        // A count is read from across the table: larger than body text,
        // bold, in full ink (playtest: "0 of 5 ready" small and grey).
        style: skin.typography.bodyStrong.copyWith(color: context.ground.text),
      ),
    );
    final Widget row;
    if (skin.shape.pipStretch) {
      row = Row(
        spacing: Space.sm,
        children: [
          for (var i = 0; i < total; i++)
            Expanded(child: _Pip(filled: i < done)),
          // The words keep up to half the row when the text is large.
          Flexible(flex: total, child: words),
        ],
      );
    } else {
      row = Wrap(
        alignment: centred ? WrapAlignment.center : WrapAlignment.start,
        crossAxisAlignment: WrapCrossAlignment.center,
        spacing: Space.sm,
        runSpacing: Space.sm,
        children: [
          for (var i = 0; i < total; i++) _Pip(filled: i < done),
          words,
        ],
      );
    }
    return Semantics(label: label, excludeSemantics: true, child: row);
  }
}

class _Pip extends StatelessWidget {
  const _Pip({required this.filled});

  final bool filled;

  @override
  Widget build(BuildContext context) {
    final shape = context.skin.shape;
    final ground = context.ground;
    // Dressed up: a punched paper dot with its shadow, the lit one the ground's
    // ink and the unlit one a darker paper that still stands off the ground
    // (3:1); never a flat vector circle.
    if (context.dress.isPaper) {
      return SizedBox(
        width: shape.pipStretch ? null : shape.pip.width,
        height: shape.pip.height,
        child: PaperPiece(
          part: PaperPart.pip,
          id: filled,
          fill: filled ? ground.text : context.skin.parts.pipUnlit(ground),
          child: const SizedBox.expand(),
        ),
      );
    }
    final outlined = !filled && shape.pipEmptyStroke > 0;
    return Container(
      width: shape.pipStretch ? null : shape.pip.width,
      height: shape.pip.height,
      decoration: BoxDecoration(
        color: filled
            ? ground.text
            : outlined
            ? null
            : ground.hairline,
        border: outlined
            ? Border.all(color: ground.text, width: shape.pipEmptyStroke)
            : null,
        borderRadius: BorderRadius.circular(
          shape.corner(shape.pip.height, shape.pipRoundness),
        ),
      ),
    );
  }
}
