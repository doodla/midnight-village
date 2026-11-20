@Tags(['e2e'])
library;

import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/core/debug/debug_models.dart';
import 'package:midnight_village/design_system/copy/copy.dart';
import 'package:midnight_village/design_system/night/night_board.dart';
import 'package:midnight_village/design_system/primitives/face_down_card.dart';
import 'package:midnight_village/design_system/primitives/hold_to_reveal.dart';
import 'package:midnight_village/design_system/primitives/panels.dart';
import 'package:midnight_village/design_system/primitives/primary_button.dart';
import 'package:midnight_village/features/game/domain/screen_table.dart';
import 'package:midnight_village/features/game/presentation/shell/not_built_screen.dart';
import 'package:midnight_village/features/game/presentation/shell/talk_screen.dart';
import 'package:midnight_village/features/game/presentation/shell/vote_screen.dart';
import 'package:midnight_village/features/game/presentation/shell/your_card_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test/helpers/test_fonts.dart';
import 'harness/end_of_game.dart';
import 'harness/failure_report.dart';
import 'harness/harness_config.dart';
import 'harness/live_table.dart';
import 'harness/time_budget.dart';
import 'harness/ui_harness.dart';

/// UI runner, night protocol 2: one phone plays a game through the REAL
/// widget tree of the rebuilt shell (`GameEntry` -> `TableShell`), live
/// socket and all, against the harness backend, from the look stage (04)
/// through the night windows, the talk (08) and the vote (09) to the count
/// (10) and the results (11), checked as the server's oracle says the game
/// went (`harness/end_of_game.dart`); the rest of the table plays through
/// the API. The phone's own steps are made
/// the way a player makes them: a hold, taps, Choose, Ready.
///
/// Per-phone PNG filmstrips at 390 x 844 are written to
/// `integration_test/screenshots/<game>/NN-<state>.png`.
///
/// Asserted: the screen the server's state calls for is shown, and what the
/// phone sent is what the server recorded (`/me/` and the oracle: its ready,
/// its pick, its lock).
void main() {
  TestWidgetsFlutterBinding.ensureInitialized();

  setUpAll(() async {
    await HarnessConfig.setUp();
    HarnessConfig.stubSecureStorage();
    // The old theme's fonts, fetched once up front with the path_provider
    // stub (as the protocol-1 UI runner does), so none is fetched mid-game.
    await HarnessConfig.loadFonts();
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
      await r.ui.pumpUntil(r.shows<TalkScreen>, reason: 'the talk');
      await r.shoot('talk');

      final looked = (await r.api(() => t.me(alice)))['night_results'] as List;
      expect(looked.single['action_type'], 'peek_player');
      expect(looked.single['revealed_info']['target_name'], 'Cara');

      // My night: what she saw, held.
      await r.holdThen(find.byType(PeekBox), () async {
        expect(r.text("Cara's card: Werewolf."), isTrue);
        await r.shoot('talk-my-night');
      });
      await r.talkAndVote(t, accuse: 'Cara');
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
      await r.ui.pumpUntil(r.shows<TalkScreen>, reason: 'the talk');
      await r.shoot('talk');

      final results = (await r.api(() => t.me(alice)))['night_results'] as List;
      expect(results.first['revealed_info']['target_name'], 'Bob');
      expect(
        (results.last['revealed_info']['roles'] as List).toSet(),
        {'Werewolf', 'Tanner'},
        reason: 'her copied Seer looked at Left and Right',
      );
      await r.talkAndVote(t, accuse: 'Bob');
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

  /// What is true on the server (the debug-state oracle). Called inside
  /// [api] (the real zone) only.
  Future<Map<String, dynamic>> _oracle() => table.oracleJson();

  Future<bool> _aliceReady() async {
    final players = ((await _oracle())['players'] as List)
        .cast<Map<String, dynamic>>();
    return players.firstWhere(
          (p) => p['user_id'] == table.player('Alice').userId,
        )['ready']
        as bool;
  }

  /// From the talk to the count, Alice on the phone: "Ready to vote" on,
  /// off and on again (each reaching the server, read from the oracle);
  /// the rest ready through the API; the vote opens; she picks [accuse],
  /// then locks in; the rest lock in a vote for her; the count follows.
  Future<void> talkAndVote(LiveTable t, {required String accuse}) async {
    final alice = t.player('Alice');
    expect(button.label, TalkCopy.readyToVote);
    expect(button.phase, ButtonPhase.quiet);
    for (final ready in [true, false, true]) {
      await tapButton(
        until: () =>
            button.label ==
            (ready ? CommonCopy.readyDone : TalkCopy.readyToVote),
      );
      await api(
        () => pollUntil(
          () async => await _aliceReady() == ready,
          reason: 'Ready to vote $ready on the server',
          timeout: eventTimeout,
        ),
      );
    }
    await shoot('talk-ready');

    await api(() => everyoneElse((p) => staged(p, 'ready', {'ready': true})));
    await ui.pumpUntil(shows<VoteScreen>, reason: 'the vote');
    await ui.settle();
    expect(button.label, VoteCopy.pickName);
    expect(find.text(alice.displayName), findsNothing, reason: 'not herself');
    await shoot('vote');

    final target = t.player(accuse);
    await ui.tapAndSubmit(
      find.text(accuse),
      until: () => button.label == 'Lock in $accuse',
    );
    await api(
      () => pollUntil(
        () async =>
            (await _oracle())['votes']['${alice.userId}'] == target.userId,
        reason: "Alice's pick on the server",
        timeout: eventTimeout,
      ),
    );
    expect((await api(_oracle))['vote_locked']['${alice.userId}'], isFalse);
    await shoot('vote-picked');

    await tapButton(until: () => button.label == VoteCopy.locked);
    await api(
      () => pollUntil(
        () async => (await _oracle())['vote_locked']['${alice.userId}'] == true,
        reason: "Alice's lock on the server",
        timeout: eventTimeout,
      ),
    );
    expect((await api(() => t.me(alice)))['my_vote'], {
      'target_player_id': target.userId,
      'locked': true,
    });
    await shoot('vote-locked');

    await api(
      () => everyoneElse(
        (p) => staged(p, 'vote', {
          'target_player_id': p.userId == alice.userId
              ? target.userId
              : alice.userId,
          'lock': true,
        }),
      ),
    );
    // The count and the results, as the server says they went.
    await endAsTheOracleSays(
      tester: tester,
      ui: ui,
      table: t,
      name: 'Alice',
      shoot: shoot,
    );
  }

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
