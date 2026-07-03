import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/core/debug/debug_api_client.dart';
import 'package:midnight_village/core/debug/debug_models.dart';
import 'package:midnight_village/core/debug/debug_oracle.dart';
import 'package:midnight_village/core/debug/debug_table_controller.dart';

import 'harness_config.dart';
import 'scenario_dsl.dart';

/// Drives a [HarnessScenario] through the real backend and exposes the
/// resulting [DebugTable] + assertion helpers (contract §D4, API runner).
///
/// This is the API-runner core: it creates the table, runs the night script,
/// advances phases, runs the vote script, finalizes, and asserts the oracle +
/// results against the scenario's [ScenarioExpectation].
///
/// It is INDEPENDENT of Riverpod: it constructs its own [DebugTableController]
/// with no-op session/invalidation hooks (the API runner never changes the
/// visible perspective — that is the UI runner's job). The §D2 client targets
/// the harness backend on 127.0.0.1:8001.
class ScenarioRunner {
  ScenarioRunner(this.scenario, {DebugApiClient? client})
    : _client =
          client ??
          DebugApiClient(
            baseUrl: HarnessConfig.apiBaseUrl,
            origin: HarnessConfig.origin,
          ) {
    _controller = DebugTableController(
      client: _client,
      // API runner never switches perspective; these are intentional no-ops.
      adoptSession: (_, {required accessToken, required refreshToken}) async {},
      invalidateGameProviders: (_) {},
    );
  }

  final HarnessScenario scenario;
  final DebugApiClient _client;
  late final DebugTableController _controller;

  DebugTable? _table;
  DebugTable get table => _table!;
  DebugTableController get controller => _controller;

  /// user_id → display name (for failure messages).
  late final Map<int, String> _nameById;
  late final Map<String, int> _idByName;

  // ---------------------------------------------------------------------------
  // Setup
  // ---------------------------------------------------------------------------

  /// Creates the table with the scenario's forced assignment.
  Future<DebugTable> setUp() async {
    final table = await _controller.createTable(
      playerNames: scenario.playerNames,
      roleCounts: scenario.roleCounts,
      playerRolesByName: scenario.playerRoles,
      centerCards: scenario.centerCards,
    );
    _table = table;
    _idByName = {for (final p in table.players) p.displayName: p.userId};
    _nameById = {for (final p in table.players) p.userId: p.displayName};
    return table;
  }

  int idFor(String name) {
    final id = _idByName[name];
    if (id == null) {
      throw StateError('Unknown player name "$name" in ${scenario.name}');
    }
    return id;
  }

  DebugPlayer playerFor(String name) => table.playerById(idFor(name));

  // ---------------------------------------------------------------------------
  // Driving the night + voting
  // ---------------------------------------------------------------------------

  /// Runs the night WAVE-BY-WAVE.
  ///
  /// The backend AUTO-ADVANCES a wave the instant every required actor in it has
  /// submitted (`check_and_maybe_advance` after each `action/`). So the runner
  /// must NOT also call `advance-wave` for a fully-scripted wave — doing so
  /// double-advances and skips the next wave straight to discussion (the
  /// original bug: "left night before reaching wave 3"). Instead, submit a
  /// wave's actions in script order and let the server move on; only `advance-
  /// wave` an ACTIVE wave the script chose not to cover (no actor submits, so
  /// the server would otherwise wait out the full wall-clock wave timer).
  ///
  /// Walks waves 1..4 in order rather than just the scripted ones, so an
  /// unscripted-but-active wave sandwiched between two scripted waves is skipped
  /// rather than blocking. Wave 1's Doppelganger two-step (peek, then a
  /// follow-up as the copied role) is handled naturally: the server resets
  /// `has_acted` and stays in wave 1 after the peek, so the awaited follow-up
  /// submission lands before the wave advances.
  Future<void> runNight() async {
    for (var wave = 1; wave <= 4; wave++) {
      final state = await oracle();
      if (state.phase != 'night') return; // night already fully resolved
      if (state.currentWave != wave) continue; // wave inactive / already past

      final actions = scenario.nightScript
          .where((a) => a.wave == wave)
          .toList();

      if (actions.isEmpty) {
        // Active wave with required actors but no scripted action: force-skip
        // it (the host endpoint marks non-submitters as skipped and advances).
        await _controller.driveAs(table.host, const DebugAction.advanceWave());
        continue;
      }

      for (final action in actions) {
        await _controller.driveAs(
          playerFor(action.actorName),
          DebugAction.nightAction(
            actionType: action.actionType,
            targets: _resolveTargets(action.targets),
          ),
        );
      }

      // Let the server auto-advance now that this wave's actors have all acted.
      await _waitForWaveToLeave(wave);
    }
  }

  /// Polls until the game is no longer in [wave] (the server auto-advanced after
  /// the wave's actors all submitted), bounded so a stuck wave throws rather
  /// than hangs. Phase leaving `night` also satisfies this (the last wave
  /// advancing transitions to discussion).
  Future<void> _waitForWaveToLeave(
    int wave, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      final state = await oracle();
      if (state.phase != 'night' || state.currentWave != wave) return;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    throw StateError(
      '${scenario.name}: wave $wave did not auto-advance within $timeout '
      '(all scripted actions submitted — a required actor may be unscripted)',
    );
  }

  /// Translates DSL target placeholders (`_targetName`, `_targetNames`, `_self`)
  /// to wire shapes (`player_id`, `player_ids`). Already-wire-shaped keys
  /// (`center_index`, `center_indices`) pass through unchanged.
  Map<String, dynamic> _resolveTargets(Map<String, dynamic> raw) {
    if (raw.isEmpty) return const {};
    final out = <String, dynamic>{};
    raw.forEach((key, value) {
      switch (key) {
        case '_targetName':
          out['player_id'] = idFor(value as String);
        case '_targetNames':
          out['player_ids'] = (value as List)
              .map((n) => idFor(n as String))
              .toList();
        case '_self':
          // Insomniac self-check: backend infers self; no target id needed.
          break;
        default:
          out[key] = value;
      }
    });
    return out;
  }

  /// Advances the game through the night waves via the host `advance-wave`
  /// endpoint until the phase leaves `night`. Each call is idempotent on the
  /// backend; we bound the loop to avoid spinning forever on a stuck phase.
  Future<void> advanceThroughNight() async {
    for (var i = 0; i < 8; i++) {
      final state = await oracle();
      if (state.phase != 'night') return;
      await _controller.driveAs(table.host, const DebugAction.advanceWave());
    }
    final state = await oracle();
    if (state.phase == 'night') {
      throw StateError(
        '${scenario.name}: still in night after 8 advance-wave calls',
      );
    }
  }

  /// Moves from discussion → voting via the host `end-discussion` endpoint.
  Future<void> endDiscussion() async {
    await _controller.driveAs(table.host, const DebugAction.endDiscussion());
  }

  /// Submits the scripted votes, then finalizes.
  ///
  /// The backend has no explicit-abstain vote: `target_player_id` is required
  /// and must be a real player, and a non-voter is finalized as abstaining when
  /// `reveal-votes` runs. So an abstain entry (`targetName == null`) is simply
  /// NOT submitted — the player is left unvoted and `reveal-votes` marks them
  /// abstaining.
  ///
  /// The backend also AUTO-REVEALS once every player has voted (`submit_vote`
  /// transitions voting → results on the final vote). When the script has no
  /// abstainers, that auto-reveal fires on the last vote and an explicit
  /// `reveal-votes` would 400 ("not in the voting phase"). So we only call
  /// `reveal-votes` when the game is still in voting (i.e. abstainers kept it
  /// from auto-revealing).
  Future<void> runVoteScript() async {
    for (final vote in scenario.voteScript) {
      if (vote.targetName == null) continue; // abstain = do not submit a vote
      await _controller.driveAs(
        playerFor(vote.voterName),
        DebugAction.vote(voteTargetUserId: idFor(vote.targetName!)),
      );
    }
    // Finalize only if the all-voted auto-reveal hasn't already transitioned us.
    final state = await oracle();
    if (state.phase == 'voting') {
      await _controller.driveAs(table.host, const DebugAction.revealVotes());
    }
  }

  /// Drives the full happy path: night → discussion → voting → results.
  Future<void> runToResults() async {
    await runNight();
    await advanceThroughNight();
    await _waitForPhase('discussion');
    await endDiscussion();
    await _waitForPhase('voting');
    await runVoteScript();
    await _waitForPhase('results');
  }

  /// Polls the oracle until [phase] is reached, with a bounded wall-clock
  /// timeout that throws on expiry (never an unbounded wait).
  Future<void> _waitForPhase(
    String phase, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      final state = await oracle();
      if (state.phase == phase) return;
      await Future<void>.delayed(const Duration(milliseconds: 150));
    }
    final state = await oracle();
    throw StateError(
      '${scenario.name}: phase "$phase" not reached within $timeout '
      '(current: "${state.phase}")',
    );
  }

  Future<DebugOracleState> oracle() => _controller.oracle();

  // ---------------------------------------------------------------------------
  // Assertions
  // ---------------------------------------------------------------------------

  /// Asserts the full final-state table against the scenario's expectation:
  /// per-player current_role, team, Doppelganger copied role, recorded night
  /// results, winners, eliminations + reasons.
  Future<void> assertFinalState() async {
    final state = await oracle();
    final expected = scenario.expected;

    // 1. Per-player current_role (post-swap truth, oracle-only) + team.
    expected.finalRolesByName.forEach((name, role) {
      final p = state.playerById(idFor(name));
      expect(
        p.currentRole,
        role,
        reason: '${scenario.name}: $name current_role',
      );
    });
    expected.teamsByName.forEach((name, team) {
      final p = state.playerById(idFor(name));
      expect(p.team, team, reason: '${scenario.name}: $name team');
    });

    // 2. Doppelganger copied roles.
    expected.doppelgangerCopiedByName.forEach((name, copied) {
      final p = state.playerById(idFor(name));
      expect(
        p.doppelgangerCopiedRole,
        copied,
        reason: '${scenario.name}: $name doppelganger_copied_role',
      );
    });

    // 3. Recorded night-action results (intra-wave ordering proof). Matched by
    //    (player, action_type); keys may be dotted for nested results (e.g.
    //    a lone Werewolf's `center_card.role`).
    for (final check in expected.nightResultChecks) {
      final result = state.actionResultFor(
        idFor(check.actorName),
        actionType: check.actionType,
      );
      expect(
        result,
        isNotNull,
        reason:
            '${scenario.name}: no logged "${check.actionType}" action for '
            '${check.actorName} (as ${check.roleActingAs})',
      );
      check.expectedResultContains.forEach((key, value) {
        expect(
          _dottedLookup(result!, key),
          value,
          reason:
              '${scenario.name}: ${check.actorName} (${check.roleActingAs}) '
              'result[$key]',
        );
      });
    }

    // 4. Winners (set-equal, lowercase).
    expect(
      state.results?.winningTeams ?? <String>{},
      expected.winningTeams,
      reason: '${scenario.name}: winning_teams',
    );

    // 5. Eliminations + reasons.
    final eliminated = _eliminatedFromResults(state.results);
    expect(
      eliminated.keys.toSet(),
      expected.eliminatedNames,
      reason: '${scenario.name}: eliminated set',
    );
    expected.eliminationReasons.forEach((name, reason) {
      expect(
        eliminated[name],
        reason,
        reason: '${scenario.name}: $name elimination_reason',
      );
    });
  }

  /// Looks up a possibly-dotted [key] (`center_card.role`) in a result map,
  /// descending into nested maps. Returns null if any segment is missing.
  Object? _dottedLookup(Map<String, dynamic> result, String key) {
    if (!key.contains('.')) return result[key];
    Object? current = result;
    for (final segment in key.split('.')) {
      if (current is Map && current.containsKey(segment)) {
        current = current[segment];
      } else {
        return null;
      }
    }
    return current;
  }

  /// Parses eliminated player names → elimination reason from the results.
  ///
  /// Real results shape (backend `_build_results`):
  /// `eliminated_players: [<user_id>, …]` and
  /// `elimination_reasons: {"<user_id>": "vote"|"hunter_chain"}`.
  Map<String, String> _eliminatedFromResults(DebugOracleResults? results) {
    if (results == null) return {};
    final eliminated = results.raw['eliminated_players'];
    if (eliminated is! List) return {};
    final reasons = results.raw['elimination_reasons'];
    final reasonsMap = reasons is Map ? reasons : const {};
    final out = <String, String>{};
    for (final raw in eliminated) {
      final id = raw is num ? raw.toInt() : int.tryParse('$raw');
      if (id == null) continue;
      final name = _nameById[id];
      if (name == null) continue;
      out[name] = (reasonsMap['$id'] as String?) ?? 'vote';
    }
    return out;
  }
}
