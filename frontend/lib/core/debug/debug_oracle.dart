/// Parsed projection of the DEBUG-gated `debug-state` oracle (contract §B2).
///
/// This is the authoritative ground truth used by both the harness assertions
/// and the toolbar god panel. Shapes mirror the backend exactly:
/// - `current_wave` is an INT: the night window (1 = Doppelganger, 2 = everyone
///   else), 0 outside night. Log entries carry `wave` = the order group (1-4).
/// - `team` ∈ {"werewolf","village","neutral"} (Tanner = "neutral").
/// - `votes` includes EVERY player as a key (null = not voted / abstained).
/// - `winning_teams` (in results) is a list of lowercase tokens ⊂
///   {"village","werewolf","tanner"}, asserted as a SET.
///
/// NOTE: `current_role` is oracle-only post-swap truth. It MUST NOT be routed
/// to any production-reachable screen.
library;

class DebugOracleState {
  const DebugOracleState({
    required this.gameId,
    required this.phase,
    required this.currentWave,
    required this.centerCards,
    required this.players,
    required this.nightActionsLog,
    required this.votes,
    required this.results,
  });

  factory DebugOracleState.fromJson(Map<String, dynamic> json) {
    final playersRaw = json['players'] as List<dynamic>;
    final logRaw = json['night_actions_log'] as List<dynamic>;
    final votesRaw = json['votes'] as Map<String, dynamic>;
    final resultsRaw = json['results'] as Map<String, dynamic>?;

    return DebugOracleState(
      gameId: json['game_id'] as String,
      phase: json['phase'] as String,
      currentWave: json['current_wave'] as int,
      centerCards: (json['center_cards'] as List<dynamic>).cast<String>(),
      players: playersRaw
          .map((p) => DebugOraclePlayer.fromJson(p as Map<String, dynamic>))
          .toList(),
      nightActionsLog: logRaw
          .map((e) => DebugNightAction.fromJson(e as Map<String, dynamic>))
          .toList(),
      votes: votesRaw.map(
        (key, value) => MapEntry(int.parse(key), value as int?),
      ),
      // Null until the results.
      results: resultsRaw == null
          ? null
          : DebugOracleResults.fromJson(resultsRaw),
    );
  }

  final String gameId;
  final String phase;
  final int currentWave;
  final List<String> centerCards;
  final List<DebugOraclePlayer> players;
  final List<DebugNightAction> nightActionsLog;

  /// Every player id → their vote target (null = not voted / abstained).
  final Map<int, int?> votes;
  final DebugOracleResults? results;

  DebugOraclePlayer playerById(int userId) =>
      players.firstWhere((p) => p.userId == userId);

  /// The recorded `result` of a player's night action, matched by [playerId]
  /// and (optionally) [actionType]. Returns null if not found.
  ///
  /// Matches on `action_type` — the stable, verbatim-recorded join key — and
  /// returns the FIRST match in log order, so the Doppelganger two-step (peek
  /// then a follow-up with a different action_type) is disambiguated by
  /// [actionType]. The log also carries `role_acting_as` (recorded at action
  /// time by the backend), but `action_type` is the cleaner join.
  Map<String, dynamic>? actionResultFor(int playerId, {String? actionType}) {
    for (final action in nightActionsLog) {
      if (action.playerId != playerId) continue;
      if (actionType != null && action.actionType != actionType) continue;
      return action.result;
    }
    return null;
  }
}

class DebugOraclePlayer {
  const DebugOraclePlayer({
    required this.userId,
    required this.displayName,
    required this.isHost,
    required this.originalRole,
    required this.currentRole,
    required this.doppelgangerCopiedRole,
    required this.team,
    required this.connected,
  });

  factory DebugOraclePlayer.fromJson(Map<String, dynamic> json) =>
      DebugOraclePlayer(
        userId: json['user_id'] as int,
        displayName: json['display_name'] as String,
        isHost: json['is_host'] as bool,
        originalRole: json['original_role'] as String,
        currentRole: json['current_role'] as String,
        doppelgangerCopiedRole: json['doppelganger_copied_role'] as String?,
        team: json['team'] as String,
        connected: json['connected'] as bool,
      );

  final int userId;
  final String displayName;
  final bool isHost;
  final String originalRole;

  /// Post-swap truth. Oracle-only — never render this pre-results.
  final String currentRole;
  final String? doppelgangerCopiedRole;

  /// "werewolf" | "village" | "neutral" (Tanner = "neutral").
  final String team;
  final bool connected;
}

class DebugNightAction {
  const DebugNightAction({
    required this.wave,
    required this.playerId,
    required this.roleActingAs,
    required this.actionType,
    required this.targets,
    required this.result,
    required this.timestampOrder,
  });

  factory DebugNightAction.fromJson(Map<String, dynamic> json) =>
      DebugNightAction(
        wave: json['wave'] as int,
        playerId: json['player_id'] as int,
        roleActingAs: json['role_acting_as'] as String,
        actionType: json['action_type'] as String,
        targets: (json['targets'] as Map).cast<String, dynamic>(),
        result: (json['result'] as Map).cast<String, dynamic>(),
        timestampOrder: json['timestamp_order'] as int,
      );

  final int wave;
  final int playerId;
  final String roleActingAs;
  final String actionType;
  final Map<String, dynamic> targets;
  final Map<String, dynamic> result;
  final int timestampOrder;
}

class DebugOracleResults {
  const DebugOracleResults({required this.winningTeams, required this.raw});

  factory DebugOracleResults.fromJson(Map<String, dynamic> json) =>
      DebugOracleResults(
        winningTeams: (json['winning_teams'] as List<dynamic>)
            .cast<String>()
            .toSet(),
        raw: json,
      );

  /// Lowercase tokens ⊂ {"village","werewolf","tanner"}. Asserted as a SET.
  final Set<String> winningTeams;

  /// The full raw results map for accessing per-player elimination data.
  final Map<String, dynamic> raw;
}
