import 'dart:async';

import '../../features/auth/domain/user.dart';
import 'debug_api_client.dart';
import 'debug_models.dart';
import 'debug_oracle.dart';

/// Adopts a player's session (writes token+user, sets authed state, NO refresh).
/// Wired to [AuthNotifier.adoptSession] by the provider factory.
typedef AdoptSessionFn =
    Future<void> Function(
      User user, {
      required String accessToken,
      required String refreshToken,
    });

/// Invalidates the four game providers for [gameId] so the prior player's
/// socket is disposed and the new player's attaches. Wired by the factory to
/// invalidate `gameProvider`, `gameWebSocketProvider`,
/// `gameWebSocketStreamProvider`, `gameConnectionStateProvider`.
typedef InvalidateGameProvidersFn = void Function(String gameId);

/// DEBUG-ONLY orchestrator for a full ONUW table (contract §D1).
///
/// Spins up N guests, builds a lobby, forces an assignment, starts the game,
/// then drives any player and reads authoritative ground truth via the oracle.
/// All backend I/O goes through the explicit-per-player-token [DebugApiClient]
/// (§D2) — NOT the production [AuthInterceptor] — so driving one player never
/// rotates another's token.
class DebugTableController {
  DebugTableController({
    required DebugApiClient client,
    required AdoptSessionFn adoptSession,
    required InvalidateGameProvidersFn invalidateGameProviders,
  }) : _client = client,
       _adoptSession = adoptSession,
       _invalidateGameProviders = invalidateGameProviders;

  final DebugApiClient _client;
  final AdoptSessionFn _adoptSession;
  final InvalidateGameProvidersFn _invalidateGameProviders;

  DebugTable? _table;
  DebugTable? get table => _table;

  /// User ids the toolbar has manually "disconnected" (the manual drop toggle).
  /// Exposed so the toolbar reflects the toggle and can suppress reconnection
  /// of the visible perspective's socket.
  final Set<int> _manuallyDisconnected = <int>{};
  bool isManuallyDisconnected(int userId) =>
      _manuallyDisconnected.contains(userId);

  // ---------------------------------------------------------------------------
  // Table setup
  // ---------------------------------------------------------------------------

  /// Creates one guest per entry in [playerNames] (the FIRST is the host /
  /// lobby creator), builds a lobby, joins + readies all, PATCHes [roleCounts],
  /// and starts with a forced assignment built from [playerRolesByName] +
  /// [centerCards].
  ///
  /// Roles are authored by player NAME (the natural unit for scenarios), not by
  /// server id — the caller can't know server ids in advance. This captures
  /// each guest's server `user_id` from the guest response and re-keys the
  /// forced assignment to those ids (stringified for the wire). Creation order
  /// does NOT affect role assignment; it is explicit per player.
  ///
  /// [timerSettings] are extra lobby settings PATCHed beside the roles, i.e. the
  /// game's timers in whole seconds (`night_wave_seconds`,
  /// `night_min_window_seconds`, `night_doppelganger_window_seconds`,
  /// `discussion_seconds`, `voting_seconds`). Leave null for the server's
  /// defaults (the real window lengths); the harness passes zeros so a night
  /// window closes as soon as every actor has submitted.
  ///
  /// [protocolTwo] opens the table as the rebuilt screens do
  /// (`defaults: "v2"`: the look stage, night protocol 2), with the deck
  /// made custom from [roleCounts] (an automatic deck is built at the deal
  /// and would not match a forced assignment). The game route then shows the
  /// rebuilt shell for it. Only this toolbar makes such tables for now.
  ///
  /// [roleCounts] is TitleCase role name → count, exactly as PATCHed.
  /// [playerRolesByName] maps each player's display name → TitleCase role.
  /// [centerCards] is exactly 3 TitleCase role names. Pass all three null to
  /// start with random assignment (no `debug` key).
  Future<DebugTable> createTable({
    required List<String> playerNames,
    required Map<String, int> roleCounts,
    Map<String, String>? playerRolesByName,
    List<String>? centerCards,
    Map<String, int>? timerSettings,
    bool protocolTwo = false,
  }) async {
    if (playerNames.isEmpty) {
      throw const _DebugTableException('playerNames must not be empty');
    }
    if (playerNames.toSet().length != playerNames.length) {
      throw const _DebugTableException('playerNames must be unique');
    }

    // 1. Create one guest per name; capture each server user_id + tokens.
    final guests = <_Guest>[];
    for (final name in playerNames) {
      guests.add(await _createGuest(name));
    }

    final host = guests.first;

    // 2. Host creates the lobby.
    final lobbyResp = await _client.post(
      '/lobbies/',
      token: host.accessToken,
      data: {'game_type': 'onuw', if (protocolTwo) 'defaults': 'v2'},
    );
    final lobbyCode = _requireString(lobbyResp, 'code', '/lobbies/');

    // 3. All non-host guests join.
    for (final guest in guests.skip(1)) {
      await _client.post('/lobbies/$lobbyCode/join/', token: guest.accessToken);
    }

    // 4. Everyone readies up.
    for (final guest in guests) {
      await _client.post(
        '/lobbies/$lobbyCode/ready/',
        token: guest.accessToken,
      );
    }

    // 5. Host PATCHes the role config (TitleCase keys).
    await _client.patch(
      '/lobbies/$lobbyCode/',
      token: host.accessToken,
      data: {
        'settings': {
          if (protocolTwo) 'deck': 'custom',
          'roles': roleCounts,
          ...?timerSettings,
        },
      },
    );

    // 6. Build the forced assignment keyed by captured server user_ids, then
    //    host starts. When no forced roles are given, start randomly.
    ForcedAssignment? assignment;
    if (playerRolesByName != null && centerCards != null) {
      assignment = ForcedAssignment(
        playerRoles: {
          for (final guest in guests)
            guest.userId:
                playerRolesByName[guest.displayName] ??
                (throw _DebugTableException(
                  'No forced role for player "${guest.displayName}"',
                )),
        },
        center: centerCards,
      );
    }

    final startBody = assignment == null
        ? null
        : {
            'debug': {'forced_assignment': assignment.toJson()},
          };
    final startResp = await _client.post(
      '/onuw/lobbies/$lobbyCode/start/',
      token: host.accessToken,
      data: startBody,
    );
    final gameId = _requireString(
      startResp,
      'game_id',
      '/onuw/lobbies/$lobbyCode/start/',
    );

    // Map each player's forced role (debug ground truth).
    final players = <DebugPlayer>[
      for (var i = 0; i < guests.length; i++)
        DebugPlayer(
          userId: guests[i].userId,
          displayName: guests[i].displayName,
          accessToken: guests[i].accessToken,
          refreshToken: guests[i].refreshToken,
          role: playerRolesByName?[guests[i].displayName] ?? 'Unknown',
          isHost: i == 0,
        ),
    ];

    final table = DebugTable(
      gameId: gameId,
      lobbyCode: lobbyCode,
      players: players,
    );
    _table = table;
    return table;
  }

  /// Points the controller at [table] (a later game of the same lobby, after a
  /// play again), so [driveAs], [playerView], [oracle] and [fireTimer] act on
  /// that game.
  void attachTable(DebugTable table) => _table = table;

  // ---------------------------------------------------------------------------
  // Perspective + driving
  // ---------------------------------------------------------------------------

  /// Switches the VISIBLE perspective to [player]: adopts their session (no
  /// refresh) and invalidates the four game providers so exactly one live WS
  /// remains — the prior player's socket is disposed, [player]'s attaches.
  Future<void> switchTo(DebugPlayer player) async {
    await _adoptSession(
      player.user,
      accessToken: player.accessToken,
      refreshToken: player.refreshToken,
    );
    final gameId = _table?.gameId;
    if (gameId != null) {
      _invalidateGameProviders(gameId);
    }
  }

  /// Issues [action] AS [player] WITHOUT changing the visible perspective,
  /// via the explicit-per-player-token client.
  ///
  /// STRICT by default: anything the server refuses (including a 409 "already
  /// acted / already voted") throws, so a runner can never mistake a refused
  /// move for a made one. The debug toolbar's one-tap helpers re-send moves on
  /// purpose and pass [lenient] = true to treat a 409 as already done.
  Future<void> driveAs(
    DebugPlayer player,
    DebugAction action, {
    bool lenient = false,
  }) async {
    final gameId = _requireTable().gameId;
    switch (action.kind) {
      case DebugActionKind.nightAction:
        await _client.post(
          '/onuw/games/$gameId/action/',
          token: player.accessToken,
          data: {'action_type': action.actionType, 'targets': action.targets},
          idempotent409: lenient,
        );
      case DebugActionKind.vote:
        await _client.post(
          '/onuw/games/$gameId/vote/',
          token: player.accessToken,
          data: {'target_player_id': action.voteTargetUserId},
          idempotent409: lenient,
        );
      case DebugActionKind.endDiscussion:
        await _client.post(
          '/onuw/games/$gameId/end-discussion/',
          token: player.accessToken,
        );
      case DebugActionKind.advanceWave:
        await _client.post(
          '/onuw/games/$gameId/advance-wave/',
          token: player.accessToken,
        );
      case DebugActionKind.revealVotes:
        await _client.post(
          '/onuw/games/$gameId/reveal-votes/',
          token: player.accessToken,
        );
    }
  }

  /// Reads what the server tells [player] about the game (`GET .../me/`): the
  /// same player-scoped view their phone gets, including the pending
  /// `action_prompt`. Issued with that player's own token; the visible
  /// perspective does not change.
  Future<Map<String, dynamic>> playerView(DebugPlayer player) async {
    final gameId = _requireTable().gameId;
    return _client.get('/onuw/games/$gameId/me/', token: player.accessToken);
  }

  /// Reads the authoritative debug-state oracle (contract §B2).
  ///
  /// Issued as the host (any authed player works; host is always present).
  Future<DebugOracleState> oracle() async {
    final table = _requireTable();
    final json = await _client.get(
      '/onuw/games/${table.gameId}/debug-state/',
      token: table.host.accessToken,
    );
    return DebugOracleState.fromJson(json);
  }

  /// Fires a pending server timer on demand (contract §B3) — the SINGLE
  /// coupling point for timeout paths (action-skip-on-expiry, vote
  /// auto-finalize). Happy-path transitions use host endpoints instead.
  ///
  /// `TimerKey.wave(n)` closes night window `n` now (1 = Doppelganger, 2 =
  /// everyone else), ignoring the fixed and minimum lengths. Returns the
  /// server's `fired`: false means no timer was pending for the key (a window
  /// whose timer setting is 0 has none), so nothing happened.
  Future<bool> fireTimer(TimerKey key) async {
    final table = _requireTable();
    final response = await _client.post(
      '/onuw/games/${table.gameId}/debug-fire-timer/',
      token: table.host.accessToken,
      data: {'key': key.key},
    );
    return response['fired'] == true;
  }

  /// Drops ([connected] = false) or restores ([connected] = true) [player]'s
  /// WebSocket — the manual disconnect toggle (contract §C/§D3, unasserted).
  ///
  /// The live socket lifecycle is owned by the game providers (keyed by gameId,
  /// reading the adopted token from storage). This records the desired state in
  /// [isManuallyDisconnected] and invalidates the providers: when restoring,
  /// the provider re-attaches; when dropping, the toolbar consults
  /// [isManuallyDisconnected] to keep the socket down. Only meaningful for the
  /// visible perspective.
  Future<void> setConnected(DebugPlayer player, bool connected) async {
    final gameId = _requireTable().gameId;
    if (connected) {
      _manuallyDisconnected.remove(player.userId);
    } else {
      _manuallyDisconnected.add(player.userId);
    }
    _invalidateGameProviders(gameId);
  }

  // ---------------------------------------------------------------------------
  // Internals
  // ---------------------------------------------------------------------------

  Future<_Guest> _createGuest(String displayName) async {
    final resp = await _client.post(
      '/auth/guest/',
      // Guest creation is unauthenticated; the explicit-token client still
      // requires SOME token header, but the backend ignores it for this route.
      // Send an empty bearer to satisfy the per-call contract.
      token: '',
      data: {'display_name': displayName},
    );
    final user = resp['user'];
    if (user is! Map<String, dynamic>) {
      throw const _DebugTableException('guest response missing user');
    }
    return _Guest(
      userId: (user['id'] as num).toInt(),
      displayName: user['display_name'] as String,
      accessToken: _requireString(resp, 'access', '/auth/guest/'),
      refreshToken: _requireString(resp, 'refresh', '/auth/guest/'),
    );
  }

  DebugTable _requireTable() {
    final table = _table;
    if (table == null) {
      throw const _DebugTableException(
        'No table created yet — call createTable first',
      );
    }
    return table;
  }

  String _requireString(Map<String, dynamic> map, String key, String path) {
    final value = map[key];
    if (value is! String || value.isEmpty) {
      throw _DebugTableException('Missing "$key" in response from $path');
    }
    return value;
  }
}

class _Guest {
  const _Guest({
    required this.userId,
    required this.displayName,
    required this.accessToken,
    required this.refreshToken,
  });

  final int userId;
  final String displayName;
  final String accessToken;
  final String refreshToken;
}

class _DebugTableException implements Exception {
  const _DebugTableException(this.message);
  final String message;

  @override
  String toString() => 'DebugTableException: $message';
}
