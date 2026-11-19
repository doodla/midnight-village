import 'package:flutter/material.dart';

import '../skin/art_set.dart';
import '../skin/skin.dart';
import 'cut_paper.dart';
import 'player_token.dart';

/// [PlayerRow]'s two sizes: the table list, and the vote.
enum PlayerRowSize {
  compact(height: 52, token: 38),
  large(height: 68, token: 52);

  const PlayerRowSize({required this.height, required this.token});

  final double height;
  final double token;
}

/// One player as a strip of paper: token, name, and an optional [trailing]
/// part (a note, the voters' tokens, a count). [picked] fills it with "your
/// pick". With [onTap] it is a button.
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

  final TokenId token;
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
    final lead = skin.shape.corner(
      size.height,
      skin.shape.rowLeadRoundness,
      square: skin.shape.radius,
    );
    final radius = BorderRadius.horizontal(
      left: Radius.circular(lead),
      right: Radius.circular(skin.shape.radius),
    );
    final type = skin.typography;

    final row = AnimatedContainer(
      duration: skin.motion.quick,
      constraints: BoxConstraints(minHeight: size.height),
      padding: EdgeInsets.fromLTRB(
        skin.spacing.sm,
        skin.spacing.xxs,
        skin.spacing.lg,
        skin.spacing.xxs,
      ),
      decoration: cutPaper(
        context,
        fill: picked ? ground.pick : ground.paper,
        radius: radius,
        elevation: picked ? ground.elevation.selected : ground.elevation.card,
      ),
      child: Row(
        children: [
          PlayerToken(token, size: size.token, ringColor: ink),
          SizedBox(width: skin.spacing.md),
          Expanded(
            child: Text(
              name,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: (size == PlayerRowSize.large ? type.title : type.name)
                  .copyWith(color: ink),
            ),
          ),
          if (trailing case final trailing?)
            DefaultTextStyle(
              style: type.label.copyWith(
                color: picked ? ground.onPick : skin.paper.quietText,
              ),
              child: IconTheme.merge(
                data: IconThemeData(color: ink),
                child: trailing,
              ),
            ),
        ],
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
