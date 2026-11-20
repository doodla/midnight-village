import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../core/host/host_change.dart';
import 'stage_progress.dart';

/// A game socket event as a night protocol 2 phone reads it.
///
/// The rule that keeps a restarted phone on the right screen: an event never
/// carries state of its own into the app. It either names a reason to fetch
/// `/me/` again ([RefetchEvent]), or carries a value `/me/` (or the player
/// list) also holds, in the same absolute form, so applying it twice, late,
/// or never, and then fetching, ends in the same state:
/// - [ProgressEvent]: `/me/`'s `progress` counts;
/// - [PresenceEvent]: the player list's `connected` flag (not on any screen
///   decision);
/// - [HostEvent]: `/me/`'s `host_id` (the event's names are for the notice).
@immutable
sealed class GameEvent {
  const GameEvent();

  /// A socket message (a map, or its JSON text). Anything that is not an
  /// object with a `type` is [IgnoredEvent]: the server never sends one, and
  /// the next fetch is the truth anyway.
  factory GameEvent.parse(Object? message) {
    final decoded = message is String ? _decode(message) : message;
    if (decoded is! Map) return const IgnoredEvent(null);
    final event = decoded.cast<String, dynamic>();
    final type = event['type'];
    return switch (type) {
      'progress' => ProgressEvent(StageProgress.fromJson(event)),
      'player_presence' => PresenceEvent(
        event['player_id'] as int,
        connected: event['connected'] as bool,
      ),
      'host_changed' => HostEvent(HostChange.fromEvent(event)),
      // A window opened or closed, the phase moved, the votes are out, the
      // game is over, the table went back to the lobby: what this phone sees
      // next is in `/me/` (and `/me/table/`), never in the event.
      'night_window' ||
      // PROTOCOL 1: the old night's window event, still sent beside
      // `night_window`; drop it when the server slice stops sending it.
      'wave_complete' ||
      'phase_change' ||
      'vote_reveal' ||
      'game_results' => RefetchEvent(type as String),
      'play_again' => const TableMovedEvent(),
      final other => IgnoredEvent(other is String ? other : null),
    };
  }

  static Object? _decode(String text) {
    try {
      return jsonDecode(text);
    } on FormatException {
      return null;
    }
  }
}

/// Something changed that `/me/` shows: fetch it.
final class RefetchEvent extends GameEvent {
  const RefetchEvent(this.type);

  final String type;
}

/// The table went back to waiting (`play_again`): where this phone is now
/// is `/me/table/`'s answer.
final class TableMovedEvent extends GameEvent {
  const TableMovedEvent();
}

/// New counts for a stage.
final class ProgressEvent extends GameEvent {
  const ProgressEvent(this.progress);

  final StageProgress progress;
}

/// A phone joined or dropped.
final class PresenceEvent extends GameEvent {
  const PresenceEvent(this.playerId, {required this.connected});

  final int playerId;
  final bool connected;
}

/// The host role moved.
final class HostEvent extends GameEvent {
  const HostEvent(this.change);

  final HostChange change;
}

/// A type this phone does nothing with (protocol 1's per-role events, or a
/// type added later: consumers drop unknown types, so does the app).
final class IgnoredEvent extends GameEvent {
  const IgnoredEvent(this.type);

  final String? type;
}
