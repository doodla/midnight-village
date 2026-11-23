import 'package:flutter/material.dart';

import '../copy/copy.dart';
import '../layout/space.dart';
import '../skin/dress.dart';
import '../skin/dress_style.dart';
import '../skin/skin.dart';
import 'fit_line.dart';
import 'paper_piece.dart';

/// "You" beside the viewer's own name wherever players are listed (02's
/// table, 10's count, 11's results): outlined in [ink], never filled, so it
/// does not read as a role's tag (cold read on the real screens: "which one
/// is me?").
class YouTag extends StatelessWidget {
  const YouTag({super.key, required this.ink});

  /// The colour of the words on what it sits on.
  final Color ink;

  @override
  Widget build(BuildContext context) => _OutlineTag(NightCopy.you, ink: ink);
}

/// "Practice" after a practice player's name (a seat the server plays) at
/// the table and in the vote, on the name's line: quieter than [YouTag],
/// which stays the one outlined tag in a list. The word alone in the tag's
/// face, no outline, in full ink (it says something true); the token, the
/// thing the seat is named for, says the rest.
class PracticeTag extends StatelessWidget {
  const PracticeTag({super.key, required this.ink});

  /// The colour of the words on what it sits on.
  final Color ink;

  @override
  Widget build(BuildContext context) => FitLine(
    TableCopy.practice,
    style: context.skin.typography.tag.copyWith(color: ink),
  );
}

class _OutlineTag extends StatelessWidget {
  const _OutlineTag(this.text, {required this.ink});

  final String text;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    // Dressed up: a cut-paper tag a shade darker than the bone row it is on
    // (a [PaperPiece]), never an outline.
    if (context.dress.isPaper) {
      return PaperPiece(
        part: PaperPart.tag,
        id: text,
        fill: skin.paper.panel,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: Space.sm,
            vertical: Space.xxs,
          ),
          child: FitWords(
            text,
            maxLines: 1,
            style: skin.typography.tag.copyWith(color: skin.paper.text),
          ),
        ),
      );
    }
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Space.sm,
        vertical: Space.xxs,
      ),
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(skin.shape.radiusTiny),
        border: Border.all(color: ink, width: skin.shape.ring),
      ),
      child: FitWords(
        text,
        maxLines: 1,
        style: skin.typography.tag.copyWith(color: ink),
      ),
    );
  }
}
