import 'package:freezed_annotation/freezed_annotation.dart';

import '../../../core/host/host_change.dart';

part 'lobby_state.freezed.dart';

/// A player in a lobby.
///
/// Serialized from the backend's nested player format:
/// ```json
/// { "user": {"id": 1, "display_name": "Alice"}, "is_ready": true, "joined_at": "..." }
/// ```
@freezed
abstract class LobbyPlayer with _$LobbyPlayer {
  const factory LobbyPlayer({
    required int id,
    required String displayName,
    required bool isReady,
    required DateTime joinedAt,
  }) = _LobbyPlayer;

  /// Parses the backend's nested player format.
  factory LobbyPlayer.fromJson(Map<String, dynamic> json) {
    // Backend returns { "user": {"id": ..., "display_name": ...}, "is_ready": ..., "joined_at": ... }
    final user = json['user'] as Map<String, dynamic>;
    return LobbyPlayer(
      id: user['id'] as int,
      displayName: user['display_name'] as String,
      isReady: json['is_ready'] as bool,
      joinedAt: DateTime.parse(json['joined_at'] as String),
    );
  }
}

/// The state of a lobby, including players, settings, and status.
///
/// Serialized from the backend's LobbyResponse format.
@freezed
abstract class LobbyState with _$LobbyState {
  const factory LobbyState({
    required String code,
    required int hostId,
    required List<LobbyPlayer> players,
    required String status,
    required int maxPlayers,
    @Default({}) Map<String, int> roleConfig,

    /// The game this table has just started (from `game_started`, or found in
    /// the player's current game). The screen opens it. A table can run
    /// several games one after another, so each start sets a new id.
    String? startedGameId,

    /// Display name of the effective host (the lobby's `host`).
    String? hostName,

    /// The host who set the table up. [hostId] is the effective host, who may
    /// be someone else while the original host's phone is away.
    int? originalHostId,

    /// True while someone other than the original host is hosting.
    @Default(false) bool isActingHost,

    /// The "Ana is hosting again" line, shown for a few seconds after the
    /// role returns. Frontend only.
    HostChange? returnedNotice,

    /// A plain line about a host action refused because the role had moved.
    /// Frontend only.
    String? hostActionNotice,
  }) = _LobbyState;

  /// Parses the backend's LobbyResponse format.
  factory LobbyState.fromJson(Map<String, dynamic> json) {
    final host = json['host'] as Map<String, dynamic>;
    final playersJson = json['players'] as List<dynamic>;
    final settings = json['settings'] as Map<String, dynamic>?;
    final roles = settings?['roles'] as Map<String, dynamic>?;

    return LobbyState(
      code: json['code'] as String,
      hostId: host['id'] as int,
      players: playersJson
          .map((p) => LobbyPlayer.fromJson(p as Map<String, dynamic>))
          .toList(),
      status: json['status'] as String,
      maxPlayers: json['max_players'] as int,
      roleConfig: roles?.map((k, v) => MapEntry(k, v as int)) ?? {},
      // `host` is the effective host. Both extra fields are optional.
      hostName: host['display_name'] as String?,
      originalHostId: json['original_host_id'] as int?,
      isActingHost: json['is_acting_host'] == true,
    );
  }
}
