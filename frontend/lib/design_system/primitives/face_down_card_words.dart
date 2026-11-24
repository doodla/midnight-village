part of 'face_down_card.dart';

/// The words on a card: a face-up card's role name on its slip, the room the
/// slip takes under the portrait, and the owner's name under the token.
mixin _FaceDownCardWords on State<FaceDownCard> {
  /// The room under a face-up card's portrait that its role slip and the
  /// owner's token take: the token's upper half, the slip's lift and height
  /// (at the size the text size gives it: a longer name only sets smaller) and
  /// a hair, so the slip sits UNDER the portrait and never over the face.
  double _roleFoot(BuildContext context, RoleId role, double cardWidth) {
    final skin = context.skin;
    final dressed = context.dress.isPaper;
    if (!dressed) return 0;
    final base = skin.typography.tag;
    final scale = MediaQuery.textScalerOf(
      context,
    ).scale(1).clamp(1.0, FaceDownCard.roleNameScale);
    final fontSize = base.fontSize! * scale;
    final painter = TextPainter(
      text: TextSpan(
        text: role.displayName,
        style: base.copyWith(fontSize: fontSize),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    final slip = painter.height + 2 * Space.xxs;
    painter.dispose();
    return FaceDownCard.ownerTokenFor(cardWidth) / 2 +
        FaceDownCard.faceNameLift +
        slip +
        Space.xxs;
  }

  /// A face-up card's role name, on a slip of paper across the card's foot,
  /// above the owner's token ([bottom] is the token's height). One line,
  /// whole: at the label size with the text size (as far as
  /// [NightBoard]'s button scale, 1.6), set smaller to fit inside the card
  /// and never under the reading floor (12 drawn). Only where even that is
  /// wider than the card (a long name on the smallest card) does the slip
  /// grow, evenly on both sides, to the word and no further.
  Widget _roleName(
    BuildContext context,
    RoleId role,
    double cardWidth, {
    required double bottom,
  }) {
    final skin = context.skin;
    final ground = context.ground;
    final dressed = context.dress.isPaper;
    final base = (dressed ? skin.typography.tag : skin.typography.caption)
        .copyWith(color: ground.text);
    const padding = EdgeInsets.symmetric(
      horizontal: Space.xxs,
      vertical: Space.xxs,
    );
    final scale = MediaQuery.textScalerOf(
      context,
    ).scale(1).clamp(1.0, FaceDownCard.roleNameScale);
    var size = base.fontSize! * scale;
    TextPainter measure(double fontSize) => TextPainter(
      text: TextSpan(
        text: role.displayName,
        style: base.copyWith(fontSize: fontSize),
      ),
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    var painter = measure(size);
    final room = cardWidth - padding.horizontal;
    if (painter.width > room) {
      final fitted = math.max(
        size * room / painter.width,
        ReadingFloor.caption,
      );
      painter.dispose();
      size = math.min(size, fitted);
      painter = measure(size);
    }
    final style = base.copyWith(fontSize: size);
    final slip = painter.width.ceilToDouble() + padding.horizontal;
    painter.dispose();
    // Dressed up the role is a cut-paper name tag, laid across the card's
    // foot at the same size and in the same room as the slip it replaces.
    if (dressed) {
      return Positioned(
        left: (cardWidth - slip) / 2,
        width: slip,
        bottom: bottom + FaceDownCard.faceNameLift,
        child: TextBacking(
          id: role.name,
          // Neutral navy paper, never a team's colour: a Minion's card must
          // not read as a Werewolf's (red is the Werewolf team's tag alone).
          part: PaperPart.nameTag,
          // The slip's own padding keeps the words in the middle of the plate
          // (the plate's stack would set them at its start edge).
          child: Padding(
            padding: padding,
            child: Text(
              role.displayName,
              maxLines: 1,
              softWrap: false,
              textAlign: TextAlign.center,
              textScaler: TextScaler.noScaling,
              style: style.copyWith(
                color: TextBacking.inkOf(context, part: PaperPart.nameTag),
              ),
            ),
          ),
        ),
      );
    }
    return Positioned(
      left: (cardWidth - slip) / 2,
      width: slip,
      bottom: bottom + FaceDownCard.faceNameLift,
      child: DecoratedBox(
        decoration: cutPaper(
          context,
          fill: ground.paper,
          radius: BorderRadius.circular(skin.shape.radiusTiny),
          elevation: ground.elevation.card,
        ),
        child: Padding(
          padding: padding,
          child: Text(
            role.displayName,
            maxLines: 1,
            softWrap: false,
            textAlign: TextAlign.center,
            textScaler: TextScaler.noScaling,
            style: style,
          ),
        ),
      ),
    );
  }

  /// The owner's name under the token.
  Widget _name(BuildContext context, String name) =>
      widget.youName && context.dress.isPaper
      // "You" is the table's own tag: the tag face, on a plate in the tag's ink.
      ? TextBacking(
          id: name,
          child: FitWords(
            name,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: context.skin.typography.tag.copyWith(
              fontSize: widget.nameSize,
              height: 1,
              color: TextBacking.inkOf(context),
            ),
          ),
        )
      // A player's name over the board is the quiet tag (navy paper, bone
      // words: it never outshouts the dark cards), its plate reaching only a
      // little past the words so neighbours keep a gap (`nameBleed`).
      : TextBacking(
          id: name,
          part: PaperPart.nameTag,
          bleed: const Offset(FaceDownCard.nameBleed, FaceDownCard.nameBleedUp),
          child: FitWords(
            name,
            textAlign: TextAlign.center,
            maxLines: 2,
            style: context.skin.typography.nameSmall.copyWith(
              fontSize: widget.nameSize,
              color: TextBacking.inkOf(context, part: PaperPart.nameTag),
            ),
          ),
        );
}
