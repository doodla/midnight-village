import 'package:flutter/widgets.dart';

import '../layout/space.dart';
import '../skin/art_set.dart';
import '../skin/dress.dart';
import '../skin/dress_style.dart';
import '../skin/skin.dart';
import 'art_picture.dart';
import 'fit_line.dart';
import 'paper_piece.dart';
import 'you_seal.dart';

/// A player in the square (08): a tag of bone paper with their sigil (the
/// same on every phone and every screen) and their name in the name face (16),
/// set down a hair off square. Your own tag carries your wax seal ([YouSeal])
/// where the sigil is. As wide as the name needs; where it is given less room
/// the name is set smaller ([FitLine]), never cut. It is not a button: a tap
/// does nothing. Plain, it is the sigil and the name, no paper.
class NameTag extends StatelessWidget {
  const NameTag({
    super.key,
    required this.name,
    required this.token,
    this.you = false,
  });

  final String name;

  /// The player's sigil; a plain disc when this app does not know it.
  final TokenId? token;

  /// This phone's own player: the wax seal instead of the sigil.
  final bool you;

  /// The tag's least height (it grows with the text).
  static const height = 32.0;

  /// The sigil's disc, and the seal on your own tag.
  static const sigil = 22.0;
  static const seal = 26.0;

  /// The room a tag keeps beside its name: its width is this and the name's.
  static const apron = Space.sm + seal + Space.xs + Space.md;

  /// How wide a tag for [name] is, at [style] (the name face) and [scaler].
  static double widthOf(String name, TextStyle style, TextScaler scaler) {
    final painter = TextPainter(
      text: TextSpan(text: name, style: style),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
      maxLines: 1,
    )..layout();
    final width = painter.width;
    painter.dispose();
    return (apron + width).ceilToDouble();
  }

  /// How tall a tag is at [style] and [scaler].
  static double heightOf(TextStyle style, TextScaler scaler) {
    final painter = TextPainter(
      text: TextSpan(text: ' ', style: style),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
      maxLines: 1,
    )..layout();
    final line = painter.height;
    painter.dispose();
    return line + 2 * Space.xs > height ? line + 2 * Space.xs : height;
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final paper = context.dress.isPaper;
    final style = skin.typography.name.copyWith(
      color: paper
          ? PaperPiece.inkOf(context, PaperPart.scrap)
          : context.ground.text,
    );
    final mark = you
        ? YouSeal(token: token, size: seal)
        : SizedBox.square(
            dimension: sigil,
            child: DecoratedBox(
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                color: skin.night.panel,
              ),
              child: token == null
                  ? null
                  : ClipOval(child: ArtPicture(skin.art.token(token!))),
            ),
          );
    final content = ConstrainedBox(
      constraints: BoxConstraints(
        minHeight: heightOf(style, MediaQuery.textScalerOf(context)),
      ),
      child: Padding(
        padding: const EdgeInsets.only(left: Space.sm, right: Space.md),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            SizedBox(
              width: seal,
              child: Center(child: mark),
            ),
            const SizedBox(width: Space.xs),
            Flexible(child: FitLine(name, style: style)),
          ],
        ),
      ),
    );
    return Semantics(
      label: name,
      excludeSemantics: true,
      child: paper
          ? PaperPiece(part: PaperPart.scrap, id: name, child: content)
          : content,
    );
  }
}
