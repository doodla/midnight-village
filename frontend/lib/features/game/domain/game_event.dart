import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../../core/host/host_change.dart';
import 'game_me.dart';
import 'game_outcome.dart';
import 'stage_progress.dart';

/// A game socket event as a phone reads it.
///
/// The rule that keeps a restarted phone on the right screen: an event never
/// carries state of its own into the app. It either names a stage that `/me/`
/// shows ([RefetchEvent]: read it again unless the `/me/` held is already
/// there), or carries what `/me/` (or the player list, the results) also
/// holds, in the same absolute form, so applying it twice, late, or never,
/// and then fetching, ends in the same state:
/// - [OwnViewEvent]: this phone's own `/me/`, whole, as a stage opens (and the
///   results with it at the end), sent to this player alone;
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
      'me' => OwnViewEvent(
        GameMe.fromJson((event['me'] as Map).cast<String, dynamic>()),
        results: switch (event['results']) {
          final Map<dynamic, dynamic> results => GameOutcome.fromJson(
            results.cast<String, dynamic>(),
          ),
          _ => null,
        },
      ),
      // A window opened, the phase moved, the votes are out, the game is
      // over: what this phone sees next is in `/me/`, never in the event,
      // which names only the stage it opens.
      'night_window' => RefetchEvent(
        type as String,
        place: GameMe.placeOf(GamePhase.night, event['window'] as int),
      ),
      'phase_change' => RefetchEvent(
        type as String,
        place: GameMe.placeOf(GamePhase.fromServer(event['phase']), 0),
      ),
      'vote_reveal' || 'game_results' => RefetchEvent(
        type as String,
        place: GameMe.placeOf(GamePhase.results, 0),
      ),
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

/// A stage opened that `/me/` shows: fetch it, unless the `/me/` held is
/// already at that stage or past it ([GameMe.place]: the server sends each
/// player's own view of the stage just before this event).
final class RefetchEvent extends GameEvent {
  const RefetchEvent(this.type, {required this.place});

  final String type;

  /// The place of the stage it opens ([GameMe.placeOf]).
  final int place;
}

/// This phone's own `/me/` as a stage opens (`me`, sent to this player's own
/// group only), and at the results the results ([results]).
final class OwnViewEvent extends GameEvent {
  const OwnViewEvent(this.me, {this.results});

  final GameMe me;
  final GameOutcome? results;
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

/// A type this phone does nothing with (a type added later: consumers drop
/// unknown types, so does the app).
final class IgnoredEvent extends GameEvent {
  const IgnoredEvent(this.type);

  final String? type;
}
