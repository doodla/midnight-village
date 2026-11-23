import 'package:flutter/material.dart';

import '../layout/space.dart';
import '../skin/dress.dart';
import '../skin/dress_style.dart';
import '../skin/skin.dart';
import 'paper_piece.dart';

/// The visible word of something that is tapped as a whole (the deck box's
/// "Edit"): words in the ground's ink on a plain screen, exactly as they were;
/// a small bone scrap with the words on it on a paper one (a [PaperPiece]). It
/// takes no tap of its own: the box around it does.
class ScrapLabel extends StatelessWidget {
  const ScrapLabel(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) {
    final type = context.skin.typography;
    if (!context.dress.isPaper) {
      return Text(
        text,
        style: type.action.copyWith(color: context.ground.text),
      );
    }
    return PaperPiece(
      part: PaperPart.scrap,
      id: text,
      child: Padding(
        padding: const EdgeInsets.symmetric(
          horizontal: Space.smPlus,
          vertical: Space.xs,
        ),
        child: Text(
          text,
          style: type.action.copyWith(
            color: PaperPiece.inkOf(context, PaperPart.scrap),
          ),
        ),
      ),
    );
  }
}
