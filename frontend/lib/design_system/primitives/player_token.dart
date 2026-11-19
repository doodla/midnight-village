import 'package:flutter/widgets.dart';

import '../skin/art_set.dart';
import '../skin/skin.dart';
import 'cut_paper.dart';

/// A player's emblem: a small cut-paper medallion in a ring. [dimmed] for a
/// player who has not done the thing being counted yet. The ring takes the
/// ground's text colour unless [ringColor] says otherwise.
class PlayerToken extends StatelessWidget {
  const PlayerToken(
    this.token, {
    super.key,
    this.size = 38,
    this.dimmed = false,
    this.ringColor,
  });

  final TokenId token;
  final double size;
  final bool dimmed;
  final Color? ringColor;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final ground = context.ground;
    final radius = BorderRadius.circular(
      skin.shape.corner(size, skin.shape.tokenRoundness),
    );
    final emblem = switch (skin.art.token(token)) {
      TokenPicture(:final image) => Image(
        image: image.provider,
        fit: BoxFit.cover,
        alignment: image.focus,
      ),
      TokenFallback(:final initials) => _Fallback(
        initials: initials,
        size: size,
      ),
    };
    return ExcludeSemantics(
      child: Opacity(
        opacity: dimmed ? skin.dimmed : 1,
        child: Container(
          width: size,
          height: size,
          foregroundDecoration: ringDecoration(
            color: ringColor ?? (dimmed ? ground.quietText : ground.text),
            width: skin.shape.ring,
            radius: radius,
          ),
          child: ClipRRect(borderRadius: radius, child: emblem),
        ),
      ),
    );
  }
}

/// A token not drawn yet: a night-coloured disc with the token's letters, so
/// a table of ten is still told apart.
class _Fallback extends StatelessWidget {
  const _Fallback({required this.initials, required this.size});

  final String initials;
  final double size;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return ColoredBox(
      color: skin.night.panel,
      child: Center(
        child: Text(
          initials,
          style: skin.typography.heading.copyWith(
            color: skin.night.text,
            fontSize: size * 0.42,
            height: 1,
          ),
        ),
      ),
    );
  }
}
