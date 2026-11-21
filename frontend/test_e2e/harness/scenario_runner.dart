import 'dart:convert';

import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/core/debug/debug_models.dart';
import 'package:midnight_village/core/debug/debug_oracle.dart';
import 'package:midnight_village/core/debug/debug_table_controller.dart';

import 'debug_oracle_diff.dart';
import 'failure_report.dart';
import 'live_table.dart';
import 'scenario_dsl.dart';

/// Game timers for the harness: every night window closes as soon as every
/// phone has chosen (`night_min_window_seconds` and
/// `night_doppelganger_window_seconds` are 0), discussion and voting wait for the
/// host, and `night_wave_seconds` is a long maximum so a window that someone
/// never answers has a real timer for `debug-fire-timer` to fire. The table keeps
/// the look stage the app's tables have (`card_look_seconds` from `defaults:
/// "v2"`): every phone taps ready, then the night opens.
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
/// The game is played the way phones play it: the look stage (everyone taps
/// ready), then each night window where every phone WITH a choice sends one
/// `choose` (a phone with nothing to choose sends nothing) with 0
/// to 2 picks (the Doppelganger a second, for her follow-up, when her prompt's
/// `chooses_left` asks for it), then the talk ended by the host, lock-in votes
/// and the host's reveal; every request names the `stage` the player's `/me/`
/// carries. The runner never decides a rule: it reads each player's own
/// prompt `kind` from `GET .../me/` and turns the game's `ch` choices into
/// picks for it ([picks]). A recorded "does nothing" (the original night's
/// explicit `skip`) is an empty choose: the server applies the role's default.
///
/// Independent of Riverpod: its [DebugTableController] has no-op session hooks
/// (the API runner never changes the visible perspective).
class ReferenceGameRunner {
  ReferenceGameRunner(this.game, {this.timerSettings = fastTimers})
    : _controller = harnessClients().controller;

  final ReferenceGame game;
  final Map<String, int> timerSettings;
  final DebugTableController _controller;

  DebugTable? _table;
  DebugTable get table => _table!;
  DebugTableController get controller => _controller;

  /// Window numbers the runner closed with the timer hook (for assertions).
  final List<int> windowsClosedByTimer = [];

  /// Per night window, the user ids whose prompt had nothing to choose (kind
  /// `none`, nothing sent yet) when the runner read it.
  final Map<int, Set<int>> sleepers = {};

  /// The oracle's count of chooses from every [sleepers] phone is 0: the
  /// server took nothing from a phone with nothing to choose.
  Future<void> assertSleepersSentNothing() async {
    final state = await oracle();
    for (final MapEntry(key: window, value: ids) in sleepers.entries) {
      for (final player in state.players.where((p) => ids.contains(p.userId))) {
        expect(
          player.chosen[window] ?? 0,
          0,
          reason:
              '${game.name}: ${player.displayName} sent a choose in '
              'window $window with nothing to choose',
        );
      }
    }
  }

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

  /// Plays the night to the end: the look stage, then every phone answers its
  /// prompt until the game leaves the night phase. Bounded: throws instead of
  /// waiting forever.
  Future<void> runNight() async {
    for (var pass = 0; pass < 40; pass++) {
      final state = await oracle();
      if (state.phase != 'night') return;

      var sent = false;
      for (var i = 0; i < game.players.length; i++) {
        final view = await _controller.playerView(playerAt(i));
        if (view['phase'] != 'night') break;
        final progress = view['progress'];
        if (progress is Map && progress['stage'] == 'look') {
          if (view['ready'] != true) {
            await _controller.stagedAs(playerAt(i), 'ready', {'ready': true});
            sent = true;
          }
          continue;
        }
        final prompt = view['action_prompt'];
        if (prompt is! Map<String, dynamic>) continue;
        if (prompt['kind'] == 'none' && prompt['chosen'] == 0) {
          (sleepers[prompt['window'] as int] ??= {}).add(playerAt(i).userId);
        }
        if ((prompt['chooses_left'] as int) < 1) continue;
        await _controller.stagedAs(playerAt(i), 'action', {
          'action_type': 'choose',
          'picks': picks(i, prompt),
        });
        sent = true;
      }

      if (!sent && (await oracle()).phase == 'night') {
        // Every phone has done its part and the window is still open: close it
        // as its timer would.
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

  /// The picks player [index] sends for [prompt], from the game's `ch`
  /// choices; `[]` when they do nothing (or have nothing to choose).
  ///
  /// The prompt's `kind` is the SERVER's word for what this phone may do now
  /// (the Doppelganger's look, then her follow-up as the copied role; a lone
  /// Werewolf): the runner decides nothing about the rules.
  List<Map<String, Object>> picks(int index, Map<String, dynamic> prompt) {
    final kind = prompt['kind'] as String;
    final ch = game.choices;
    final isDoppelganger = game.dealt[index] == 'Doppelganger';
    Object? own(String key) => isDoppelganger ? ch['doppel_follow'] : ch[key];
    Map<String, Object> player(int i) => {'player_id': idAt(i)};
    Map<String, Object> center(int i) => {'center_index': i};

    switch (kind) {
      case 'doppelganger_look':
        final target = ch['doppel_target'] as int?;
        return target == null ? [] : [player(target)];
      case 'seer':
        final c = own('seer') as List?;
        if (c == null) return [];
        if (c.first == 'player') return [player(c[1] as int)];
        return [for (final i in (c[1] as List).cast<int>()) center(i)];
      case 'robber':
        final c = own('robber') as int?;
        return c == null ? [] : [player(c)];
      case 'troublemaker':
        final c = own('troublemaker') as List?;
        return c == null ? [] : [player(c[0] as int), player(c[1] as int)];
      case 'drunk':
        final c = own('drunk') as int?;
        return c == null ? [] : [center(c)];
      case 'lone_werewolf':
        final c = ch['wolf_center'] as int?;
        return c == null ? [] : [center(c)];
      case 'none':
        return [];
    }
    throw StateError('${game.name}: no picks for a prompt of kind $kind');
  }

  // ---------------------------------------------------------------------------
  // The day
  // ---------------------------------------------------------------------------

  /// Discussion -> voting -> results for a full game: the host ends the
  /// discussion, everyone votes (pick and lock) as recorded, the host reveals
  /// if anyone abstained (the last lock reveals otherwise).
  Future<void> runDay() async {
    final votes = game.votes;
    if (votes == null) {
      throw StateError('${game.name} is a night-only game');
    }
    await _waitForPhase('discussion');
    await _controller.stagedAs(table.host, 'end-discussion', {});
    await _waitForPhase('voting');
    for (final entry in votes.entries) {
      final target = entry.value;
      if (target == null) continue; // abstain: not submitted
      await _controller.stagedAs(playerAt(entry.key), 'vote', {
        'target_player_id': idAt(target),
        'lock': true,
      });
    }
    if ((await oracle()).phase == 'voting') {
      await _controller.stagedAs(table.host, 'reveal-votes', {});
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
