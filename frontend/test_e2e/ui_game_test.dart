@Tags(['e2e'])
library;

import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/core/debug/debug_models.dart';
import 'package:midnight_village/design_system/copy/copy.dart';
import 'package:midnight_village/design_system/faces/held_face.dart';
import 'package:midnight_village/design_system/night/night_board.dart';
import 'package:midnight_village/design_system/primitives/face_down_card.dart';
import 'package:midnight_village/design_system/primitives/panels.dart';
import 'package:midnight_village/design_system/primitives/primary_button.dart';
import 'package:midnight_village/features/game/presentation/shell/talk_screen.dart';
import 'package:midnight_village/features/game/presentation/shell/your_card_screen.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../test/helpers/test_fonts.dart';
import 'harness/harness_config.dart';
import 'harness/time_budget.dart';
import 'harness/phone.dart';

/// UI runner: one phone plays a game through the REAL
/// widget tree of the table's shell (`TableShell`, from the game's link), live
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
    await HarnessConfig.loadFonts();
    // What this device has learned (the teach-once cues): a new device.
    // Test code; the analyzer only counts test/ and *_test.dart as tests.
    // ignore: invalid_use_of_visible_for_testing_member
    SharedPreferences.setMockInitialValues({});
    await loadAppFonts();
  });

  testWidgets('UI: the look, the board, Choose, then the talk', (tester) async {
    await runPhone(tester, 'p2-seer-look-to-talk', (r) async {
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
      expect(r.button.label, r.board.prompt.kind.go.fill({'cards': 'Cara'}));
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

      // My night: open as the talk opens (her night told her something),
      // put away with a tap; then held, the same words.
      expect(find.byType(HeldFace), findsOneWidget);
      await r.putAwayMyNight(() async {
        expect(r.text("Cara's card was: Werewolf."), isTrue);
        await r.shoot('talk-open');
      });
      await r.holdThen(find.byType(PeekBox), () async {
        expect(r.text("Cara's card was: Werewolf."), isTrue);
        await r.shoot('talk-my-night');
      });
      await r.talkAndVote(t, accuse: 'Cara');
    });
  });

  testWidgets('UI: the Doppelganger copies, takes her follow-up '
      'on the same board, then window 2', (tester) async {
    await runPhone(tester, 'p2-doppelganger-two-windows', (r) async {
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
      expect(
        r.button.label,
        r.board.prompt.kind.go.fill({'cards': 'Left, Right'}),
      );
      await r.tapButton(until: () => r.button.phase == ButtonPhase.done);
      await r.shoot('follow-up-chosen');

      // Nobody else has anything to choose in window 1 (they send nothing);
      // the window ends with her follow-up, or on its timer where it has a
      // fixed length.
      await r.api(() async {
        await r.everyoneElse((p) => r.choose(p, []));
        if ((await t.controller.oracle()).currentWave == 1) {
          expect(await t.controller.fireTimer(TimerKey.wave(1)), isTrue);
        }
      });
      // Window 2: as the copied Seer she has already acted; her board sleeps,
      // asks nothing and sends nothing.
      await r.ui.pumpUntil(
        () => r.shows<NightBoard>() && r.board.prompt.window == 2,
        reason: 'window 2, a sleeping board',
      );
      expect(r.board.prompt.sleeps, isTrue);
      expect(r.button.label, NightCopy.nothingToDo);
      await r.shoot('window-2-sleeping');

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
