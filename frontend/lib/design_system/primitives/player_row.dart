import 'package:flutter/material.dart';

import '../layout/space.dart';
import '../skin/art_set.dart';
import '../skin/skin.dart';
import '../skin/skin_type.dart';
import 'cut_paper.dart';
import 'player_token.dart';

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

  /// In the count (S10): 64 tall, a 48 token, the name at 24, the voters and
  /// a [Tally] at the end.
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

/// One player as a strip of paper: token, name, and an optional [trailing]
/// part (a [RowNote], [VoterTokens] and a [Tally], an icon). [picked] fills it
/// with "your pick" (or the dead player). With [onTap] it is a button.
///
/// The trailing part keeps its own type; it gets the row's ink as the colour
/// of plain text and icons.
class PlayerRow extends StatelessWidget {
  const PlayerRow({
    super.key,
    required this.token,
    required this.name,
    this.trailing,
    this.picked = false,
    this.onTap,
    this.size = PlayerRowSize.compact,
  });

  final TokenId? token;
  final String name;
  final Widget? trailing;
  final bool picked;
  final VoidCallback? onTap;
  final PlayerRowSize size;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final ground = context.ground;
    final ink = picked ? ground.onPick : skin.paper.text;
    final quiet = picked ? ground.onPick : skin.paper.quietText;
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
      padding: EdgeInsets.fromLTRB(
        Space.sm,
        Space.xxs,
        size.endPadding,
        Space.xxs,
      ),
      decoration: cutPaper(
        context,
        fill: picked ? ground.pick : ground.paper,
        radius: radius,
        elevation: picked ? ground.elevation.selected : ground.elevation.card,
      ),
      child: _RowInk(
        ink: ink,
        quiet: quiet,
        child: Row(
          spacing: size.gap,
          children: [
            PlayerToken(token, size: size.token, ringColor: ink),
            Expanded(
              child: Text(
                name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: size.nameStyle(skin.typography).copyWith(color: ink),
              ),
            ),
            if (trailing case final trailing?)
              DefaultTextStyle.merge(
                style: TextStyle(color: ink),
                child: IconTheme.merge(
                  data: IconThemeData(color: ink),
                  child: trailing,
                ),
              ),
          ],
        ),
      ),
    );
    if (onTap == null) return row;
    return Semantics(
      button: true,
      selected: picked,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: radius,
          highlightColor: Colors.transparent,
          child: row,
        ),
      ),
    );
  }
}

class _RowInk extends InheritedWidget {
  const _RowInk({required this.ink, required this.quiet, required super.child});

  final Color ink;
  final Color quiet;

  static _RowInk? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_RowInk>();

  @override
  bool updateShouldNotify(_RowInk old) => ink != old.ink || quiet != old.quiet;
}

/// A short note at the end of a [PlayerRow] ("Host · you"), as a label.
class RowNote extends StatelessWidget {
  const RowNote(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text.toUpperCase(),
    maxLines: 1,
    style: context.skin.typography.label.copyWith(
      color: _RowInk.of(context)?.quiet ?? context.ground.quietText,
    ),
  );
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
