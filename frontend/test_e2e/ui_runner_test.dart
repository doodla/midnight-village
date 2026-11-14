@Tags(['e2e'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/features/game/presentation/night_result_view.dart';

import 'harness/failure_report.dart';
import 'harness/harness_config.dart';
import 'harness/scenario_dsl.dart';
import 'harness/scenario_runner.dart';
import 'harness/scenarios.dart';
import 'harness/ui_harness.dart';

/// UI runner: the representative subset ([uiCriticalIds]) through the REAL
/// widget tree, live WebSocket and all, against the booted harness backend.
///
/// One player's phone is the visible screen; the rest of the table is driven
/// through the API. The visible player's own steps are done by TAPPING real
/// widgets (choose, pick a target, Confirm / Skip), so what is exercised is the
/// whole client path of the two-window night: the prompt, the submit, waiting
/// with NO result while others still choose, all results arriving together as
/// the window closes, the Doppelganger's look followed by her follow-up prompt in
/// the same window, and the move on to discussion, voting and results.
///
/// Per-player PNG filmstrips are written to
/// `integration_test/screenshots/<game>/NN-<state>.png`.
///
/// ## Surface
///
/// Plain `flutter test` on the host Dart VM under the NORMAL `testWidgets`
/// binding (not `IntegrationTestWidgetsFlutterBinding`, which is device-bound).
/// Network work runs inside `tester.runAsync` (the fake zone's I/O never
/// completes); `RepaintBoundary.toImage()` inside `runAsync` writes a real PNG.
///
/// ## What is asserted
///
/// - the screen the server's state calls for is shown (a prompt with its Skip
///   where the server offered `skip`; waiting after submitting);
/// - nothing is revealed before the window closes;
/// - what is revealed is what the server recorded for that player (the oracle's
///   night log, via the reference game's `views`);
/// - the hidden-info guard: a player's post-swap `current_role` (when it differs
///   from their dealt role) is oracle-only and never appears on their screen
///   before results.
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await HarnessConfig.setUp();
    // The app persists the JWT + user in flutter_secure_storage and the
    // interceptor reads it per request; back it with an in-memory map since the
    // host VM has no secure-storage plugin.
    HarnessConfig.stubSecureStorage();
    // Real glyphs for legible filmstrips.
    await HarnessConfig.loadFonts();
  });

  final scripts = <String, _UiScript>{
    '1': _game1Seer,
    '4': _game4DoppelgangerRobber,
    '5': _game5HunterThroughTheNight,
    '8': _game8Insomniac,
    '21': _game21SeerDoesNothing,
  };

  for (final game in allScenarios.where((g) => g.isUiCritical)) {
    final script = scripts[game.id];
    if (script == null) {
      throw StateError('uiCritical game ${game.id} has no UI script');
    }
    testWidgets('UI: ${game.name}', (tester) async {
      final runner = ReferenceGameRunner(game);
      final ui = UiHarness(tester);
      var frame = 0;
      try {
        // Provision the table through the API path (inside runAsync: real
        // network only progresses in the real zone).
        await tester.runAsync(() => runner.setUp());
        await ui.pumpApp();
        await script(
          _UiRun(
            tester: tester,
            ui: ui,
            runner: runner,
            game: game,
            shoot: (name) => ui.captureFrame(
              game.name,
              '${(++frame).toString().padLeft(2, '0')}-$name',
            ),
          ),
        );
        // The recorded outcome must hold too (the UI drove none of the rules).
        await tester.runAsync(() async {
          if (game.hasVotes) await runner.assertResults();
        });
      } catch (e) {
        FailureReport.record(
          scenario: game.name,
          checkpoint: 'ui-runner',
          message: e.toString(),
          pngPath: 'integration_test/screenshots/${game.name}/',
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

typedef _UiScript = Future<void> Function(_UiRun run);

/// Everything a UI script needs, with the common steps as methods.
class _UiRun {
  _UiRun({
    required this.tester,
    required this.ui,
    required this.runner,
    required this.game,
    required this.shoot,
  });

  final WidgetTester tester;
  final UiHarness ui;
  final ReferenceGameRunner runner;
  final ReferenceGame game;

  /// Captures the next numbered filmstrip frame.
  final Future<void> Function(String name) shoot;

  Finder text(String t) => find.text(t);
  bool shows(String t) => find.text(t).evaluate().isNotEmpty;
  bool showsType(Type t) => find.byType(t).evaluate().isNotEmpty;

  /// Switches the visible screen to player [index] and opens the game.
  Future<void> openAs(int index) async {
    final player = runner.playerAt(index);
    await ui.switchTo(
      userId: player.userId,
      displayName: player.displayName,
      accessToken: player.accessToken,
      refreshToken: player.refreshToken,
      gameId: runner.table.gameId,
    );
    await ui.openGame(runner.table.gameId);
    await ui.pumpUntil(
      () => ui.gameScreenRendered,
      reason: '${game.name}: game screen for ${player.displayName}',
    );
  }

  /// The hidden-info guard: the post-swap card must not be on this player's
  /// pre-results screen.
  Future<void> guardHiddenCard(int index) async {
    final player = runner.playerAt(index);
    final oracle = await tester.runAsync(() => runner.oracle());
    final truth = oracle!.playerById(player.userId);
    if (truth.currentRole != truth.originalRole) {
      expect(
        find.text(truth.currentRole),
        findsNothing,
        reason:
            '${game.name}: post-swap current_role "${truth.currentRole}" leaked '
            'onto ${player.displayName}\'s pre-results screen',
      );
    }
  }

  /// A plain tap (a selection: no network).
  Future<void> tap(String label) async {
    await tester.tap(find.text(label));
    await tester.pump();
    await ui.settle();
  }

  bool get waitingShown => shows('The village sleeps…');

  /// Plays the rest of the night for the other players via the API.
  Future<void> restOfNight() =>
      tester.runAsync(() => runner.runNight()).then((_) {});

  /// After the night ends the player still holds an undismissed result: it is
  /// shown first, then Continue goes on to the discussion.
  Future<void> continueToDiscussion() async {
    await ui.pumpUntil(
      () => shows('Continue to discussion'),
      reason: '${game.name}: night result held before the discussion',
    );
    await tap('Continue to discussion');
    await ui.pumpUntil(
      () => shows('Roles in this game'),
      reason: '${game.name}: discussion',
    );
  }

  /// Discussion -> votes -> results, driven through the API; the screen follows
  /// over the socket.
  Future<void> dayToResults() async {
    await tester.runAsync(() => runner.runDay());
    await ui.pumpUntil(
      () =>
          find.byKey(const ValueKey('results')).evaluate().isNotEmpty ||
          find.byKey(const ValueKey('results-loading')).evaluate().isNotEmpty,
      reason: '${game.name}: results screen',
    );
    await ui.pumpUntil(
      () => find.byKey(const ValueKey('results')).evaluate().isNotEmpty,
      reason: '${game.name}: results loaded',
    );
    await shoot('results');
  }

  /// The role names a recorded `saw_player` / `took` / `own_card` view carries.
  String viewRole(int player, String kind) {
    final v = game.views[player]!.firstWhere((e) => e.kind == kind).value;
    return v is List ? v.last as String : v as String;
  }
}

// -----------------------------------------------------------------------------
// Game 1: the Seer looks, submits, WAITS, and gets the result with everyone's.
// -----------------------------------------------------------------------------
Future<void> _game1Seer(_UiRun r) async {
  const bob = 1; // Seer; looks at Alice (0), who is a Werewolf.
  await r.openAs(bob);
  await r.guardHiddenCard(bob);

  // The Seer chooses between a player and the center, and may do nothing.
  expect(r.shows("Look at a player's card"), isTrue);
  expect(r.shows('Look at two center cards'), isTrue);
  expect(r.shows('Skip'), isTrue, reason: 'the server offered skip');
  await r.shoot('bob-seer-choice');

  await r.tap("Look at a player's card");
  await r.tap('Alice');
  await r.shoot('bob-picked-alice');
  await r.ui.tapAndSubmit(r.text('Confirm'), until: () => r.waitingShown);

  // Submitted: he waits. Nothing is shown while others are still choosing.
  expect(r.shows('Confirm'), isFalse, reason: 'the prompt is gone');
  expect(r.showsType(NightResultView), isFalse);
  await r.shoot('bob-submitted-waiting');

  // The rest of the table answers; the window closes; his result arrives.
  await r.restOfNight();
  await r.ui.pumpUntil(
    () => r.showsType(NightResultView),
    reason: 'the Seer result after the window closed',
  );
  expect(r.shows(r.viewRole(bob, 'saw_player')), isTrue);
  expect(find.textContaining('Alice'), findsWidgets);
  await r.shoot('bob-seer-result');

  await r.continueToDiscussion();
  await r.shoot('bob-discussion');
  await r.dayToResults();
}

// -----------------------------------------------------------------------------
// Game 4: the Doppelganger copies the Robber: her look result arrives at once,
// followed by her follow-up prompt in the SAME window.
// -----------------------------------------------------------------------------
Future<void> _game4DoppelgangerRobber(_UiRun r) async {
  const alice = 0; // Doppelganger: looks at Bob (the Robber), then robs Carol.
  await r.openAs(alice);
  await r.guardHiddenCard(alice);
  expect(r.showsType(NightResultView), isFalse);
  await r.shoot('alice-doppelganger-look');

  await r.tap('Bob');
  await r.ui.tapAndSubmit(
    r.text('Confirm'),
    until: () => r.showsType(NightResultView),
  );

  // Her look result is on screen (not replaced by the follow-up prompt) and she
  // goes on when ready.
  expect(r.shows(r.viewRole(alice, 'copied')), isTrue);
  expect(r.shows('Continue'), isTrue);
  await r.shoot('alice-look-result');

  await r.tap('Continue');
  expect(r.shows('Skip'), isTrue, reason: 'her follow-up offers skip');
  await r.shoot('alice-follow-up-robber');
  await r.tap('Carol');
  await r.ui.tapAndSubmit(
    r.text('Confirm'),
    until: () => r.showsType(NightResultView),
  );

  // Window 1 closed on her follow-up: she is told who she robbed, and window 2
  // (everyone else) opens without wiping it.
  expect(r.shows(r.viewRole(alice, 'took')), isTrue);
  await r.shoot('alice-follow-up-result');

  await r.restOfNight();
  await r.continueToDiscussion();
  await r.dayToResults();
}

// -----------------------------------------------------------------------------
// Game 5: a player with no night action waits through the whole night, then
// the Hunter-chain / Tanner-block results.
// -----------------------------------------------------------------------------
Future<void> _game5HunterThroughTheNight(_UiRun r) async {
  const bob = 1; // Hunter: nothing to do at night.
  await r.openAs(bob);
  await r.guardHiddenCard(bob);
  expect(r.waitingShown, isTrue);
  await r.shoot('bob-hunter-night-waiting');

  await r.restOfNight();
  // Nothing was revealed to him: straight to the discussion.
  await r.ui.pumpUntil(
    () => r.shows('Roles in this game'),
    reason: 'the discussion for a player with no night result',
  );
  expect(r.showsType(NightResultView), isFalse);
  await r.shoot('bob-discussion');
  await r.dayToResults();
}

// -----------------------------------------------------------------------------
// Game 8: the Insomniac's result is delivered in window 2 with everyone's, and
// is the card the Drunk and others left them.
// -----------------------------------------------------------------------------
Future<void> _game8Insomniac(_UiRun r) async {
  const eve = 4; // Insomniac
  await r.openAs(eve);
  await r.guardHiddenCard(eve);
  expect(r.showsType(NightResultView), isFalse);
  await r.shoot('eve-insomniac-prompt');

  await r.ui.tapAndSubmit(
    r.text('Look at my card'),
    until: () => r.waitingShown,
  );
  // She asked, but is told nothing until the window closes.
  expect(r.shows('Your card is now:'), isFalse);
  await r.shoot('eve-waiting');

  await r.restOfNight();
  await r.ui.pumpUntil(
    () => r.shows('Your card is now:'),
    reason: 'the Insomniac result after the window closed',
  );
  expect(r.shows(r.viewRole(eve, 'own_card')), isTrue);
  await r.shoot('eve-insomniac-result');

  await r.continueToDiscussion();
  await r.dayToResults();
}

// -----------------------------------------------------------------------------
// Game 21: nobody acts. The Seer taps Skip (the explicit "do nothing"), the
// Drunk never answers, the window closes by its timer.
// -----------------------------------------------------------------------------
Future<void> _game21SeerDoesNothing(_UiRun r) async {
  const bob = 1; // Seer
  await r.openAs(bob);
  await r.guardHiddenCard(bob);
  expect(r.shows('Skip'), isTrue);
  await r.shoot('bob-seer-choice');

  await r.ui.tapAndSubmit(r.text('Skip'), until: () => r.waitingShown);
  expect(r.showsType(NightResultView), isFalse);
  await r.shoot('bob-skipped-waiting');

  await r.restOfNight();
  expect(
    r.runner.windowsClosedByTimer,
    contains(2),
    reason: 'the Drunk never answered, so the window closed by its timer',
  );
  await r.ui.pumpUntil(
    () => r.shows('You did nothing.'),
    reason: 'the do-nothing result after the window closed',
  );
  await r.shoot('bob-did-nothing');

  await r.continueToDiscussion();
  await r.dayToResults();
}
