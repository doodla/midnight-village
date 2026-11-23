import 'package:flutter/material.dart';

import '../copy/copy.dart';
import '../layout/space.dart';
import '../skin/dress.dart';
import '../skin/skin.dart';
import 'fit_line.dart';
import 'text_backing.dart';

/// "You" beside the viewer's own name wherever players are listed (02's
/// table, 10's count, 11's results): outlined in [ink], never filled, so it
/// does not read as a role's tag (cold read on the real screens: "which one
/// is me?").
class YouTag extends StatelessWidget {
  const YouTag({
    super.key,
    required this.ink,
    this.compact = false,
    this.style,
  });

  /// The colour of the words on what it sits on.
  final Color ink;

  /// One line tall, no more: under a board card, in the room of a name.
  final bool compact;

  /// A compact tag's face, one line tall exactly (the name's, under a card).
  final TextStyle? style;

  @override
  Widget build(BuildContext context) =>
      _OutlineTag(NightCopy.you, ink: ink, compact: compact, style: style);
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
  const _OutlineTag(
    this.text, {
    required this.ink,
    required this.compact,
    this.style,
  });

  final String text;
  final bool compact;
  final Color ink;
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    // Dressed up: a cut-paper tag (a [PaperPiece]), never an outline.
    if (context.dress.isPaper) {
      // A plate of paper in the ink of what it lies on (a navy tag on a bone
      // row, a bone one on the night), reaching past its words on every side
      // (paint only, `TextBacking`), the words the other way round, in the tag
      // face the table's own "You" is set in everywhere.
      return Padding(
        padding: EdgeInsets.symmetric(horizontal: skin.parts.backingBleed.dx),
        child: TextBacking(
          id: text,
          fill: ink,
          child: FitWords(
            text,
            maxLines: 1,
            style: ((compact ? style : null) ?? skin.typography.tag).copyWith(
              color: ink.computeLuminance() < 0.3
                  ? skin.night.text
                  : skin.night.ground,
            ),
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
