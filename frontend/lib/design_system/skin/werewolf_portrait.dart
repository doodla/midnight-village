import 'package:flutter/widgets.dart';

import '../models/role.dart';
import 'art_set.dart';
import 'card_back.dart';
import 'skin.dart';

/// The Werewolf's three portraits. One is drawn for a whole game
/// ([WerewolfPortrait.forGame]), the same on every phone and for both
/// Werewolves; outside a game it is [fallback].
enum WerewolfPortrait {
  /// Mid-lunge, jaws wide, a claw reaching out. The one outside a game.
  lunge('lunge'),

  /// Still, mouth shut, the cold stare.
  stare('stare'),

  /// Head low between the shoulders, snarling.
  snarl('snarl');

  const WerewolfPortrait(this.fileName);

  /// The picture's name in the skin's `roles/` folder after `werewolf_`.
  final String fileName;

  static const fallback = lunge;

  /// The portrait for the game [gameId], or [fallback] for no game.
  ///
  /// Chosen like the card back (`CardBack.forGame`): from the game's id, which
  /// every player holds, so it is the same on every phone and tells nothing
  /// about any role. A salt keeps the wolf and the back from moving together.
  static WerewolfPortrait forGame(String? gameId) {
    if (gameId == null || gameId.isEmpty) return fallback;
    return values[gameHash(gameId, '#werewolf') % values.length];
  }
}

/// Says which Werewolf portrait the roles below are drawn with (the table
/// shell puts one above each screen of a game, beside `CardBackScope`).
/// Without one, the fallback.
class WerewolfPortraitScope extends InheritedWidget {
  const WerewolfPortraitScope({
    super.key,
    required this.portrait,
    required super.child,
  });

  /// The game's portrait; null for none (the fallback).
  final WerewolfPortrait? portrait;

  static WerewolfPortrait of(BuildContext context) =>
      context
          .dependOnInheritedWidgetOfExactType<WerewolfPortraitScope>()
          ?.portrait ??
      WerewolfPortrait.fallback;

  @override
  bool updateShouldNotify(WerewolfPortraitScope oldWidget) =>
      portrait != oldWidget.portrait;
}

extension RoleArtContext on BuildContext {
  /// [role]'s portrait at this place: the skin's art, the game's Werewolf
  /// ([WerewolfPortraitScope]). Every role portrait is drawn from this.
  ArtImage roleArt(RoleId role) =>
      skin.art.role(role, wolf: WerewolfPortraitScope.of(this));
}
