import 'package:flutter/widgets.dart';

import 'art_set.dart';
import 'card_back.dart';
import 'skin.dart';

/// Says which back the cards below are drawn with, so every card back drawn
/// below it is that one ([CardBack.forGame] chooses it, once, for a game: the
/// table shell puts one above each screen of a game). Without one, the
/// fallback. No card, token or screen takes a back of its own: this is the
/// only way a back is chosen, which is what keeps one game's cards alike.
class CardBackScope extends InheritedWidget {
  const CardBackScope({super.key, required this.back, required super.child});

  /// The game's back; null for none (the fallback).
  final CardBack? back;

  /// The back drawn at [context].
  static CardBack of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<CardBackScope>()?.back ??
      CardBack.fallback;

  @override
  bool updateShouldNotify(CardBackScope oldWidget) => back != oldWidget.back;
}

extension CardBackContext on BuildContext {
  /// The picture of the card back at this place: the skin's art for the
  /// game's back ([CardBackScope]). Every face-down card is drawn from this.
  ArtImage get cardBack => skin.art.cardBack(CardBackScope.of(this));
}
