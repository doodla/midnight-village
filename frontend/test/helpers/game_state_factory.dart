import 'contract/contract_samples.dart';
import 'contract/contract_shape.dart';
import 'contract/server_json.dart';

/// The role names the server uses (TitleCase, as dealt).
const serverRoles = {
  'Werewolf',
  'Villager',
  'Seer',
  'Robber',
  'Troublemaker',
  'Drunk',
  'Insomniac',
  'Minion',
  'Tanner',
  'Hunter',
  'Mason',
  'Doppelganger',
};

String _serverRole(String role) {
  if (!serverRoles.contains(role)) {
    throw ArgumentError.value(
      role,
      'role',
      'not a role name the server sends (it sends TitleCase: $serverRoles)',
    );
  }
  return role;
}

/// `GET /onuw/games/{id}/me/` as the server sends it, for [viewerId].
///
/// Starts from the server's recorded `/me/` for the phase
/// (`contract_samples/http/game/me_*.json`) and lets a test choose the values:
/// who sits at the table, the viewer's role, the window, the prompt, results.
/// Every key the server always sends is there (`has_voted`, `action_prompt`,
/// `night_results`, `lobby_code`, `host_id`); keys it never sends (a player's
/// `connected`, which comes from `GET .../players/`) cannot be added. [build]
/// checks the result against the samples.
///
/// Defaults: night, window 2 (no Doppelganger in the deck, so the night is
/// window 2 only), viewer 1 holding a Seer with nothing to do yet, three
/// players (Alice, Bob, Charlie), Bob hosting, no deadline.
class GameMeJsonBuilder {
  String _gameId = 'test-game-id';
  String _phase = 'night';
  int? _wave;
  String? _deadline;
  int _viewerId = 1;
  String _role = 'Seer';
  bool _hasActed = false;
  String? _currentRole;
  bool _hasVoted = false;
  Map<int, bool> _playersVoted = const {};
  int? _hostId;
  bool _viewerHosts = false;
  String _lobbyCode = 'ABC123';
  String? _promptKind;
  List<int>? _promptTeam;
  List<Map<String, dynamic>> _nightResults = const [];
  int _nightResultsSeen = 0;
  List<Seat> _seats = defaultSeats;
  Map<String, int> _deck = const {
    'Werewolf': 2,
    'Seer': 1,
    'Robber': 1,
    'Villager': 2,
  };

  GameMeJsonBuilder inPhase(String phase) {
    _phase = phase;
    return this;
  }

  GameMeJsonBuilder withGameId(String gameId) {
    _gameId = gameId;
    return this;
  }

  /// The night window: 1 (the Doppelganger's, only with one in the deck) or 2.
  GameMeJsonBuilder withWave(int wave) {
    _wave = wave;
    return this;
  }

  /// The current deadline (ISO 8601), as the server sends it.
  GameMeJsonBuilder withDeadline(String deadline) {
    _deadline = deadline;
    return this;
  }

  /// Whose `/me/` this is (default 1).
  GameMeJsonBuilder forViewer(int playerId) {
    _viewerId = playerId;
    return this;
  }

  /// The viewer's dealt card (server casing, e.g. `Robber`); [currentRole] is
  /// the card held at the end (results only).
  GameMeJsonBuilder withRole(
    String role, {
    bool hasActed = false,
    String? currentRole,
  }) {
    _role = _serverRole(role);
    _hasActed = hasActed;
    _currentRole = currentRole == null ? null : _serverRole(currentRole);
    return this;
  }

  GameMeJsonBuilder hasVoted(bool voted) {
    _hasVoted = voted;
    return this;
  }

  /// Which players have voted (the vote only; the rest have not).
  GameMeJsonBuilder withPlayersHavingVoted(Map<int, bool> playerVotes) {
    _playersVoted = playerVotes;
    return this;
  }

  /// The viewer is the (effective) host.
  GameMeJsonBuilder asHost() {
    _hostId = null;
    _viewerHosts = true;
    return this;
  }

  /// The effective host's player id (`host_id`); `is_host` follows it, as
  /// on the server.
  GameMeJsonBuilder withHostId(int id) {
    _hostId = id;
    _viewerHosts = false;
    return this;
  }

  int get _host =>
      _hostId ??
      (_viewerHosts
          ? _viewerId
          : _seats.firstWhere((s) => s.id != _viewerId).id);

  GameMeJsonBuilder withSeats(List<Seat> seats) {
    _seats = seats;
    return this;
  }

  /// The viewer's pending prompt: the server's prompt of [kind] (see
  /// [promptKinds]) for the current window, aimed at the other players.
  GameMeJsonBuilder withPrompt(String kind, {List<int>? seeTeam}) {
    _promptKind = kind;
    _promptTeam = seeTeam;
    return this;
  }

  /// `night_results`: entries from [serverNightResult].
  GameMeJsonBuilder withNightResults(List<Map<String, dynamic>> results) {
    _nightResults = results;
    return this;
  }

  /// `night_results_seen`: how many of [withNightResults]' entries this
  /// player has acknowledged (the server never counts more than it lists).
  GameMeJsonBuilder withNightResultsSeen(int seen) {
    _nightResultsSeen = seen;
    return this;
  }

  GameMeJsonBuilder withLobbyCode(String code) {
    _lobbyCode = code;
    return this;
  }

  /// The deck (`roles_in_game`), role name -> count. The viewer's own card
  /// is added when missing.
  GameMeJsonBuilder withDeck(Map<String, int> deck) {
    deck.keys.forEach(_serverRole);
    _deck = deck;
    return this;
  }

  /// The deck, always holding the viewer's own card.
  Map<String, int> get _dealtDeck => {
    ..._deck,
    if (!_deck.containsKey(_role)) _role: 1,
  };

  int get _seenCount {
    if (_nightResultsSeen < 0 || _nightResultsSeen > _nightResults.length) {
      throw StateError(
        'night_results_seen is 0 to the number of night_results the server '
        'lists (${_nightResults.length}), never $_nightResultsSeen.',
      );
    }
    return _nightResultsSeen;
  }

  int get _window {
    if (_phase != 'night') return 0;
    final wave = _wave ?? 2;
    if (wave == 1 && !_dealtDeck.containsKey('Doppelganger')) {
      throw StateError(
        'Window 1 is the Doppelganger\'s: without one in the deck the server '
        'opens window 2 only (put a Doppelganger in withDeck, or use wave 2).',
      );
    }
    return wave;
  }

  Map<String, dynamic> build() {
    final sample = ContractSamples.map(switch (_phase) {
      'night' => 'http/game/me_night_no_action',
      'discussion' => 'http/game/me_discussion',
      'voting' => 'http/game/me_voting',
      'results' => 'http/game/me_results',
      _ => throw ArgumentError.value(_phase, 'phase', 'not a game phase'),
    });
    final player = ((sample['players'] as List).first as Map)
        .cast<String, dynamic>();
    final role = (sample['your_role'] as Map).cast<String, dynamic>();
    final window = _window;
    final promptKind = _promptKind;
    final json = withValues(sample, {
      'game_id': _gameId,
      'lobby_code': _lobbyCode,
      'phase': _phase,
      'current_wave': window,
      'deadline': _deadline,
      'your_role': withValues(role, {
        'original_role': _role,
        'has_acted': _hasActed,
        if (_phase == 'results') 'current_role': _currentRole ?? _role,
      }),
      'is_host': _host == _viewerId,
      'host_id': _host,
      'has_voted': _hasVoted,
      'players': [
        for (final (i, seat) in _seats.indexed)
          withValues(player, {
            'player_id': seat.id,
            'display_name': seat.name,
            ...seatFields(i),
            if (_phase == 'voting')
              'has_voted': seat.id == _viewerId
                  ? _hasVoted
                  : _playersVoted[seat.id] ?? false,
          }),
      ],
      'action_prompt': promptKind == null
          ? null
          : serverPrompt(
              promptKind,
              wave: window,
              playerIds: [
                for (final s in _seats)
                  if (s.id != _viewerId) s.id,
              ],
              seeTeam: _promptTeam,
            ),
      'roles_in_game': [
        for (final MapEntry(:key, :value) in _dealtDeck.entries)
          {'role': key, 'count': value},
      ],
      'night_results': _nightResults,
      'night_results_seen': _seenCount,
    });
    checkHttpBody('GET', '/onuw/games/$_gameId/me/', 200, json);
    return json;
  }
}
