part of 'live_game.dart';

/// A game as this phone holds it: the server's last `/me/`,
/// the taps it has not seen yet ([outbox]), and the results once over.
@immutable
class LiveGame {
  const LiveGame._({
    required this.server,
    required this.outbox,
    this.outcome,
    this.presence = const {},
    this.hostNotice,
    this.tableClosed = false,
    this.fetchFailing = false,
    this.outcomeFailing = false,
  });

  /// The last `/me/` the server sent.
  final GameMe server;

  /// This phone's taps in flight, unsent or confirming.
  final Outbox outbox;

  /// `GET .../results/`, fetched (and fetched again until it loads) once the
  /// game is in the results.
  final GameOutcome? outcome;

  /// Who has a phone connected (public), from `player_presence`.
  final Map<int, bool> presence;

  /// The latest host change, for the quiet line about it (until cleared).
  final HostChange? hostNotice;

  /// The game (its table) is gone: the last fetch was answered 404.
  final bool tableClosed;

  /// The last `/me/` fetch got no answer (it is being made again): with the
  /// socket down, this phone is offline ("One moment"). A socket refused
  /// while fetches work is not shown.
  final bool fetchFailing;

  /// The last results fetch failed (it is being made again, with backoff):
  /// The end board says "One moment" until [outcome] arrives.
  final bool outcomeFailing;

  /// What the screens show: `/me/` with this phone's taps on it. Everything
  /// the table can see on this phone changes on the tap, never on the
  /// answer.
  GameMe get me => outbox.on(server);

  /// The taps whose answer never came and that wait for "Try again"
  /// ([LiveGameNotifier.retry]); the board shows its own for a
  /// choose. The results ack is retried by itself and is not listed.
  Set<OutboxLane> get unsent =>
      outbox.unsent.difference(const {OutboxLane.ack});

  LiveGame copyWith({
    GameMe? server,
    Outbox? outbox,
    GameOutcome? outcome,
    Map<int, bool>? presence,
    HostChange? hostNotice,
    bool clearHostNotice = false,
    bool? tableClosed,
    bool? fetchFailing,
    bool? outcomeFailing,
  }) => LiveGame._(
    server: server ?? this.server,
    outbox: outbox ?? this.outbox,
    outcome: outcome ?? this.outcome,
    presence: presence ?? this.presence,
    hostNotice: clearHostNotice ? null : hostNotice ?? this.hostNotice,
    tableClosed: tableClosed ?? this.tableClosed,
    fetchFailing: fetchFailing ?? this.fetchFailing,
    outcomeFailing: outcomeFailing ?? this.outcomeFailing,
  );
}
