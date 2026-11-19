// OLD LOOK: delete when 06 Night action and 09 Vote are rebuilt
@Deprecated(
  'OLD LOOK: delete when 06 Night action and 09 Vote are rebuilt. Build screens from lib/design_system/primitives/ instead.',
)
library;

import 'package:freezed_annotation/freezed_annotation.dart';

part 'player_display.freezed.dart';

enum PlayerStatus { active, eliminated, disconnected }

@freezed
abstract class PlayerDisplay with _$PlayerDisplay {
  const factory PlayerDisplay({
    required String id,
    required String displayName,
    @Default(false) bool isCurrentPlayer,
    @Default(true) bool isSelectable,
    @Default(false) bool isSelected,
    @Default(PlayerStatus.active) PlayerStatus status,
  }) = _PlayerDisplay;
}
