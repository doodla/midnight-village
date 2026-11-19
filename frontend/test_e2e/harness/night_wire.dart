import 'dart:async';
import 'dart:convert';

import 'package:midnight_village/core/debug/debug_api_client.dart';
import 'package:midnight_village/core/debug/debug_models.dart';
import 'package:web_socket_channel/web_socket_channel.dart';

import 'harness_config.dart';

/// Records every WebSocket event one player receives for a game, in order, so a
/// test can check WHAT the server sends WHEN (the night's delivery rules) rather
/// than only where the game ends up.
///
/// Events keep the wire's underscore names: `wave_start`, `action_prompt`,
/// `action_result`, `wave_complete`, `wave_waiting`, `phase_change`.
class PlayerWire {
  PlayerWire._(this.player, this._channel);

  /// Connects as [player] to the game's socket (with the Origin header the
  /// server requires) and starts recording.
  static Future<PlayerWire> connect(
    DebugApiClient client,
    DebugTable table,
    DebugPlayer player,
  ) async {
    final channel = client.connectWebSocket(
      '${HarnessConfig.wsBaseUrl}/ws/game/${table.gameId}/',
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

  /// `type[:wave]` for each event, e.g. `wave_start:2`, `phase_change:discussion`.
  List<String> get trace => [
    for (final e in events)
      switch (e['type']) {
        'phase_change' => 'phase_change:${e['phase']}',
        final String t when e.containsKey('wave') => '$t:${e['wave']}',
        final String t => t,
        _ => '?',
      },
  ];

  Iterable<Map<String, dynamic>> ofType(String type) =>
      events.where((e) => e['type'] == type);

  /// Polls until [condition] holds (bounded; throws on expiry).
  Future<void> waitFor(
    bool Function() condition, {
    required String reason,
    Duration timeout = const Duration(seconds: 8),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      if (condition()) return;
      await Future<void>.delayed(const Duration(milliseconds: 50));
    }
    throw StateError(
      'Timed out waiting for $reason for ${player.displayName}. '
      'Events so far: $trace',
    );
  }

  Future<void> close() async {
    await _subscription.cancel();
    await _channel.sink.close();
  }
}
