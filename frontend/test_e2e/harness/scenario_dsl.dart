/// Scenario-as-data DSL for the ONUW integration harness (contract §D4).
///
/// One [HarnessScenario] per reference scenario in
/// `docs/specs/frontend/validation/scenarios.md`. Scenarios are pure data: the
/// API runner and UI runner interpret them against a booted real backend.
///
/// Encoding rules (contract §D4):
/// - Player roles + center are TitleCase canonical names.
/// - Night action targets use the encoding in [NightAction] factories.
/// - A declined/optional-skip action = the same `actionType` with empty
///   `targets:{}` (no fire-timer needed).
/// - Teams are {werewolf,village,neutral}; `winning_teams` lowercase, set-equal.
/// - Elimination reasons ∈ {vote, hunter_chain}; eliminations as a SET of names.
/// - Oracle checkpoints are per-wave boundaries; intra-wave ordering is asserted
///   via each actor's recorded `result` in the log.
library;

/// Tags drive which runner picks up a scenario. `uiCritical` scenarios also run
/// through the UI runner (real widgets + PNG filmstrips).
enum ScenarioTag { uiCritical }

/// A complete, executable reference scenario.
class HarnessScenario {
  const HarnessScenario({
    required this.name,
    required this.tags,
    required this.playerNames,
    required this.playerRoles,
    required this.centerCards,
    required this.nightScript,
    required this.voteScript,
    required this.expected,
    this.uiChecks = const [],
  });

  /// Human-readable scenario name (matches scenarios.md), used in filmstrip dirs
  /// and failure output.
  final String name;

  final Set<ScenarioTag> tags;

  /// Ordered player display names. The FIRST is the host / lobby creator.
  final List<String> playerNames;

  /// Player display name → forced TitleCase role.
  final Map<String, String> playerRoles;

  /// Exactly 3 TitleCase center cards.
  final List<String> centerCards;

  /// Night actions in execution order. Each is driven AS the actor (by name)
  /// via the explicit-per-player-token client; the runner resolves names → ids.
  final List<NightAction> nightScript;

  /// Votes by actor name → target name (null target = abstain).
  final List<VoteEntry> voteScript;

  /// The authoritative truth this scenario must produce, asserted via the
  /// oracle + results endpoints.
  final ScenarioExpectation expected;

  /// UI-runner checks (filmstrip + rendered-role assertions). Only meaningful
  /// for `uiCritical` scenarios.
  final List<UiCheck> uiChecks;

  /// Derived TitleCase role-count map for the lobby PATCH, from [playerRoles] +
  /// [centerCards].
  Map<String, int> get roleCounts {
    final counts = <String, int>{};
    for (final role in [...playerRoles.values, ...centerCards]) {
      counts[role] = (counts[role] ?? 0) + 1;
    }
    return counts;
  }

  bool get isUiCritical => tags.contains(ScenarioTag.uiCritical);
}

/// A single night action, driven AS [actorName] during [wave].
///
/// Use the named factories for the contract §D4 target encodings. Actions are
/// wave-gated on the server: the runner buckets the night script by [wave] and
/// submits each bucket while that wave is active, advancing between waves via
/// the host `advance-wave` endpoint.
class NightAction {
  const NightAction._({
    required this.wave,
    required this.actorName,
    required this.actionType,
    required this.targets,
  });

  /// `peek_player {player_id}` — Seer / Doppelganger peeks a player.
  factory NightAction.peekPlayer({
    required int wave,
    required String actor,
    required String targetName,
  }) => NightAction._(
    wave: wave,
    actorName: actor,
    actionType: 'peek_player',
    targets: {'_targetName': targetName},
  );

  /// `peek_center {center_indices:[i,j]}` — Seer peeks exactly 2 center cards.
  factory NightAction.peekCenter({
    required int wave,
    required String actor,
    required List<int> centerIndices,
  }) {
    assert(centerIndices.length == 2, 'peek_center requires exactly 2 indices');
    return NightAction._(
      wave: wave,
      actorName: actor,
      actionType: 'peek_center',
      targets: {'center_indices': centerIndices},
    );
  }

  /// `swap_with_player {player_id}` — Robber swaps with a player.
  factory NightAction.swapWithPlayer({
    required int wave,
    required String actor,
    required String targetName,
  }) => NightAction._(
    wave: wave,
    actorName: actor,
    actionType: 'swap_with_player',
    targets: {'_targetName': targetName},
  );

  /// `swap_others {player_ids:[a,b]}` — Troublemaker swaps two other players.
  factory NightAction.swapOthers({
    required int wave,
    required String actor,
    required String targetName1,
    required String targetName2,
  }) => NightAction._(
    wave: wave,
    actorName: actor,
    actionType: 'swap_others',
    targets: {
      '_targetNames': [targetName1, targetName2],
    },
  );

  /// `swap_with_center {center_index:i}` — Drunk swaps with a center card.
  factory NightAction.swapWithCenter({
    required int wave,
    required String actor,
    required int centerIndex,
  }) => NightAction._(
    wave: wave,
    actorName: actor,
    actionType: 'swap_with_center',
    targets: {'center_index': centerIndex},
  );

  /// `see_team {center_index:i}` — lone Werewolf peeks one center card.
  factory NightAction.loneWerewolfPeek({
    required int wave,
    required String actor,
    required int centerIndex,
  }) => NightAction._(
    wave: wave,
    actorName: actor,
    actionType: 'see_team',
    targets: {'center_index': centerIndex},
  );

  /// Insomniac self-check. The Insomniac's role `action_types` is `(none,)`:
  /// the backend auto-reveals their final card, so the action carries the
  /// `none` action type and no target (the `_self` placeholder resolves to
  /// empty targets). Submitting `peek_player` here is rejected ("Invalid action
  /// type for this wave") — only `none` is valid for the Insomniac.
  factory NightAction.insomniacSelfCheck({
    required int wave,
    required String actor,
  }) => NightAction._(
    wave: wave,
    actorName: actor,
    actionType: 'none',
    targets: {'_self': true},
  );

  /// Declined / optional-skip: same `actionType` with empty `targets:{}` (no
  /// fire-timer needed). Used e.g. for scenario 2's declined lone-WW peek.
  factory NightAction.decline({
    required int wave,
    required String actor,
    required String actionType,
  }) => NightAction._(
    wave: wave,
    actorName: actor,
    actionType: actionType,
    targets: {},
  );

  /// The night wave (1-4) during which this action is submitted.
  final int wave;
  final String actorName;
  final String actionType;

  /// Either already-wire-shaped (`center_index`, `center_indices`) OR carrying a
  /// `_targetName` / `_targetNames` / `_self` placeholder the runner resolves to
  /// `player_id` / `player_ids` using captured user ids.
  final Map<String, dynamic> targets;
}

/// A vote: [voterName] votes for [targetName] (null = abstain).
class VoteEntry {
  const VoteEntry({required this.voterName, required this.targetName});
  final String voterName;
  final String? targetName;
}

/// The authoritative truth a scenario must produce.
class ScenarioExpectation {
  const ScenarioExpectation({
    required this.finalRolesByName,
    required this.teamsByName,
    required this.winningTeams,
    required this.eliminatedNames,
    this.eliminationReasons = const {},
    this.doppelgangerCopiedByName = const {},
    this.nightResultChecks = const [],
  });

  /// Player name → expected `current_role` (post-swap truth, oracle-only).
  final Map<String, String> finalRolesByName;

  /// Player name → expected team {werewolf,village,neutral}.
  final Map<String, String> teamsByName;

  /// Lowercase tokens, asserted as a SET (⊂ {village,werewolf,tanner}).
  final Set<String> winningTeams;

  /// Eliminated player names, asserted as a SET.
  final Set<String> eliminatedNames;

  /// Player name → elimination reason {vote, hunter_chain}, for those eliminated.
  final Map<String, String> eliminationReasons;

  /// Doppelganger card holders → the role they copied (oracle
  /// `doppelganger_copied_role`).
  final Map<String, String> doppelgangerCopiedByName;

  /// Assertions against individual recorded night-action results in the log
  /// (e.g. a Seer's peek showed "Werewolf"). The runner asserts these against
  /// the `night_actions_log`.
  final List<NightResultCheck> nightResultChecks;
}

/// Asserts that [actorName]'s recorded night action of type [actionType]
/// produced a result containing [expectedResultContains] (subset match on the
/// `result` map; supports dotted keys like `center_card.role` for nested
/// values).
///
/// Matches on (player_id, action_type) — the stable join key. [roleActingAs]
/// is recorded in the scenario data for readability but is not used for the
/// lookup (the oracle records `role_acting_as` at action time, but action_type
/// remains the cleaner join key).
class NightResultCheck {
  const NightResultCheck({
    required this.actorName,
    required this.roleActingAs,
    required this.actionType,
    required this.expectedResultContains,
  });

  final String actorName;
  final String roleActingAs;

  /// The wire `action_type` recorded in the log (`peek_player`, `swap_with_
  /// player`, `see_team`, `none`, …) — the stable join key.
  final String actionType;
  final Map<String, dynamic> expectedResultContains;
}

/// A UI-runner check: switch to [perspectiveName], capture a filmstrip frame
/// named [frameName], and (optionally) assert the RENDERED role text equals the
/// player's `original_role` (NEVER current_role — that is hidden pre-results).
class UiCheck {
  const UiCheck({
    required this.perspectiveName,
    required this.frameName,
    this.assertRenderedOriginalRole = false,
  });

  final String perspectiveName;
  final String frameName;

  /// When true, assert the role-reveal screen renders [perspectiveName]'s
  /// `original_role` as text. This is the only safe rendered-role assertion.
  final bool assertRenderedOriginalRole;
}
