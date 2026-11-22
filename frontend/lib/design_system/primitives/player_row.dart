import 'package:flutter/material.dart';

import '../layout/space.dart';
import '../skin/art_set.dart';
import '../skin/skin.dart';
import '../skin/skin_type.dart';
import '../skin/type_scale.dart';
import 'cut_paper.dart';
import 'fit_line.dart';
import 'player_token.dart';
import 'you_tag.dart';

/// [PlayerRow]'s sizes, from the mocks. Heights are
/// (today, compact, tight): the type-size review's options (`TypeScale`).
enum PlayerRowSize {
  /// At the table (S02): 46 tall, a 32 token, the name at 18 (or the
  /// [PlayerNameSize] above it).
  lobby(
    heights: (46, 40, 38),
    token: TokenSize.lobby,
    gap: Space.smPlus,
    endPadding: Space.smPlus,
    todayNameSize: 18,
  ),

  /// The vote's compact fallback (S09): 52 tall, a 38 token, the name at 21.
  compact(
    heights: (52, 48, 48),
    token: TokenSize.row,
    gap: Space.md,
    endPadding: Space.md,
  ),

  /// In the vote (S09): 68 tall, a 52 token, the name at 26.
  large(
    heights: (68, 56, 52),
    token: TokenSize.vote,
    gap: Space.mdPlus,
    endPadding: Space.lg,
  ),

  /// In the count (S10): 64 tall, a 48 token, the name at 24, the voters'
  /// names under it and a [Tally] at the end.
  count(
    heights: (64, 56, 52),
    token: TokenSize.count,
    gap: Space.md,
    endPadding: Space.mdPlus,
  );

  const PlayerRowSize({
    required this.heights,
    required this.token,
    required this.gap,
    required this.endPadding,
    this.todayNameSize,
  });

  final (double, double, double) heights;

  /// The row's least height at the running scale.
  double get height =>
      TypeScale.pick(today: heights.$1, compact: heights.$2, tight: heights.$3);
  final TokenSize token;

  /// Between the token and the name.
  final double gap;

  /// After the trailing part.
  final double endPadding;

  /// Today's lobby name size, which the shipped scale sets by hand; the other
  /// scales' names are the `name` role itself.
  final double? todayNameSize;

  /// The name's size where it is not a role's own (today's [lobby]).
  double? get nameSize =>
      TypeScale.current == TypeScale.today ? todayNameSize : null;

  TextStyle nameStyle(SkinType type) => switch (this) {
    lobby =>
      nameSize == null ? type.name : type.name.copyWith(fontSize: nameSize),
    compact => type.name,
    large => TypeScale.current == TypeScale.today ? type.title : type.name,
    count => TypeScale.current == TypeScale.today ? type.heading : type.name,
  };
}

/// One name size for every [PlayerRowSize.lobby] row below it: the table's
/// two-up rows all set their names at the size the longest word fits at, so a
/// long name never makes one row's name smaller than its neighbour's.
class PlayerNameSize extends InheritedWidget {
  const PlayerNameSize({super.key, required this.size, required super.child});

  final double size;

  static double? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PlayerNameSize>()?.size;

  @override
  bool updateShouldNotify(PlayerNameSize old) => size != old.size;
}

/// One player as a strip of paper: token, name, an optional [detail] line
/// under the name (who voted for them, by name, S10) and an optional
/// [trailing] part (a [Tally]). With [onTap] it is a button.
///
/// - [picked]: the player's pick lifts and takes the selection's outline
///   (ink by day); never a fill (first-time play spec, copy rule 10).
/// - [own]: the viewer's own row, a thicker outline in the paper's ink and
///   "You" ([YouTag]) after the name (S02, S10).
/// - [practice]: a practice player (a seat the server plays), "Practice"
///   ([PracticeTag]) on the name's line in every row (the name set smaller
///   first, never moved under it); never [own].
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
    this.practice = false,
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
  final bool practice;
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

    final scoped = size == PlayerRowSize.lobby
        ? PlayerNameSize.of(context)
        : null;
    final nameStyle = scoped == null
        ? size.nameStyle(skin.typography)
        : size.nameStyle(skin.typography).copyWith(fontSize: scoped);

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
                  // "You" beside the name where both fit, under it where
                  // not, so a long name keeps its room and a short one its
                  // size.
                  if (own)
                    Wrap(
                      spacing: Space.sm,
                      runSpacing: Space.xxs,
                      crossAxisAlignment: WrapCrossAlignment.center,
                      children: [
                        FitWords(
                          name,
                          maxLines: 2,
                          style: nameStyle.copyWith(color: ink),
                        ),
                        YouTag(ink: ink),
                      ],
                    )
                  // "Practice" always on the name's line, so every row of
                  // a list is laid out alike.
                  else if (practice)
                    Row(
                      spacing: Space.sm,
                      children: [
                        Flexible(
                          child: FitWords(
                            name,
                            maxLines: 2,
                            style: nameStyle.copyWith(color: ink),
                          ),
                        ),
                        PracticeTag(ink: ink),
                      ],
                    )
                  else
                    FitWords(
                      name,
                      maxLines: 2,
                      style: nameStyle.copyWith(color: ink),
                    ),
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
