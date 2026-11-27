import 'dart:convert';

import 'contract/contract_samples.dart';
import 'contract/contract_shape.dart';
import 'contract/server_json.dart';

/// Socket events as the server sends them, for [MockWebSocketChannel.addServerEvent].
///
/// Each starts from the recorded event (`contract_samples/ws/`) and lets a test
/// choose its values; the result is checked against the samples. There is no
/// factory for what the server never sends (a `phase_change` to the night, a
/// results `votes` list, anything but the type in `player_joined`).
abstract final class GameEvents {
  static String _event(String sample, Map<String, dynamic> values) {
    final event = withValues(ContractSamples.map(sample), values);
    checkSocketEvent(event);
    return jsonEncode(event);
  }

  // ---------------------------------------------------------------------------
  // Phases
  // ---------------------------------------------------------------------------

  /// The talk or the vote starts. The server sends `phase_change` for these
  /// two only: the night opens with `night_window`, the end comes as
  /// `game_results`.
  static String phaseChange({required String phase, String? deadline}) {
    if (phase != 'discussion' && phase != 'voting') {
      throw ArgumentError.value(
        phase,
        'phase',
        'the server sends phase_change for discussion and voting only',
      );
    }
    return _event('ws/game/phase_change_$phase', {
      'phase': phase,
      'deadline': deadline,
    });
  }

  // ---------------------------------------------------------------------------
  // Vote and results
  // ---------------------------------------------------------------------------

  /// Every vote, voter id (as a string) -> target id, null = did not vote.
  static String voteReveal({required Map<String, int?> votes}) =>
      _event('ws/game/vote_reveal', {'votes': votes});

  /// The game is over; the app then fetches `GET .../results/`.
  static String gameResults({
    List<String> winningTeams = const ['village'],
    String reason = 'A Werewolf was eliminated.',
    List<int> eliminatedPlayers = const [],
  }) {
    final data = ContractSamples.map('ws/game/game_results')['data'] as Map;
    return _event('ws/game/game_results', {
      'data': withValues(data.cast<String, dynamic>(), {
        'winning_teams': winningTeams,
        'reason': reason,
        'eliminated_players': eliminatedPlayers,
      }),
    });
  }

  // ---------------------------------------------------------------------------
  // Table
  // ---------------------------------------------------------------------------

  /// A player's phone connected or dropped (public to the whole table).
  static String playerPresence({
    required int playerId,
    required bool connected,
  }) => _event('ws/game/player_presence_connected', {
    'player_id': playerId,
    'connected': connected,
  });

  /// The host role moved (lobby and game sockets alike). [reason] is
  /// `handover`, `returned` or `transferred`.
  static String hostChanged({
    required int hostId,
    required String hostName,
    required int originalHostId,
    String reason = 'handover',
  }) => _event('ws/game/host_changed_handover', {
    'host_id': hostId,
    'host_name': hostName,
    'original_host_id': originalHostId,
    'reason': reason,
  });

  /// This phone's own view as a stage opens (`me`, to this player alone,
  /// before the table's event): [me] is a recorded `/me/` (`recordedMe`).
  static String ownView(Map<String, dynamic> me) => _event(
    me['phase'] == 'results' ? 'ws/game/me_results' : 'ws/game/me_talk',
    {'me': me},
  );

  /// The heartbeat's frame every socket sends its phone ([every] seconds).
  static String beat({num every = 15.0}) =>
      _event('ws/game/beat', {'every': every});

  /// The host took the table back to the lobby for another game.
  static String playAgain({required String lobbyCode}) =>
      _event('ws/game/play_again', {'lobby_code': lobbyCode});

  // ---------------------------------------------------------------------------
  // Lobby socket
  // ---------------------------------------------------------------------------

  /// Someone joined. The server sends nothing but the type, so the app reads
  /// the lobby again.
  static String playerJoined() => _event('ws/lobby/player_joined', {});

  /// Someone left (the type only, like [playerJoined]).
  static String playerLeft() => _event('ws/lobby/player_left', {});

  /// The lobby changed (the host set the deck, or play again): the whole lobby
  /// body, [serverLobby] with the deck [roleConfig].
  static String lobbyUpdate({
    required Map<String, int> roleConfig,
    String code = 'ABC123',
  }) => _event('ws/lobby/lobby_update', {
    'data': serverLobby(code: code, roles: roleConfig),
  });

  /// The host dealt: open the game.
  static String gameStarted({required String gameId}) =>
      _event('ws/lobby/game_started', {'game_id': gameId});
}
