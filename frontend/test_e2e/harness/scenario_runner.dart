import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/core/debug/debug_api_client.dart';
import 'package:midnight_village/core/debug/debug_models.dart';
import 'package:midnight_village/core/debug/debug_oracle.dart';
import 'package:midnight_village/core/debug/debug_table_controller.dart';

import 'debug_oracle_diff.dart';
import 'failure_report.dart';
import 'harness_config.dart';
import 'scenario_dsl.dart';

/// Game timers for the harness: every night window closes as soon as its last
/// actor has submitted (`night_min_window_seconds` and
/// `night_doppelganger_window_seconds` are 0), discussion and voting wait for the
/// host, and `night_wave_seconds` is a long maximum so a window that someone
/// never answers has a real timer for `debug-fire-timer` to fire.
const Map<String, int> fastTimers = {
  'night_wave_seconds': 600,
  'night_min_window_seconds': 0,
  'night_doppelganger_window_seconds': 0,
  'discussion_seconds': 0,
  'voting_seconds': 0,
};

/// Drives a [ReferenceGame] through the real backend and checks the result
/// against the recorded outcome (API runner core).
///
/// The night is two windows (1 = Doppelganger, 2 = everyone else). The runner
/// never hard-codes who acts when: it asks each player's own `GET .../me/` for
/// their pending `action_prompt` and answers it from the game's `ch` choices.
/// It submits everything a window is waiting for; a player with no choice who
/// is not offered `skip` (the Drunk, the Doppelganger's look) simply does not
/// answer, and the runner closes the window with the `debug-fire-timer` hook,
/// like a timeout.
///
/// Independent of Riverpod: its [DebugTableController] has no-op session hooks
/// (the API runner never changes the visible perspective).
class ReferenceGameRunner {
  ReferenceGameRunner(
    this.game, {
    DebugApiClient? client,
    this.timerSettings = fastTimers,
  }) : _client =
           client ??
           DebugApiClient(
             baseUrl: HarnessConfig.apiBaseUrl,
             origin: HarnessConfig.origin,
           ) {
    _controller = DebugTableController(
      client: _client,
      adoptSession: (_, {required accessToken, required refreshToken}) async {},
      invalidateGameProviders: (_) {},
    );
  }

  final ReferenceGame game;
  final Map<String, int> timerSettings;
  final DebugApiClient _client;
  late final DebugTableController _controller;

  DebugTable? _table;
  DebugTable get table => _table!;
  DebugTableController get controller => _controller;

  /// Window numbers the runner closed with the timer hook (for assertions).
  final List<int> windowsClosedByTimer = [];

  // ---------------------------------------------------------------------------
  // Setup
  // ---------------------------------------------------------------------------

  /// Creates the table with the game's forced assignment and the harness timers.
  Future<DebugTable> setUp() async {
    final table = await _controller.createTable(
      playerNames: game.players,
      roleCounts: game.roleCounts,
      playerRolesByName: {
        for (var i = 0; i < game.players.length; i++)
          game.players[i]: game.dealt[i],
      },
      centerCards: game.center,
      timerSettings: timerSettings,
    );
    _table = table;
    return table;
  }

  DebugPlayer playerAt(int index) => table.players[index];
  int idAt(int index) => playerAt(index).userId;
  int indexOfId(int userId) =>
      table.players.indexWhere((p) => p.userId == userId);
  DebugPlayer playerNamed(String name) =>
      table.players.firstWhere((p) => p.displayName == name);

  Future<DebugOracleState> oracle() => _controller.oracle();

  // ---------------------------------------------------------------------------
  // The night
  // ---------------------------------------------------------------------------

  /// Plays the night to the end: answers every prompt until the game leaves the
  /// night phase. Bounded: throws instead of waiting forever.
  Future<void> runNight() async {
    // (window, player, role acting as) already answered or deliberately left.
    final handled = <String>{};
    for (var pass = 0; pass < 40; pass++) {
      final state = await oracle();
      if (state.phase != 'night') return;

      var submitted = false;
      for (var i = 0; i < game.players.length; i++) {
        final view = await _controller.playerView(playerAt(i));
        final prompt = view['action_prompt'];
        if (prompt is! Map<String, dynamic>) continue;
        final key = '${prompt['wave']}:$i:${prompt['role_acting_as']}';
        if (!handled.add(key)) continue;
        final action = choose(i, prompt);
        if (action == null) continue; // does nothing: the window waits
        await _controller.driveAs(
          playerAt(i),
          DebugAction.nightAction(
            actionType: action.actionType,
            targets: action.targets,
          ),
        );
        submitted = true;
      }

      if (!submitted) {
        // Everyone who can answer has; the window is still open, waiting for
        // someone who does nothing. Close it as its timer would.
        final window = state.currentWave;
        final fired = await _controller.fireTimer(TimerKey.wave(window));
        if (!fired) {
          throw StateError(
            '${game.name}: window $window is open with nobody left to answer '
            'but no timer was pending to close it',
          );
        }
        windowsClosedByTimer.add(window);
      }
    }
    throw StateError('${game.name}: still in the night after 40 passes');
  }

  /// What player [index] sends for [prompt], from the game's `ch` choices, or
  /// null if they do nothing and are not offered `skip`.
  ///
  /// Everything is read from the SERVER's prompt (who acts, which action types,
  /// whether a Werewolf is alone): the runner decides nothing about the rules.
  NightMove? choose(int index, Map<String, dynamic> prompt) {
    final role = prompt['role_acting_as'] as String;
    final types = (prompt['action_types'] as List).cast<String>();
    final valid = (prompt['valid_targets'] as Map).cast<String, dynamic>();
    final ch = game.choices;
    final isDoppelganger = game.dealt[index] == 'Doppelganger';

    NightMove? skipOrNothing() =>
        types.contains('skip') ? const NightMove('skip', {}) : null;

    switch (role) {
      case 'Doppelganger':
        final target = ch['doppel_target'] as int?;
        if (target == null) return null;
        return NightMove('peek_player', {'player_id': idAt(target)});
      case 'Seer':
        final c = (isDoppelganger ? ch['doppel_follow'] : ch['seer']) as List?;
        if (c == null) return skipOrNothing();
        if (c.first == 'player') {
          return NightMove('peek_player', {'player_id': idAt(c[1] as int)});
        }
        return NightMove('peek_center', {
          'center_indices': (c[1] as List).cast<int>(),
        });
      case 'Robber':
        final c = (isDoppelganger ? ch['doppel_follow'] : ch['robber']) as int?;
        if (c == null) return skipOrNothing();
        return NightMove('swap_with_player', {'player_id': idAt(c)});
      case 'Troublemaker':
        final c =
            (isDoppelganger ? ch['doppel_follow'] : ch['troublemaker'])
                as List?;
        if (c == null) return skipOrNothing();
        return NightMove('swap_others', {
          'player_ids': [idAt(c[0] as int), idAt(c[1] as int)],
        });
      case 'Drunk':
        final c = (isDoppelganger ? ch['doppel_follow'] : ch['drunk']) as int?;
        if (c == null) return null; // the Drunk cannot skip
        return NightMove('swap_with_center', {'center_index': c});
      case 'Werewolf':
        // The server says whether this Werewolf is alone: nobody to see.
        final team = valid['see_team'];
        final lone = team is List && team.isEmpty;
        final peek = ch['wolf_center'] as int?;
        if (lone && peek != null) {
          return NightMove('see_team', {'center_index': peek});
        }
        return const NightMove('see_team', {});
      case 'Minion':
      case 'Mason':
        return const NightMove('see_team', {});
      case 'Insomniac':
        return const NightMove('none', {});
    }
    throw StateError('${game.name}: no move for a prompt as $role');
  }

  // ---------------------------------------------------------------------------
  // The day
  // ---------------------------------------------------------------------------

  /// Discussion -> voting -> results for a full game: the host ends the
  /// discussion, everyone votes as recorded (the last vote reveals).
  Future<void> runDay() async {
    final votes = game.votes;
    if (votes == null) {
      throw StateError('${game.name} is a night-only game');
    }
    await _waitForPhase('discussion');
    await _controller.driveAs(table.host, const DebugAction.endDiscussion());
    await _waitForPhase('voting');
    for (final entry in votes.entries) {
      final target = entry.value;
      if (target == null) continue; // abstain: not submitted
      await _controller.driveAs(
        playerAt(entry.key),
        DebugAction.vote(voteTargetUserId: idAt(target)),
      );
    }
    if ((await oracle()).phase == 'voting') {
      await _controller.driveAs(table.host, const DebugAction.revealVotes());
    }
    await _waitForPhase('results');
  }

  /// Night, then (for a full game) the day.
  Future<void> runToEnd() async {
    await runNight();
    await _waitForPhase('discussion');
    await assertNight();
    if (game.hasVotes) await runDay();
  }

  /// Polls the oracle until [phase] is reached (bounded; throws on expiry).
  Future<void> _waitForPhase(
    String phase, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final deadline = DateTime.now().add(timeout);
    while (DateTime.now().isBefore(deadline)) {
      if ((await oracle()).phase == phase) return;
      await Future<void>.delayed(const Duration(milliseconds: 100));
    }
    final state = await oracle();
    throw StateError(
      '${game.name}: phase "$phase" not reached within $timeout '
      '(current: "${state.phase}")',
    );
  }

  // ---------------------------------------------------------------------------
  // Assertions against the recorded outcome (via the debug-state oracle)
  // ---------------------------------------------------------------------------

  /// What the oracle says about the night, in the same keys as [_expectedNight].
  Map<String, Object?> _actualNight(DebugOracleState state) {
    final byIndex = [
      for (var i = 0; i < game.players.length; i++) state.playerById(idAt(i)),
    ];
    final copiedBy = byIndex
        .map((p) => p.doppelgangerCopiedRole)
        .whereType<String>()
        .toList();
    return {
      'final_cards': [for (final p in byIndex) p.currentRole],
      'final_center': state.centerCards,
      'teams': [for (final p in byIndex) p.team],
      'copied': copiedBy.isEmpty ? null : copiedBy.single,
      for (var i = 0; i < game.players.length; i++)
        'views.${game.players[i]}': viewsFromLog(state, i),
    };
  }

  Map<String, Object?> _expectedNight() => {
    'final_cards': game.finalCards,
    'final_center': game.finalCenter,
    'teams': game.teams,
    'copied': game.copied,
    for (var i = 0; i < game.players.length; i++)
      'views.${game.players[i]}': [
        for (final v in game.views[i] ?? const <ExpectedView>[]) v.canonical,
      ],
  };

  /// What player [index] learned, rebuilt from the oracle's night log in the
  /// recorded shape and order (`[kind, value]` as canonical JSON text).
  List<String> viewsFromLog(DebugOracleState state, int index) {
    final out = <String>[];
    void add(String kind, Object? value) => out.add(jsonEncode([kind, value]));
    List<int> indices(Object? ids) =>
        ((ids as List).map((e) => indexOfId((e as num).toInt())).toList())
          ..sort();

    for (final entry in state.nightActionsLog) {
      if (entry.playerId != idAt(index)) continue;
      final r = entry.result;
      if (entry.actionType == 'skip') continue;
      if (r.containsKey('copied_role')) {
        add('copied', r['copied_role']);
      } else if (r.containsKey('peeked_role')) {
        final target = indexOfId((entry.targets['player_id'] as num).toInt());
        add('saw_player', [target, r['peeked_role']]);
      } else if (r.containsKey('peeked_center')) {
        add('saw_center', [
          for (final c in r['peeked_center'] as List)
            [(c['index'] as num).toInt(), c['role']],
        ]);
      } else if (r.containsKey('new_role')) {
        add('took', r['new_role']);
      } else if (r.containsKey('werewolves')) {
        add('werewolves', indices(r['werewolves']));
        final c = r['center_card'] as Map?;
        if (c != null) {
          add('saw_center', [
            [(c['index'] as num).toInt(), c['role']],
          ]);
        }
      } else if (r.containsKey('masons')) {
        add('masons', indices(r['masons']));
      } else if (r.containsKey('current_role')) {
        add('own_card', r['current_role']);
      }
    }
    return out;
  }

  /// Asserts the night against the recorded outcome: every player's final card,
  /// the center, teams, the copied role, and what each player learned.
  Future<void> assertNight() async {
    final state = await oracle();
    _expectNoDiff('night', _expectedNight(), _actualNight(state), state);
  }

  /// Asserts the day against the recorded outcome (full games): votes cast,
  /// who was voted out, who died, the winners, who won, and the reason.
  Future<void> assertResults() async {
    final state = await oracle();
    final results = state.results;
    if (results == null) {
      fail('${game.name}: no results in the oracle (phase ${state.phase})');
    }
    final raw = results.raw;
    List<int> idxs(Iterable<Object?> ids) =>
        (ids.map((e) => indexOfId((e as num).toInt())).toList())..sort();

    final eliminated = (raw['eliminated_players'] as List).cast<Object?>();
    final reasons = (raw['elimination_reasons'] as Map).cast<String, Object?>();
    final outcomes = (raw['player_outcomes'] as Map).cast<String, Object?>();
    final actual = <String, Object?>{
      'votes': {
        for (final e in state.votes.entries)
          '${indexOfId(e.key)}': e.value == null ? null : indexOfId(e.value!),
      },
      'voted_out': idxs([
        for (final e in reasons.entries)
          if (e.value == 'vote') int.parse(e.key),
      ]),
      'dead': idxs(eliminated),
      'winners': results.winningTeams.toList()..sort(),
      'won': idxs([
        for (final e in outcomes.entries)
          if (e.value == 'win') int.parse(e.key),
      ]),
      'reason': raw['reason'],
    };
    final expected = <String, Object?>{
      'votes': {for (final e in game.votes!.entries) '${e.key}': e.value},
      'voted_out': [...game.votedOut!]..sort(),
      'dead': [...game.dead!]..sort(),
      'winners': [...game.winners!]..sort(),
      'won': [...game.won!]..sort(),
      'reason': game.reason,
    };
    _expectNoDiff('results', expected, actual, state);
  }

  void _expectNoDiff(
    String checkpoint,
    Map<String, Object?> expected,
    Map<String, Object?> actual,
    DebugOracleState state,
  ) {
    final diff = diffMaps(expected, actual);
    if (diff.isEmpty) return;
    final message =
        '${game.name} [$checkpoint] differs from the recorded game:\n'
        '${const JsonEncoder.withIndent('  ').convert(diff)}';
    FailureReport.record(
      scenario: game.name,
      checkpoint: checkpoint,
      message: message,
      expected: expected,
      actual: actual,
    );
    fail(message);
  }
}

/// A night action to send: wire `action_type` and `targets`.
class NightMove {
  const NightMove(this.actionType, this.targets);
  final String actionType;
  final Map<String, dynamic> targets;
}
