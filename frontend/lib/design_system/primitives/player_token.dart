import 'package:flutter/widgets.dart';

import '../skin/art_set.dart';
import '../skin/skin.dart';
import 'art_picture.dart';
import 'cut_paper.dart';

/// The sizes a token is drawn at: the mocks', shrunk with the names (the
/// owner's type choice of 23 November 2026).
enum TokenSize {
  /// The owner under a face-down card (S06).
  card(36),

  /// A row in the vote's compact fallback (S09).
  row(32),

  /// A row at the table (S02).
  lobby(26),

  /// A row in the count (S10).
  count(34),

  /// A row in the vote (S09).
  vote(38),

  /// The dead player in the count's band (S10).
  band(64);

  const TokenSize(this.size);

  final double size;
}

/// A player's emblem: a small cut-paper medallion in a ring. [away] for a
/// member whose phone has dropped: dimmed, in the ground's idle ring, with no
/// words (first-time play spec, 02). The ring takes the ground's text colour
/// unless [ringColor] says otherwise. A token this app does not know (null:
/// a newer server's) is a plain disc.
class PlayerToken extends StatelessWidget {
  const PlayerToken(
    this.token, {
    super.key,
    this.size = TokenSize.row,
    this.away = false,
    this.ringColor,
  });

  final TokenId? token;
  final TokenSize size;
  final bool away;
  final Color? ringColor;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final ground = context.ground;
    final side = size.size;
    final radius = BorderRadius.circular(
      skin.shape.corner(side, skin.shape.tokenRoundness),
    );
    final token = this.token;
    final emblem = token == null
        ? ColoredBox(color: skin.night.panel)
        : ArtPicture(skin.art.token(token));
    return ExcludeSemantics(
      child: Opacity(
        opacity: away ? skin.dimmed : 1,
        child: Container(
          width: side,
          height: side,
          foregroundDecoration: ringDecoration(
            color: ringColor ?? (away ? ground.idle : ground.text),
            width: skin.shape.ring,
            radius: radius,
          ),
          child: ClipRRect(borderRadius: radius, child: emblem),
        ),
      ),
    );
  }
}
