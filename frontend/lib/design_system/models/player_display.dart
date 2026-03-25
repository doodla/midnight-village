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
