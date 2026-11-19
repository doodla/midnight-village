import 'package:flutter/widgets.dart';

import '../layout/space.dart';
import '../skin/art_set.dart';
import '../skin/skin.dart';
import 'art_picture.dart';
import 'cut_paper.dart';

/// The sizes a token is drawn at in the mocks.
enum TokenSize {
  /// Progress pips at night, "waiting for Dev" (S05, S07).
  waiting(26),

  /// Progress pips by day (S08, S09).
  pip(30),

  /// A voter beside the accused (S10).
  voter(34),

  /// The owner under a face-down card (S06).
  card(36),

  /// A row at the table (S02).
  row(38),

  /// Beside a heading ("Cleo's card", S07).
  header(44),

  /// A row in the count (S10).
  count(48),

  /// A row in the vote (S09).
  vote(52),

  /// The dead player in the count's band (S10).
  band(64);

  const TokenSize(this.size);

  final double size;
}

/// A player's emblem: a small cut-paper medallion in a ring. [waiting] for a
/// player who has not done the thing being counted yet (faded, in the
/// ground's idle ring). The ring takes the ground's text colour unless
/// [ringColor] says otherwise. A token this app does not know (null: a newer
/// server's) is a plain disc.
class PlayerToken extends StatelessWidget {
  const PlayerToken(
    this.token, {
    super.key,
    this.size = TokenSize.row,
    this.waiting = false,
    this.ringColor,
  });

  final TokenId? token;
  final TokenSize size;
  final bool waiting;
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
        opacity: waiting ? skin.waiting : 1,
        child: Container(
          width: side,
          height: side,
          foregroundDecoration: ringDecoration(
            color: ringColor ?? (waiting ? ground.idle : ground.text),
            width: skin.shape.ring,
            radius: radius,
          ),
          child: ClipRRect(borderRadius: radius, child: emblem),
        ),
      ),
    );
  }
}

/// The tokens of the players who voted for someone, in a row (S10).
class VoterTokens extends StatelessWidget {
  const VoterTokens(this.tokens, {super.key, this.ringColor});

  final List<TokenId?> tokens;
  final Color? ringColor;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: Space.xs,
    runSpacing: Space.xs,
    children: [
      for (final token in tokens)
        PlayerToken(token, size: TokenSize.voter, ringColor: ringColor),
    ],
  );
}
