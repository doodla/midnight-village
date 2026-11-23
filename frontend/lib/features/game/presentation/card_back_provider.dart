import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../design_system/skin/card_back.dart';
import '../../../design_system/skin/werewolf_portrait.dart';

part 'card_back_provider.g.dart';

/// The card back of game [gameId]: one for the whole game and every phone at
/// the table (`CardBack.forGame`, from the game's id). A provider only so the
/// screen gallery can pin it (`test_screens/`); nothing else overrides it.
@riverpod
CardBack gameCardBack(Ref ref, String gameId) => CardBack.forGame(gameId);

/// The Werewolf's portrait in game [gameId]: one for the whole game and every
/// phone at the table (`WerewolfPortrait.forGame`, from the game's id). A
/// provider only so the screen gallery can pin it.
@riverpod
WerewolfPortrait gameWerewolfPortrait(Ref ref, String gameId) =>
    WerewolfPortrait.forGame(gameId);
