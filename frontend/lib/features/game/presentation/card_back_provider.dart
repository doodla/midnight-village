import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../design_system/skin/card_back.dart';

part 'card_back_provider.g.dart';

/// The card back of game [gameId]: one for the whole game and every phone at
/// the table (`CardBack.forGame`, from the game's id). A provider only so the
/// screen gallery can pin it (`test_screens/`); nothing else overrides it.
@riverpod
CardBack gameCardBack(Ref ref, String gameId) => CardBack.forGame(gameId);
