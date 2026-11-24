part of '../screen_catalogue.dart';

/// Screen 03b's states (one file per screen, so two screens' work never
/// meets in one file). In the gallery's order within the screen.
final _pages03b = <ScreenEntry>[
  ..._rebuilt('03b-deck-role', '03b-deck-role-explained.png', {
    '': const _NoMain(_sheet, pumpDeckRole),
    // The Werewolf's card sheet with no game (the lunge), as a player sees it
    // before a table is dealt.
    '-werewolf-no-game': const _NoMain(_sheet, pumpDeckRoleWerewolf),
  }),
];
