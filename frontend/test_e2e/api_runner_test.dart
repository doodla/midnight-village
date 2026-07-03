@Tags(['e2e'])
library;

import 'package:flutter_test/flutter_test.dart';

import 'harness/failure_report.dart';
import 'harness/harness_config.dart';
import 'harness/scenario_runner.dart';
import 'harness/scenarios.dart';

/// API runner (contract §D4) — the FULL matrix, every run.
///
/// For each of the nine scenarios: spin a fresh table with a forced assignment,
/// drive the night + vote scripts via the explicit-per-player-token client, and
/// assert the authoritative `debug-state` oracle + `results` against the
/// scenario's [ScenarioExpectation] (final roles, teams, copied roles, recorded
/// night results, winners, eliminations + reasons).
///
/// This targets the BOOTED HARNESS BACKEND on 127.0.0.1:8001. It does NOT mock
/// the backend — that is the whole point (the 773 widget tests already mock the
/// seam). It runs headless on the host VM under `flutter test`; real Dio/WS work
/// because [HarnessConfig.setUp] clears `HttpOverrides.global`.
void main() {
  setUpAll(() async {
    await HarnessConfig.setUp();
    FailureReport.reset();
  });

  for (final scenario in allScenarios) {
    test('API: ${scenario.name}', () async {
      final runner = ScenarioRunner(scenario);
      try {
        await runner.setUp();
        await runner.runToResults();
        await runner.assertFinalState();
      } catch (e) {
        // Capture a machine-readable record before rethrowing so the suite
        // still fails but an agent has structured context (scenario, message,
        // and — for assertFinalState mismatches — the oracle snapshot).
        Map<String, Object?>? actual;
        try {
          final state = await runner.oracle();
          actual = {
            'phase': state.phase,
            'winning_teams': state.results?.winningTeams.toList(),
            'players': {
              for (final p in state.players)
                p.displayName:
                    '${p.originalRole}->${p.currentRole} [${p.team}]',
            },
          };
        } catch (_) {
          actual = null;
        }
        FailureReport.record(
          scenario: scenario.name,
          checkpoint: 'final-state',
          message: e.toString(),
          actual: actual,
        );
        rethrow;
      }
    });
  }
}
