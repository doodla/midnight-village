import 'package:flutter/widgets.dart';

import '../layout/space.dart';
import '../skin/dress.dart';
import '../skin/skin.dart';
import '../skin/dress_style.dart';
import 'paper_piece.dart';
import 'fit_line.dart';

/// What a [TagChip] is printed in.
enum TagTone {
  /// The ground inverted: its text colour as the fill ("Village team").
  plain,

  /// Danger: the Werewolf team.
  danger,

  /// The ground's own colours, for a tag on a coloured band ("Cleo held the
  /// Robber" on the winner's band, S11).
  ground,
}

/// A short tag ("Village team"). [small] is the sheet's (S03b, 12 px);
/// the regular one is the card's (S04, S10, 13 px).
class TagChip extends StatelessWidget {
  const TagChip(
    this.text, {
    super.key,
    this.tone = TagTone.plain,
    this.small = false,
  });

  /// A Werewolf-team tag.
  const TagChip.danger(this.text, {super.key, this.small = false})
    : tone = TagTone.danger;

  final String text;
  final TagTone tone;
  final bool small;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final ground = context.ground;
    final (fill, ink) = switch (tone) {
      TagTone.plain => (ground.text, ground.ground),
      TagTone.danger => (ground.danger, ground.onDanger),
      TagTone.ground => (ground.ground, ground.text),
    };
    final padding = small
        ? const EdgeInsets.symmetric(horizontal: Space.smPlus, vertical: 5)
        : const EdgeInsets.symmetric(
            horizontal: Space.smPlus,
            vertical: Space.xs,
          );
    final words = FitWords(
      text,
      style: (small ? skin.typography.badge : skin.typography.tag).copyWith(
        color: ink,
      ),
    );
    final radius = BorderRadius.circular(skin.shape.radiusTiny);
    // Dressed up: a cut-paper tag (a [PaperPiece]) set down by hand, its word
    // level.
    if (context.dress.isPaper) {
      return PaperPiece(
        part: PaperPart.tag,
        id: text,
        fill: fill,
        child: Padding(padding: padding, child: words),
      );
    }
    return Container(
      padding: padding,
      decoration: BoxDecoration(color: fill, borderRadius: radius),
      child: words,
    );
  }
}
