import 'package:flutter/material.dart';

import '../layout/space.dart';
import '../skin/art_set.dart';
import '../skin/skin.dart';
import '../skin/skin_type.dart';
import 'cut_paper.dart';
import 'fit_line.dart';
import 'player_token.dart';
import 'you_tag.dart';

/// [PlayerRow]'s sizes, from the mocks.
enum PlayerRowSize {
  /// At the table (S02): 52 tall, a 38 token, the name at 21.
  compact(
    height: 52,
    token: TokenSize.row,
    gap: Space.md,
    endPadding: Space.md,
  ),

  /// In the vote (S09): 68 tall, a 52 token, the name at 26.
  large(
    height: 68,
    token: TokenSize.vote,
    gap: Space.mdPlus,
    endPadding: Space.lg,
  ),

  /// In the count (S10): 64 tall, a 48 token, the name at 24, the voters'
  /// names under it and a [Tally] at the end.
  count(
    height: 64,
    token: TokenSize.count,
    gap: Space.md,
    endPadding: Space.mdPlus,
  );

  const PlayerRowSize({
    required this.height,
    required this.token,
    required this.gap,
    required this.endPadding,
  });

  final double height;
  final TokenSize token;

  /// Between the token and the name.
  final double gap;

  /// After the trailing part.
  final double endPadding;

  TextStyle nameStyle(SkinType type) => switch (this) {
    compact => type.name,
    large => type.title,
    count => type.heading,
  };
}

/// One player as a strip of paper: token, name, an optional [detail] line
/// under the name (who voted for them, by name, S10) and an optional
/// [trailing] part (a [Tally]). With [onTap] it is a button.
///
/// - [picked]: the player's pick lifts and takes the selection's outline
///   (ink by day); never a fill (first-time play spec, copy rule 10).
/// - [own]: the viewer's own row, a thicker outline in the paper's ink and
///   "You" ([YouTag]) after the name (S02, S10).
/// - [away]: a dropped member, the token dimmed, with no words (S02).
/// - [dimmed]: the vote once locked, where every row dims the same and none
///   shows the pick (S09).
class PlayerRow extends StatelessWidget {
  const PlayerRow({
    super.key,
    required this.token,
    required this.name,
    this.detail,
    this.trailing,
    this.picked = false,
    this.own = false,
    this.away = false,
    this.dimmed = false,
    this.onTap,
    this.size = PlayerRowSize.compact,
  });

  final TokenId? token;
  final String name;
  final String? detail;
  final Widget? trailing;
  final bool picked;
  final bool own;
  final bool away;
  final bool dimmed;
  final VoidCallback? onTap;
  final PlayerRowSize size;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final ground = context.ground;
    final ink = skin.paper.text;
    final lead = skin.shape.corner(
      size.height,
      skin.shape.rowLeadRoundness,
      square: skin.shape.radius,
    );
    final radius = BorderRadius.horizontal(
      left: Radius.circular(lead),
      right: Radius.circular(skin.shape.radius),
    );

    final row = AnimatedContainer(
      duration: Motion.quick,
      curve: Motion.curve,
      constraints: BoxConstraints(minHeight: size.height),
      transform: Matrix4.translationValues(0, picked ? -Space.xs : 0, 0),
      padding: EdgeInsets.fromLTRB(
        Space.sm,
        Space.xxs,
        size.endPadding,
        Space.xxs,
      ),
      decoration: cutPaper(
        context,
        fill: ground.paper,
        radius: radius,
        elevation: picked ? ground.elevation.selected : ground.elevation.card,
      ),
      foregroundDecoration: picked
          ? ringDecoration(
              color: ground.selection,
              width: skin.shape.selectedRing,
              radius: radius,
            )
          : own
          ? BoxDecoration(
              borderRadius: radius,
              border: Border.all(color: ink, width: skin.shape.selectedRing),
            )
          : null,
      child: _RowInk(
        ink: ink,
        child: Row(
          spacing: size.gap,
          children: [
            PlayerToken(token, size: size.token, ringColor: ink, away: away),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // A long name wraps between words, then is set smaller;
                  // never cut short.
                  FitWords(
                    name,
                    maxLines: 2,
                    style: size.nameStyle(skin.typography).copyWith(color: ink),
                  ),
                  // Under the name, so a long name keeps its room.
                  if (own) YouTag(ink: ink),
                  // Names wrap between words, never inside one.
                  if (detail case final detail?)
                    FitWords(
                      detail,
                      style: skin.typography.body.copyWith(
                        color: skin.paper.quietText,
                      ),
                    ),
                ],
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
    final shown = AnimatedOpacity(
      duration: Motion.quick,
      opacity: dimmed ? skin.dimmed : 1,
      child: row,
    );
    // Once locked (dimmed) a row cannot be picked: it reads as switched off.
    if (dimmed) return Semantics(enabled: false, child: shown);
    if (onTap == null) return shown;
    return Semantics(
      button: true,
      selected: picked,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          highlightColor: Colors.transparent,
          splashColor: Colors.transparent,
          child: shown,
        ),
      ),
    );
  }
}

class _RowInk extends InheritedWidget {
  const _RowInk({required this.ink, required super.child});

  final Color ink;

  static _RowInk? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_RowInk>();

  @override
  bool updateShouldNotify(_RowInk old) => ink != old.ink;
}

/// The number of votes at the end of a count row (S10).
class Tally extends StatelessWidget {
  const Tally(this.count, {super.key});

  final int count;

  @override
  Widget build(BuildContext context) => Text(
    '$count',
    textAlign: TextAlign.end,
    style: context.skin.typography.tally.copyWith(
      color: _RowInk.of(context)?.ink ?? context.ground.text,
    ),
  );
}
