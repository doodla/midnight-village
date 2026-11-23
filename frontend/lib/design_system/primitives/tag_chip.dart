import 'package:flutter/widgets.dart';

import '../layout/space.dart';
import '../models/role.dart';
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
    this.compact = false,
    this.style,
  }) : team = null;

  /// A team's tag: dressed up it is paper of the team's own colour, the same
  /// on every surface and ground (the Werewolf team's red, the Village's blue,
  /// the Tanner's umber, from the skin's parts); plain, the colours it had
  /// (danger for the Werewolf team, the ground's ink for the rest).
  const TagChip.team(
    this.text, {
    super.key,
    required this.team,
    this.small = false,
    this.compact = false,
    this.style,
  }) : tone = team == TeamId.werewolf ? TagTone.danger : TagTone.plain;

  /// A Werewolf-team tag.
  const TagChip.danger(this.text, {super.key, this.small = false})
    : tone = TagTone.danger,
      team = null,
      compact = false,
      style = null;

  final String text;
  final TagTone tone;
  final TeamId? team;
  final bool small;

  /// Tight round its words (a role's name laid on a card's foot, in the room
  /// of the card).
  final bool compact;

  /// A compact tag's words in exactly this style, on one line, never scaled
  /// again (the caller has fitted them to the room).
  final TextStyle? style;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final ground = context.ground;
    final parts = skin.parts;
    final teamPaper = context.dress.isPaper ? team : null;
    final (fill, ink) = switch (teamPaper) {
      TeamId.werewolf => (parts.werewolfTag, parts.onTeamTag),
      TeamId.village => (parts.villageTag, parts.onTeamTag),
      TeamId.independent => (parts.tannerTag, parts.onTeamTag),
      null => switch (tone) {
        TagTone.plain => (ground.text, ground.ground),
        TagTone.danger => (ground.danger, ground.onDanger),
        TagTone.ground => (ground.ground, ground.text),
      },
    };
    final padding = compact
        ? const EdgeInsets.symmetric(horizontal: 4, vertical: 3)
        : small
        ? const EdgeInsets.symmetric(horizontal: Space.smPlus, vertical: 5)
        : const EdgeInsets.symmetric(
            horizontal: Space.smPlus,
            vertical: Space.xs,
          );
    final face = (small ? skin.typography.badge : skin.typography.tag).copyWith(
      color: ink,
    );
    final words = compact && style != null
        ? Text(
            text,
            maxLines: 1,
            softWrap: false,
            textScaler: TextScaler.noScaling,
            textAlign: TextAlign.center,
            style: style!.copyWith(color: ink),
          )
        : FitWords(text, style: face);
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
