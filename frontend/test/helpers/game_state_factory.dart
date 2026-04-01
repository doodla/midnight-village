import 'package:midnight_village/features/game/domain/game_session_state.dart';
import 'package:midnight_village/features/game/domain/night_state.dart';
import 'package:midnight_village/features/game/domain/voting_state.dart';

/// Default players used by both [GameStateBuilder] and [GameMeJsonBuilder].
const List<GamePlayer> defaultPlayers = [
  GamePlayer(playerId: 1, displayName: 'Alice'),
  GamePlayer(playerId: 2, displayName: 'Bob'),
  GamePlayer(playerId: 3, displayName: 'Charlie'),
];

/// Fluent builder for [GameSessionState] objects in tests.
///
/// Produces fully constructed domain objects for widget tests that inject
/// state via provider overrides. For HTTP mock JSON, use [GameMeJsonBuilder].
///
/// Defaults: night phase, wave 1, seer role, 3 players (Alice/Bob/Charlie).
class GameStateBuilder {
  String _gameId = 'test-game-id';
  String _phase = 'night';
  int _currentWave = 1;
  DateTime? _deadline;
  String _originalRole = 'seer';
  bool _hasActed = false;
  String? _currentRole;
  List<GamePlayer> _players = defaultPlayers;
  NightSubView _nightSubView = NightSubView.waiting;
  ActionPrompt? _actionPrompt;
  ActionResult? _lastActionResult;
  bool _hasVoted = false;
  VoteProgress _voteProgress = const VoteProgress();
  VoteRevealData? _voteRevealData;
  bool _isHost = false;
  List<RoleInGame> _rolesInGame = const [
    RoleInGame(role: 'werewolf', count: 2),
    RoleInGame(role: 'seer', count: 1),
  ];

  GameStateBuilder inPhase(String phase) {
    _phase = phase;
    return this;
  }

  GameStateBuilder withGameId(String gameId) {
    _gameId = gameId;
    return this;
  }

  GameStateBuilder withWave(int wave) {
    _currentWave = wave;
    return this;
  }

  GameStateBuilder withDeadline(DateTime deadline) {
    _deadline = deadline;
    return this;
  }

  GameStateBuilder withRole(
    String role, {
    bool hasActed = false,
    String? currentRole,
  }) {
    _originalRole = role;
    _hasActed = hasActed;
    _currentRole = currentRole;
    return this;
  }

  GameStateBuilder withPlayers(List<GamePlayer> players) {
    _players = players;
    return this;
  }

  GameStateBuilder asHost() {
    _isHost = true;
    return this;
  }

  GameStateBuilder hasVoted(bool voted) {
    _hasVoted = voted;
    _voteProgress = _voteProgress.copyWith(currentPlayerVoted: voted);
    return this;
  }

  GameStateBuilder withVoteProgress(Map<int, bool> playerVoted) {
    _voteProgress = VoteProgress(
      playerVoted: playerVoted,
      currentPlayerVoted: _voteProgress.currentPlayerVoted,
    );
    return this;
  }

  GameStateBuilder withVoteReveal({
    required Map<String, int?> votes,
    required Map<String, int> tally,
  }) {
    _voteRevealData = VoteRevealData(votes: votes, tally: tally);
    return this;
  }

  GameStateBuilder withSeerPrompt({
    int wave = 1,
    List<int> playerTargets = const [2, 3],
    List<int> centerTargets = const [0, 1, 2],
  }) {
    _actionPrompt = ActionPrompt(
      roleActingAs: 'Seer',
      actionTypes: const ['peek_player', 'peek_center'],
      validTargets: {
        'peek_player': {'players': playerTargets},
        'peek_center': {'card_indices': centerTargets},
      },
      wave: wave,
    );
    _nightSubView = NightSubView.seerChoice;
    return this;
  }

  GameStateBuilder withActionPrompt(ActionPrompt prompt) {
    _actionPrompt = prompt;
    _nightSubView = prompt.actionTypes.length > 1
        ? NightSubView.seerChoice
        : NightSubView.actionPrompt;
    return this;
  }

  GameStateBuilder withActionResult(ActionResult result) {
    _lastActionResult = result;
    _nightSubView = NightSubView.actionResult;
    return this;
  }

  GameStateBuilder withRolesInGame(List<RoleInGame> roles) {
    _rolesInGame = roles;
    return this;
  }

  GameSessionState build() {
    return GameSessionState(
      gameId: _gameId,
      phase: _phase,
      currentWave: _currentWave,
      deadline: _deadline,
      yourRole: YourRole(
        originalRole: _originalRole,
        hasActed: _hasActed,
        currentRole: _currentRole,
      ),
      players: _players,
      nightSubView: _nightSubView,
      actionPrompt: _actionPrompt,
      lastActionResult: _lastActionResult,
      hasVoted: _hasVoted,
      voteProgress: _voteProgress,
      voteRevealData: _voteRevealData,
      isHost: _isHost,
      rolesInGame: _rolesInGame,
    );
  }
}
