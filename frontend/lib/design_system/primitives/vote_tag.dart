import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../layout/space.dart';
import '../skin/art_set.dart';
import '../skin/dress.dart';
import '../skin/dress_style.dart';
import '../skin/skin.dart';
import 'art_picture.dart';
import 'fit_line.dart';
import 'paper_piece.dart';

/// A name tag that hangs on a twine under the card a player voted for: a tag of
/// bone paper with a punched hole where the twine goes through, the voter's
/// sigil in a small disc, and their name in the name face (16). It is
/// [height] tall and as wide as its name needs; where it is given less room
/// (a card's column) the name is set smaller, down to the label floor, and
/// never cut. On a plain screen it is the sigil and the name, no paper.
class VoteTag extends StatelessWidget {
  const VoteTag({
    super.key,
    required this.name,
    required this.token,
    this.maxWidth,
  });

  final String name;

  /// The voter's sigil; a plain disc when this app does not know it.
  final TokenId? token;

  /// The most it is wide, or null for as wide as its name needs. A name is
  /// never cut: it is set smaller to fit, down to the label floor, and a tag
  /// whose name still does not fit there is as wide as that name needs.
  final double? maxWidth;

  /// How tall the tag is.
  static const height = 28.0;

  /// The sigil's disc.
  static const sigil = 18.0;

  /// The hole the twine goes through.
  static const hole = 6.0;

  /// The room a tag keeps for its hole, sigil and gaps before the name: its
  /// width is this and the name's.
  static const apron = Space.sm + hole + Space.xs + sigil + Space.xs + Space.sm;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final paper = context.dress.isPaper;
    final style = skin.typography.name.copyWith(
      color: paper
          ? PaperPiece.inkOf(context, PaperPart.scrap)
          : context.ground.text,
    );
    final picture = token == null
        ? null
        : ClipOval(child: ArtPicture(skin.art.token(token!)));
    final disc = SizedBox.square(
      dimension: sigil,
      child: DecoratedBox(
        decoration: BoxDecoration(
          shape: BoxShape.circle,
          color: skin.night.panel,
        ),
        child: picture,
      ),
    );
    final words = FitLine(name, style: style);
    final room = maxWidth == null
        ? null
        : math.max(maxWidth! - apron, _widthAtFloor(context, style));
    final content = SizedBox(
      height: height,
      child: Padding(
        padding: const EdgeInsets.only(left: Space.sm, right: Space.sm),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (paper)
              SizedBox.square(
                dimension: hole,
                child: DecoratedBox(
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: context.ground.ground,
                  ),
                ),
              ),
            if (paper) const SizedBox(width: Space.xs),
            disc,
            const SizedBox(width: Space.xs),
            room == null ? words : SizedBox(width: room, child: words),
          ],
        ),
      ),
    );
    final body = paper
        ? PaperPiece(part: PaperPart.scrap, id: name, child: content)
        : content;
    return Semantics(label: name, excludeSemantics: true, child: body);
  }

  /// How wide the name is at the label floor: the least room it can be set in.
  double _widthAtFloor(BuildContext context, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: name, style: style),
      textDirection: Directionality.of(context),
      maxLines: 1,
    )..layout();
    // Text is as wide as it is tall: its width at the floor is its width in
    // its own size, in the floor's share of that size.
    final width = painter.width * ReadingFloor.caption / (style.fontSize ?? 16);
    painter.dispose();
    return width;
  }
}
