import '../../features/auth/domain/user.dart';

/// DEBUG-ONLY value types for the debug toolbar + integration harness.
///
/// Everything in `lib/core/debug/` is reachable only behind const [Env.isDev]
/// (see callers). These are plain data holders shared between the toolbar
/// (human, `/debug`) and the `integration_test/` runners (automated).

/// A forced role assignment sent to the backend on game start
/// (`debug.forced_assignment`).
///
/// Wire shape (per contract §B1):
/// ```jsonc
/// { "player_roles": { "12": "Werewolf", ... },  // keys = STRINGIFIED user ids
///   "center": ["Werewolf", "Minion", "Drunk"] }  // exactly 3, TitleCase
/// ```
class ForcedAssignment {
  const ForcedAssignment({required this.playerRoles, required this.center});

  /// Map of server `user_id` → canonical TitleCase role name.
  final Map<int, String> playerRoles;

  /// Exactly 3 center cards, canonical TitleCase role names.
  final List<String> center;

  /// Serializes to the backend wire shape. Keys are stringified user ids
  /// because JSON object keys must be strings; the backend `int()`-coerces.
  Map<String, dynamic> toJson() => {
    'player_roles': {
      for (final entry in playerRoles.entries)
        entry.key.toString(): entry.value,
    },
    'center': center,
  };
}

/// One player at a debug table: their server identity, tokens, and forced role.
class DebugPlayer {
  const DebugPlayer({
    required this.userId,
    required this.displayName,
    required this.accessToken,
    required this.refreshToken,
    required this.role,
    required this.isHost,
  });

  final int userId;
  final String displayName;
  final String accessToken;
  final String refreshToken;

  /// The forced role this player was dealt (TitleCase). Debug-only ground truth.
  final String role;
  final bool isHost;

  /// Builds the [User] used by [AuthNotifier.adoptSession] when switching to
  /// this player's perspective.
  User get user => User(id: userId, displayName: displayName);
}

/// A fully-provisioned debug table: every player + the started game id.
class DebugTable {
  const DebugTable({
    required this.gameId,
    required this.lobbyCode,
    required this.players,
  });

  final String gameId;
  final String lobbyCode;
  final List<DebugPlayer> players;

  DebugPlayer get host => players.firstWhere((p) => p.isHost);

  DebugPlayer playerById(int userId) =>
      players.firstWhere((p) => p.userId == userId);
}

/// The kind of game action a player drives via [DebugTableController.driveAs].
enum DebugActionKind {
  nightAction,
  vote,
  endDiscussion,
  advanceWave,
  revealVotes,
}

/// A single action issued AS a specific player without switching perspective.
class DebugAction {
  const DebugAction.nightAction({
    required this.actionType,
    required this.targets,
  }) : kind = DebugActionKind.nightAction,
       voteTargetUserId = null;

  const DebugAction.vote({required this.voteTargetUserId})
    : kind = DebugActionKind.vote,
      actionType = null,
      targets = null;

  const DebugAction.endDiscussion()
    : kind = DebugActionKind.endDiscussion,
      actionType = null,
      targets = null,
      voteTargetUserId = null;

  const DebugAction.advanceWave()
    : kind = DebugActionKind.advanceWave,
      actionType = null,
      targets = null,
      voteTargetUserId = null;

  const DebugAction.revealVotes()
    : kind = DebugActionKind.revealVotes,
      actionType = null,
      targets = null,
      voteTargetUserId = null;

  final DebugActionKind kind;

  /// For night actions: the wire `action_type` (e.g. `peek_player`).
  final String? actionType;

  /// For night actions: the encoded `targets` map (see contract §D4).
  final Map<String, dynamic>? targets;

  /// For votes: the target player's server `user_id`. Null = abstain.
  final int? voteTargetUserId;
}

/// Identifies a pending server timer to fire on demand (contract §B3).
///
/// `wave:{n}` / `discussion` / `voting`, or `current` (the single pending key).
class TimerKey {
  const TimerKey._(this.key);

  factory TimerKey.wave(int n) => TimerKey._('wave:$n');
  static const TimerKey discussion = TimerKey._('discussion');
  static const TimerKey voting = TimerKey._('voting');
  static const TimerKey current = TimerKey._('current');

  final String key;
}
