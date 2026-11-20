import 'dart:async';
import 'dart:convert';

import 'package:midnight_village/core/debug/debug_api_client.dart';
import 'package:midnight_village/core/debug/debug_models.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'harness_config.dart';
import 'time_budget.dart';

/// Records every WebSocket event one player receives for a game (or a lobby), in
/// order, so a test can check WHAT the server sends WHEN (the night's delivery
/// rules) rather than only where the game ends up.
///
/// Events keep the wire's underscore names: `night_window`, `progress`,
/// `phase_change`, `vote_reveal`, `game_results`, `player_presence`,
/// `host_changed`, `play_again` (game socket);
/// `lobby_update`, `host_changed`, `game_started` (lobby socket).
class PlayerWire {
  PlayerWire._(this.player, this._channel);

  /// Connects as [player] to the game's socket (with the Origin header the
  /// server requires) and starts recording.
  static Future<PlayerWire> connect(
    DebugApiClient client,
    DebugTable table,
    DebugPlayer player,
  ) => connectToGame(client, table.gameId, player);

  /// Same, for any game id (a later game of the same lobby).
  static Future<PlayerWire> connectToGame(
    DebugApiClient client,
    String gameId,
    DebugPlayer player,
  ) => _open(client, player, '/ws/game/$gameId/');

  /// Same, for the table's lobby socket (`/ws/lobby/<code>/`): the one the lobby
  /// screen and the host handover use.
  static Future<PlayerWire> connectLobby(
    DebugApiClient client,
    DebugTable table,
    DebugPlayer player,
  ) => _open(client, player, '/ws/lobby/${table.lobbyCode}/');

  static Future<PlayerWire> _open(
    DebugApiClient client,
    DebugPlayer player,
    String path,
  ) async {
    final channel = client.connectWebSocket(
      '${HarnessConfig.wsBaseUrl}$path',
      token: player.accessToken,
    );
    await channel.ready;
    final wire = PlayerWire._(player, channel);
    wire._subscription = channel.stream.listen((message) {
      wire.events.add(
        Map<String, dynamic>.from(jsonDecode(message as String) as Map),
      );
    });
    return wire;
  }

  final DebugPlayer player;
  final WebSocketChannel _channel;
  late final StreamSubscription<dynamic> _subscription;

  /// Everything received so far, oldest first.
  final List<Map<String, dynamic>> events = [];

  /// `type[:window]` for each event, e.g. `night_window:2`,
  /// `phase_change:discussion`.
  List<String> get trace => [
    for (final e in events)
      switch (e['type']) {
        'phase_change' => 'phase_change:${e['phase']}',
        final String t when e.containsKey('window') => '$t:${e['window']}',
        final String t => t,
        _ => '?',
      },
  ];

  Iterable<Map<String, dynamic>> ofType(String type) =>
      events.where((e) => e['type'] == type);

  /// A position in [events]; pass it as `after` to [waitForEvent] to ignore
  /// everything received before it.
  int get mark => events.length;

  /// Waits for an event of [type] (matching [where]) received after [after] and
  /// returns it (bounded; throws on expiry).
  Future<Map<String, dynamic>> waitForEvent(
    String type, {
    bool Function(Map<String, dynamic> event)? where,
    int after = 0,
    required Duration timeout,
  }) async {
    Map<String, dynamic>? found;
    await waitFor(
      () {
        for (final e in events.skip(after)) {
          if (e['type'] == type && (where?.call(e) ?? true)) {
            found = e;
            return true;
          }
        }
        return false;
      },
      reason: 'a "$type" event',
      timeout: timeout,
    );
    return found!;
  }

  /// Polls until [condition] holds (bounded by [timeout]; throws on expiry).
  Future<void> waitFor(
    bool Function() condition, {
    required String reason,
    required Duration timeout,
  }) => pollUntil(
    condition,
    reason: '$reason for ${player.displayName}',
    timeout: timeout,
    context: () => 'Events so far: $trace',
  );

  Future<void> close() async {
    await _subscription.cancel();
    await _channel.sink.close();
  }
}
