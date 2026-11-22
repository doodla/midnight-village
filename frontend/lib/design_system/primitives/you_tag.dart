import 'package:flutter/material.dart';

import '../copy/copy.dart';
import '../layout/space.dart';
import '../skin/skin.dart';
import 'fit_line.dart';

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

/// "Practice" beside a practice player's name (a seat the server plays) at
/// the table and in the vote: the same outlined tag as [YouTag], so it reads
/// as who the seat is, never as a role.
class PracticeTag extends StatelessWidget {
  const PracticeTag({super.key, required this.ink});

  /// The colour of the words on what it sits on.
  final Color ink;

  @override
  Widget build(BuildContext context) =>
      _OutlineTag(TableCopy.practice, ink: ink);
}

class _OutlineTag extends StatelessWidget {
  const _OutlineTag(this.text, {required this.ink});

  final String text;
  final Color ink;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
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
