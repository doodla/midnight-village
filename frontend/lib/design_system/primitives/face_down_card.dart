import 'package:flutter/material.dart';

import '../skin/art_set.dart';
import '../skin/skin.dart';
import 'cut_paper.dart';
import 'player_token.dart';

/// A card lying face down: a player's (with their [owner] token and
/// [ownerName] under it) or a center card. When [selected] it lifts, takes
/// the selection ring and shows [mark] (what tapping it will do: look, swap).
class FaceDownCard extends StatelessWidget {
  const FaceDownCard({
    super.key,
    this.width = 78,
    this.owner,
    this.ownerName,
    this.selected = false,
    this.mark,
    this.semanticLabel,
    this.onTap,
  });

  final double width;
  final TokenId? owner;
  final String? ownerName;
  final bool selected;
  final IconData? mark;
  final String? semanticLabel;
  final VoidCallback? onTap;

  /// Width over height of a card (the mocks' 78 x 106).
  static const aspect = 78 / 106;

  /// The owner's token, which overlaps the card's foot by half.
  static const _tokenSize = 36.0;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final ground = context.ground;
    final radius = BorderRadius.circular(skin.shape.radius);
    final lift = selected ? ground.elevation.selected : ground.elevation.card;
    final back = skin.art.cardBack;

    final card = SizedBox(
      width: width,
      height: width / aspect,
      child: Stack(
        fit: StackFit.expand,
        children: [
          Container(
            decoration: cutPaper(
              context,
              fill: ground.ground,
              radius: radius,
              elevation: lift,
            ),
            foregroundDecoration: ringDecoration(
              color: selected ? ground.selection : ground.hairline,
              width: selected ? skin.shape.selectedRing : skin.shape.ring,
              radius: radius,
            ),
            child: ClipRRect(
              borderRadius: radius,
              child: Image(
                image: back.provider,
                fit: BoxFit.cover,
                alignment: back.focus,
              ),
            ),
          ),
          if (selected && mark != null)
            Center(
              child: Container(
                width: width / 2,
                height: width / 2,
                decoration: BoxDecoration(
                  color: ground.mark,
                  shape: BoxShape.circle,
                  boxShadow: ground.elevation.badge.boxShadows,
                ),
                child: Icon(mark, color: ground.onMark, size: width / 3),
              ),
            ),
        ],
      ),
    );

    return Semantics(
      label: semanticLabel,
      button: onTap != null,
      selected: selected,
      excludeSemantics: semanticLabel != null,
      child: GestureDetector(
        onTap: onTap,
        behavior: HitTestBehavior.opaque,
        child: AnimatedContainer(
          duration: skin.motion.quick,
          curve: skin.motion.curve,
          transform: Matrix4.translationValues(
            0,
            selected ? -skin.spacing.sm : 0,
            0,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              if (owner case final owner?)
                Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(bottom: _tokenSize / 2),
                      child: card,
                    ),
                    Positioned(
                      left: 0,
                      right: 0,
                      bottom: 0,
                      child: Center(
                        child: PlayerToken(
                          owner,
                          size: _tokenSize,
                          ringColor: selected ? ground.selection : null,
                        ),
                      ),
                    ),
                  ],
                )
              else
                card,
              if (ownerName case final name?) ...[
                SizedBox(height: skin.spacing.xxs),
                SizedBox(
                  width: width,
                  child: Text(
                    name,
                    textAlign: TextAlign.center,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: skin.typography.nameSmall.copyWith(
                      color: selected ? ground.selection : ground.text,
                    ),
                  ),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}
