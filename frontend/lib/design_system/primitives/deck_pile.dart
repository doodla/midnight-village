import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../feel/press.dart';
import '../feel/press_paint.dart';
import '../models/role.dart';
import '../skin/dress.dart';
import '../skin/skin.dart';
import '../skin/skin_tilt.dart';
import 'board_pieces.dart';

/// One role of the deck in play (08's square): its card cut from paper, the
/// portrait in a 4:3 window and the role's words on a strip across its foot
/// ([BoardCard]); bone, or the Werewolf team's red. Where the deck holds the
/// role more than once the other copies stand fanned behind it (one to the
/// left, a third to the right) and the words say how many ("3 Villagers").
/// A tap or a hold opens the role ([onOpen]); the pile settles under the
/// finger from the frame it lands ([PressSettle]). The deck is the game's public
/// set-up: nothing here says who holds what. Plain, the card is its words.
class DeckPile extends StatelessWidget {
  const DeckPile({
    super.key,
    required this.role,
    required this.count,
    required this.label,
    required this.portraitWidth,
    required this.stripHeight,
    this.nameOnly = false,
    this.onOpen,
  });

  final RoleId role;
  final int count;

  /// The words on the strip: the role, or how many ("2 Werewolves").
  final String label;

  /// The portrait's width; its window is 4:3.
  final double portraitWidth;

  /// The strip's height (as tall as its words at the phone's text size).
  final double stripHeight;

  /// No portrait: the card is its words on its team's paper (where the
  /// portraits would be too small to read). The card is then as tall as its
  /// strip.
  final bool nameOnly;
  final VoidCallback? onOpen;

  /// How far a copy behind is turned out from the card.
  static const fan = 12 * math.pi / 180;

  /// The card's paper round the portrait.
  static const inset = BoardCard.inset;

  /// The share of the strip that hangs below the portrait.
  static const stripBelow = 0.7;

  /// The front card's size for a portrait [portraitWidth] wide and words
  /// [labelWidth] wide on a strip [stripHeight] tall.
  static Size cardSize(
    double portraitWidth,
    double labelWidth,
    double stripHeight,
  ) => Size(
    math.max(
      portraitWidth + 2 * inset,
      labelWidth + 2 * (BoardCard.stripPad + inset),
    ),
    portraitWidth <= 0
        ? stripHeight + 2 * inset + BoardCard.stripUp
        : inset + portraitWidth * 3 / 4 + stripHeight * stripBelow,
  );

  /// How far the copies behind reach past the card on each side
  /// (left, right).
  static (double, double) reach(Size card, int count) {
    final out = card.height * math.sin(fan) + inset;
    return (count >= 2 ? out : 0, count >= 3 ? out : 0);
  }

  /// The whole pile's size: the card, the copies' reach to the sides, and
  /// below it the corner a turned copy (or the card's own tilt) drops by.
  static Size sizeOf(Size card, int count, {bool nameOnly = false}) {
    final (left, right) = reach(card, count);
    final drop = count >= 2 ? card.width / 2 * math.sin(fan) : 0.0;
    return Size(
      card.width + left + right,
      card.height + drop + inset + rise(card, count, nameOnly: nameOnly),
    );
  }

  /// How far the copies behind lift above the card's top: a name-only card
  /// is wide and short, so a copy turned about its foot lifts its outer
  /// corner by half its width times the fan's sine (a portrait card is tall
  /// enough that the board's margin above takes it).
  static double rise(Size card, int count, {required bool nameOnly}) =>
      nameOnly && count >= 2 ? card.width / 2 * math.sin(fan) : 0.0;

  bool get _red => role.team == TeamId.werewolf;

  @override
  Widget build(BuildContext context) {
    final labelWidth = _measure(context, label);
    final card = cardSize(portraitWidth, labelWidth, stripHeight);
    final (left, right) = reach(card, count);
    final paper = _red ? BoardPaper.werewolfDeck : BoardPaper.winner;
    final rect = Offset.zero & card;
    final tilt = context.skin.tilt.angle(Tilt.seededRow(role.name));
    Widget copy(double angle) => Transform.rotate(
      angle: angle,
      alignment: Alignment.bottomCenter,
      child: BoardCard(
        role: role,
        strip: '',
        paper: paper,
        size: card,
        portraitWidth: nameOnly ? 0 : portraitWidth,
        rect: rect,
        stripHeight: stripHeight,
      ),
    );
    final lift = rise(card, count, nameOnly: nameOnly);
    final pile = SizedBox.fromSize(
      size: sizeOf(card, count, nameOnly: nameOnly),
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (context.dress.isPaper && count >= 2)
            Positioned(left: left, top: lift, child: copy(tilt - fan)),
          if (context.dress.isPaper && count >= 3)
            Positioned(left: left, top: lift, child: copy(tilt + fan)),
          Positioned(
            left: left,
            top: lift,
            child: BoardCard(
              role: role,
              strip: label,
              paper: paper,
              size: card,
              portraitWidth: nameOnly ? 0 : portraitWidth,
              rect: rect,
              angle: tilt,
              stripHeight: stripHeight,
            ),
          ),
        ],
      ),
    );
    return Semantics(
      button: onOpen != null,
      label: label,
      excludeSemantics: true,
      child: Pressable(
        enabled: onOpen != null,
        builder: (context, press, child) =>
            PressSettle(press: press, child: child!),
        child: GestureDetector(
          behavior: HitTestBehavior.opaque,
          onTap: onOpen,
          onLongPress: onOpen,
          child: pile,
        ),
      ),
    );
  }

  static double _measure(BuildContext context, String text) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: context.skin.typography.tag),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width.ceilToDouble();
  }

  /// How wide the words [text] are on a strip at this phone's text size.
  static double labelWidth(BuildContext context, String text) =>
      _measure(context, text);
}
