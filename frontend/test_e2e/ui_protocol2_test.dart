@Tags(['e2e'])
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/core/debug/debug_models.dart';
import 'package:midnight_village/design_system/copy/copy.dart';
import 'package:midnight_village/design_system/night/night_board.dart';
import 'package:midnight_village/design_system/primitives/face_down_card.dart';
import 'package:midnight_village/design_system/primitives/hold_to_reveal.dart';
import 'package:midnight_village/design_system/primitives/primary_button.dart';
import 'package:midnight_village/features/game/domain/screen_table.dart';
import 'package:midnight_village/features/game/presentation/shell/not_built_screen.dart';
import 'package:midnight_village/features/game/presentation/shell/your_card_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test/helpers/test_fonts.dart';
import 'harness/failure_report.dart';
import 'harness/harness_config.dart';
import 'harness/live_table.dart';
import 'harness/time_budget.dart';
import 'harness/ui_harness.dart';

/// UI runner, night protocol 2: one phone plays a game through the REAL
/// widget tree of the rebuilt shell (`GameEntry` -> `TableShell`), live
/// socket and all, against the harness backend, from the look stage (04)
/// through the night windows to the talk (08, a placeholder for now); the
/// rest of the table plays through the API. The phone's own steps are made
/// the way a player makes them: a hold, taps, Choose, Ready.
///
/// Per-phone PNG filmstrips at 390 x 844 are written to
/// `integration_test/screenshots/<game>/NN-<state>.png`.
///
/// Asserted: the screen the server's state calls for is shown, and what the
/// phone sent is what the server recorded (`/me/` and the oracle).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await HarnessConfig.setUp();
    HarnessConfig.stubSecureStorage();
    // What this device has learned (the teach-once cues): a new device.
    // Test code; the analyzer only counts test/ and *_test.dart as tests.
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
    await loadAppFonts();
  });

  testWidgets('UI, protocol 2: the look, the board, Choose, then the talk', (
    tester,
  ) async {
    await _run(tester, 'p2-seer-look-to-talk', (r) async {
      final t = await r.open(
        roleCounts: {
          'Werewolf': 2,
          'Seer': 1,
          'Robber': 1,
          'Troublemaker': 1,
          'Villager': 3,
        },
        roles: {
          'Alice': 'Seer',
          'Bob': 'Robber',
          'Cara': 'Werewolf',
          'Dan': 'Troublemaker',
          'Eve': 'Villager',
        },
        center: ['Werewolf', 'Villager', 'Villager'],
      );
      final alice = t.player('Alice');

      // 04: the card face down, "Ready" locked until it is held.
      await r.ui.pumpUntil(r.shows<YourCardScreen>, reason: '04 Your card');
      expect(r.button.phase, ButtonPhase.locked);
      expect(r.text(CommonCopy.hold), isTrue, reason: 'a new device');
      await r.shoot('your-card');
      await r.holdThen(find.byType(FaceDownCard), () async {
        expect(r.text('Seer'), isTrue, reason: 'the held face');
        await r.shoot('your-card-held');
      });
      expect(r.button.phase, ButtonPhase.ready);
      await r.tapButton(until: () => r.button.phase == ButtonPhase.done);
      // Shown on the tap; the server has it once the request lands.
      await r.api(
        () => pollUntil(
          () async => (await t.me(alice))['ready'] == true,
          reason: "Alice's Ready to reach the server",
          timeout: eventTimeout,
        ),
      );
      await r.shoot('ready');

      // Everyone else looks: the night opens on every phone at once.
      await r.api(
        () => r.everyoneElse((p) => r.staged(p, 'ready', {'ready': true})),
      );
      await r.ui.pumpUntil(r.shows<NightBoard>, reason: 'the night board');
      await r.shoot('board');

      await r.tapCard('Cara');
      expect(r.button.label, 'Choose Cara');
      await r.shoot('picked');
      await r.tapButton(until: () => r.button.phase == ButtonPhase.done);
      expect(r.button.label, NightCopy.chosen);
      await r.shoot('chosen');

      // The rest of the table chooses; the window closes; the talk.
      await r.api(() => r.everyoneElse((p) => r.choose(p, [])));
      await r.ui.pumpUntil(
        () => r.placeholder == AppScreen.talk,
        reason: 'the talk after the night',
      );
      await r.shoot('talk');

      final looked = (await r.api(() => t.me(alice)))['night_results'] as List;
      expect(looked.single['action_type'], 'peek_player');
      expect(looked.single['revealed_info']['target_name'], 'Cara');
    });
  });

  testWidgets('UI, protocol 2: the Doppelganger copies, takes her follow-up '
      'on the same board, then window 2', (tester) async {
    await _run(tester, 'p2-doppelganger-two-windows', (r) async {
      final t = await r.open(
        roleCounts: {
          'Doppelganger': 1,
          'Seer': 1,
          'Werewolf': 2,
          'Villager': 2,
          'Drunk': 1,
          'Tanner': 1,
        },
        roles: {
          'Alice': 'Doppelganger',
          'Bob': 'Seer',
          'Cara': 'Werewolf',
          'Dan': 'Villager',
          'Eve': 'Drunk',
        },
        center: ['Werewolf', 'Villager', 'Tanner'],
      );
      final alice = t.player('Alice');

      await r.ui.pumpUntil(r.shows<YourCardScreen>, reason: '04 Your card');
      await r.holdThen(find.byType(FaceDownCard), () async {});
      await r.tapButton(until: () => r.button.phase == ButtonPhase.done);
      await r.api(
        () => r.everyoneElse((p) => r.staged(p, 'ready', {'ready': true})),
      );

      // Window 1: her look.
      await r.ui.pumpUntil(
        () => r.shows<NightBoard>() && r.board.prompt.window == 1,
        reason: 'window 1',
      );
      await r.shoot('window-1');
      await r.holdThen(r.you, () async {
        expect(r.text(NightCopy.doppelgangerLook), isTrue);
        await r.shoot('window-1-you-held');
      });

      await r.tapCard('Bob');
      await r.shoot('look-picked');
      // Her look is read at once: /me/ brings her follow-up turn and the
      // board arms again on its own.
      await r.tapButton(
        until: () =>
            r.board.prompt.turn == 1 && r.button.phase != ButtonPhase.done,
      );
      expect(r.button.label, NightCopy.chooseNone);
      await r.shoot('follow-up');
      await r.holdThen(r.you, () async {
        expect(r.text('You copied Bob.'), isTrue);
        await r.shoot('follow-up-you-held');
      });

      await r.tapCard(NightCopy.left);
      await r.tapCard(NightCopy.right);
      expect(r.button.label, 'Choose Left, Right');
      await r.tapButton(until: () => r.button.phase == ButtonPhase.done);
      await r.shoot('follow-up-chosen');

      // Everyone else's one choose of window 1; then the window's end.
      await r.api(() async {
        await r.everyoneElse((p) => r.choose(p, []));
        expect(await t.controller.fireTimer(TimerKey.wave(1)), isTrue);
      });
      await r.ui.pumpUntil(
        () =>
            r.shows<NightBoard>() &&
            r.board.prompt.window == 2 &&
            r.button.phase != ButtonPhase.done,
        reason: 'window 2, a fresh board',
      );
      await r.shoot('window-2');

      await r.tapCard(NightCopy.you);
      expect(r.button.label, NightCopy.keep);
      await r.tapButton(until: () => r.button.phase == ButtonPhase.done);
      await r.shoot('kept');

      await r.api(() => r.everyoneElse((p) => r.choose(p, [])));
      await r.ui.pumpUntil(
        () => r.placeholder == AppScreen.talk,
        reason: 'the talk after window 2',
      );
      await r.shoot('talk');

      final results = (await r.api(() => t.me(alice)))['night_results'] as List;
      expect(results.first['revealed_info']['target_name'], 'Bob');
      expect(
        (results.last['revealed_info']['roles'] as List).toSet(),
        {'Werewolf', 'Tanner'},
        reason: 'her copied Seer looked at Left and Right',
      );
    });
  });
}

/// Runs [script] on a fresh app at a phone's size, recording a failure with
/// its filmstrip folder, and tears the app down whatever happens.
Future<void> _run(
  WidgetTester tester,
  String name,
  Future<void> Function(_Phone r) script,
) async {
  tester.view.physicalSize = const Size(780, 1688);
  tester.view.devicePixelRatio = 2;
  addTearDown(tester.view.reset);
  final ui = UiHarness(tester);
  final phone = _Phone(tester, ui, name);
  try {
    await ui.pumpApp();
    await script(phone);
  } catch (e) {
    FailureReport.record(
      scenario: name,
      checkpoint: 'ui-protocol2',
      message: e.toString(),
      pngPath: 'integration_test/screenshots/$name/',
    );
    rethrow;
  } finally {
    await phone.close();
    await ui.tearDownHarness();
  }
}

/// Alice's phone at a table of five, and the API hand for the others.
class _Phone {
  _Phone(this.tester, this.ui, this.name);

  final WidgetTester tester;
  final UiHarness ui;
  final String name;
  late LiveTable table;
  var _frame = 0;

  /// Opens the table (made as the `/debug` toolbar makes a v2 table), forced
  /// to [roles] and [center], and Alice's phone on its game.
  Future<LiveTable> open({
    required Map<String, int> roleCounts,
    required Map<String, String> roles,
    required List<String> center,
  }) async {
    table = (await tester.runAsync(
      () => LiveTable.open(
        protocolTwo: true,
        playerNames: roles.keys.toList(),
        roleCounts: roleCounts,
        playerRolesByName: roles,
        centerCards: center,
        // Long backstops: every stage here ends because everyone acted, or
        // by the fire-timer hook, never by a clock.
        timerSettings: {
          'card_look_seconds': 120,
          'night_wave_seconds': 600,
          'night_min_window_seconds': 0,
          'night_doppelganger_window_seconds': 600,
          'discussion_seconds': 600,
          'voting_seconds': 600,
        },
      ),
    ))!;
    final alice = table.player('Alice');
    await ui.switchTo(
      userId: alice.userId,
      displayName: alice.displayName,
      accessToken: alice.accessToken,
      refreshToken: alice.refreshToken,
      gameId: table.gameId,
    );
    await ui.openShell(table.gameId);
    return table;
  }

  Future<void> close() async {
    try {
      await tester.runAsync(table.closeAll);
    } catch (_) {
      // Not opened.
    }
  }

  /// Real network, in the real zone.
  Future<T> api<T>(Future<T> Function() call) async =>
      (await tester.runAsync(() => call().timeout(eventTimeout))) as T;

  /// Every player but Alice, one after the other.
  Future<void> everyoneElse(Future<void> Function(DebugPlayer p) act) async {
    for (final p in table.table.players.where(
      (p) => p.displayName != 'Alice',
    )) {
      await act(p);
    }
  }

  /// A stage-scoped request as [p], naming the stage `/me/` has now (a
  /// choose answers the prompt as `/me/` shows it).
  Future<void> staged(
    DebugPlayer p,
    String tail,
    Map<String, dynamic> data,
  ) async {
    final me = await table.me(p);
    final prompt = me['action_prompt'] as Map<String, dynamic>?;
    await table.client.post(
      '/onuw/games/${table.gameId}/$tail/',
      token: p.accessToken,
      data: {
        ...data,
        'stage': me['stage'] as String,
        if (data['action_type'] == 'choose')
          'chosen': prompt == null ? 0 : prompt['chosen'] as int,
      },
    );
  }

  Future<void> choose(DebugPlayer p, List<Map<String, Object>> picks) =>
      staged(p, 'action', {'action_type': 'choose', 'picks': picks});

  // ---------------------------------------------------------------------------
  // The screen
  // ---------------------------------------------------------------------------

  bool shows<T extends Widget>() => find.byType(T).evaluate().isNotEmpty;
  bool text(String t) => find.text(t).evaluate().isNotEmpty;

  NightBoard get board => tester.widget<NightBoard>(find.byType(NightBoard));
  PrimaryButton get button =>
      tester.widget<PrimaryButton>(find.byType(PrimaryButton).last);

  /// The placeholder shown, if any.
  AppScreen? get placeholder => shows<NotBuiltScreen>()
      ? tester.widget<NotBuiltScreen>(find.byType(NotBuiltScreen)).screen
      : null;

  /// "You" on the board.
  Finder get you => find.ancestor(
    of: find.text(NightCopy.you),
    matching: find.byType(FaceDownCard),
  );

  /// A card on the board by its caption (a pick: no network).
  Future<void> tapCard(String caption) async {
    await tester.tap(find.text(caption).last);
    await tester.pump();
    await ui.settle();
  }

  /// Holds [target] for a reveal that counts, runs [whileHeld], lets go.
  Future<void> holdThen(
    Finder target,
    Future<void> Function() whileHeld,
  ) async {
    final gesture = await tester.startGesture(tester.getCenter(target.first));
    await tester.pump(HoldToReveal.holdDelay);
    await tester.pump(HoldToReveal.revealedAfter);
    await whileHeld();
    await gesture.up();
    await tester.pump();
  }

  /// The screen's primary button (it sends a request: a real-zone tap).
  Future<void> tapButton({required bool Function() until}) =>
      ui.tapAndSubmit(find.byType(PrimaryButton).last, until: until);

  /// The next filmstrip frame.
  Future<void> shoot(String state) =>
      ui.captureFrame(name, '${(++_frame).toString().padLeft(2, '0')}-$state');
}
