@Tags(['e2e'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'harness/failure_report.dart';
import 'harness/harness_config.dart';
import 'harness/scenario_runner.dart';
import 'harness/scenarios.dart';
import 'harness/ui_harness.dart';

/// UI runner (contract §D4) — the `uiCritical` subset only.
///
/// Boots the REAL widget tree against the harness backend, switches to each
/// scenario's relevant player via `adoptSession` (no refresh), drives the game
/// via the §D2 client, and captures `RepaintBoundary.toImage()` PNG filmstrips
/// to `integration_test/screenshots/<scenario>/NN-<state>.png`.
///
/// ## Surface
///
/// Plain `flutter test` on the host Dart VM under the NORMAL `testWidgets`
/// binding — NOT `IntegrationTestWidgetsFlutterBinding` (that is the
/// device-bound path, which falls back to a web device with no macOS app target
/// and dies with "Web devices are not supported for integration tests yet").
/// `RepaintBoundary(GlobalKey).toImage()` inside `tester.runAsync()` writes a
/// real PNG with no hang under this binding, with real fonts loaded.
///
/// ## What is asserted (and what is NOT)
///
/// The harness switches a perspective IN to an already-running game (provisioned
/// via the API). The app's `RoleRevealView` is a FRESH-night-entry animation
/// driven by the `phase.change` WS event; a player who loads mid-night via
/// `/me/` is hydrated straight into `waiting`/`actionPrompt` — the role-reveal
/// is never shown on a switch-in. So the original_role-on-role-reveal assertion
/// in the original contract draft can never pass for this driving model and is
/// intentionally NOT made here (reported as a finding).
///
/// What IS asserted, per perspective:
/// - the real game screen mounted for that player (the PhaseIndicator renders),
///   proving switch-in + live game state loaded into the real widget tree;
/// - the hidden-info guard: when a player's post-swap `current_role` differs
///   from their `original_role`, the post-swap truth MUST NOT appear on their
///   (pre-results) screen — it is oracle-only.
/// The PNG filmstrips are the primary artifact an agent reads.
void main() {
  // `testWidgets` uses the normal (non-device) binding on the host VM.
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await HarnessConfig.setUp();
    // The app persists the JWT + user in flutter_secure_storage and the
    // interceptor reads it per request; back it with an in-memory map since the
    // host VM has no secure-storage plugin (otherwise switchTo/openGame stall).
    HarnessConfig.stubSecureStorage();
    // Real glyphs for legible filmstrips (binding is up; UI runner only).
    await HarnessConfig.loadFonts();
  });

  final uiScenarios = allScenarios.where((s) => s.isUiCritical).toList();

  for (final scenario in uiScenarios) {
    testWidgets('UI: ${scenario.name}', (tester) async {
      final runner = ScenarioRunner(scenario);
      final ui = UiHarness(tester);

      try {
        // 1. Provision the table + forced assignment via the API path. ALL
        //    ScenarioRunner network must run inside runAsync: under the
        //    automated binding, real Dio/WS only progresses in the real zone.
        await tester.runAsync(() => runner.setUp());

        // 2. Boot the real widget tree pointed at the harness backend.
        await ui.pumpApp();

        // 3. Pre-results perspectives: switch in, mount the game screen with
        //    state pre-loaded, assert the screen + the hidden-info guard, and
        //    capture a filmstrip frame.
        for (final check in scenario.uiChecks.where(
          (c) => !c.frameName.contains('results'),
        )) {
          final player = runner.playerFor(check.perspectiveName);

          await ui.switchTo(
            userId: player.userId,
            displayName: player.displayName,
            accessToken: player.accessToken,
            refreshToken: player.refreshToken,
            gameId: runner.table.gameId,
          );
          await ui.openGame(runner.table.gameId);

          // The game screen mounted for this perspective (PhaseIndicator is the
          // stable anchor present in every non-loading game phase).
          await ui.pumpUntil(
            () => ui.gameScreenRendered,
            reason:
                '${scenario.name}: game screen for ${player.displayName} '
                'did not render',
          );

          // Hidden-info guard: a player's post-swap current_role (when it
          // differs from their dealt role) is oracle-only and must NOT leak onto
          // their pre-results screen.
          final oracle = await tester.runAsync(() => runner.oracle());
          final truth = oracle!.playerById(player.userId);
          if (truth.currentRole != truth.originalRole) {
            expect(
              find.text(truth.currentRole),
              findsNothing,
              reason:
                  '${scenario.name}: post-swap current_role '
                  '"${truth.currentRole}" leaked into a pre-results screen for '
                  '${player.displayName}',
            );
          }

          await ui.captureFrame(scenario.name, check.frameName);
        }

        // 4. Drive the scenario through to results.
        await tester.runAsync(() => runner.runToResults());

        // 5. Results perspectives: switch in, wait for the results screen, and
        //    capture the final filmstrip.
        for (final check in scenario.uiChecks.where(
          (c) => c.frameName.contains('results'),
        )) {
          final player = runner.playerFor(check.perspectiveName);
          await ui.switchTo(
            userId: player.userId,
            displayName: player.displayName,
            accessToken: player.accessToken,
            refreshToken: player.refreshToken,
            gameId: runner.table.gameId,
          );
          await ui.openGame(runner.table.gameId);
          await ui.pumpUntil(
            () =>
                find.byKey(const ValueKey('results')).evaluate().isNotEmpty ||
                find
                    .byKey(const ValueKey('results-loading'))
                    .evaluate()
                    .isNotEmpty,
            reason:
                '${scenario.name}: results screen for ${player.displayName}',
          );
          await ui.captureFrame(scenario.name, check.frameName);
        }
      } catch (e) {
        FailureReport.record(
          scenario: scenario.name,
          checkpoint: 'ui-runner',
          message: e.toString(),
          pngPath: 'integration_test/screenshots/${scenario.name}/',
        );
        rethrow;
      } finally {
        // Unmount + dispose so the binding's end-of-test `!timersPending`
        // assertion holds (the game tree + live socket arm long-lived timers).
        await ui.tearDownHarness();
      }
    });
  }
}
