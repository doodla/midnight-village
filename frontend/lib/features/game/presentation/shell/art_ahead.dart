import 'package:flutter/widgets.dart';

import '../../../../design_system/primitives/scene_switcher.dart';
import '../../../../design_system/skin/art_set.dart';
import '../../../lobby/presentation/deck_screen.dart';
import '../../domain/screen_table.dart';

/// The art of what comes next, decoded while the player is on the screen
/// before it: a screen opens on pictures already decoded, at the size it
/// draws them, and its first frame is not the one that decodes them.
///
/// One table says what can come after each screen ([comesNext]), and one
/// says what each screen draws ([artOf], from the screen's own code: the
/// same box its pictures are decoded for). The shell asks for both each time
/// a screen shows (`TableShell`), never awaited: no screen waits for it, and
/// a picture already decoded costs nothing.
///
/// The secrets' pictures (every portrait at the sizes a held face and the
/// strips draw them, the card back in use) are decoded at start and when a
/// game is named (`secretArt`, `precacheCardBack`), so no reveal fetches.
abstract final class ArtAhead {
  /// The screens that can come after each one, the likeliest first.
  static const comesNext = <AppScreen, List<AppScreen>>{
    AppScreen.join: [AppScreen.table],
    AppScreen.table: [AppScreen.deck, AppScreen.yourCard],
    AppScreen.deck: [AppScreen.table],
    AppScreen.yourCard: [AppScreen.nightBoard, AppScreen.talk],
    AppScreen.nightBoard: [AppScreen.talk],
    AppScreen.talk: [AppScreen.vote],
    AppScreen.vote: [AppScreen.end],
    AppScreen.end: [AppScreen.table],
  };

  /// What [screen] draws on a phone like [context]'s, as it decodes it.
  /// A screen whose pictures are all secrets or come with its header is
  /// empty here.
  static List<ImageProvider> artOf(BuildContext context, AppScreen screen) =>
      switch (screen) {
        AppScreen.deck => deckArt(context),
        // 04's village, the header the dusk brings down.
        AppScreen.yourCard || AppScreen.nightBoard => SceneSwitcher.headerArt(
          context,
          LayeredSceneId.nightVillage,
        ),
        // 08's dawn, the header the dawn brings up; the end board stands
        // under the same square.
        AppScreen.talk || AppScreen.vote || AppScreen.end =>
          SceneSwitcher.headerArt(context, LayeredSceneId.dawnGallows),
        AppScreen.join || AppScreen.table => const [],
      };

  /// Decodes the art of every screen that can come after [shown]. Not
  /// awaited; a picture that fails costs that picture.
  static void warm(BuildContext context, AppScreen shown) {
    for (final next in comesNext[shown] ?? const <AppScreen>[]) {
      for (final image in artOf(context, next)) {
        precacheImage(image, context, onError: (_, _) {});
      }
    }
  }
}
