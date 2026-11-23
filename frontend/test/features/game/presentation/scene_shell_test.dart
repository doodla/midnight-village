import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/copy/copy.dart';
import 'package:midnight_village/design_system/layout/space.dart';
import 'package:midnight_village/design_system/night/night_board.dart';
import 'package:midnight_village/design_system/primitives/band.dart';
import 'package:midnight_village/design_system/primitives/face_down_card.dart';
import 'package:midnight_village/design_system/primitives/layered_art.dart';
import 'package:midnight_village/design_system/primitives/primary_button.dart';
import 'package:midnight_village/design_system/skin/art_set.dart';
import 'package:midnight_village/design_system/skin/skin_id.dart';
import 'package:midnight_village/design_system/teach/learned_store.dart';
import 'package:midnight_village/features/game/presentation/shell/count_screen.dart';
import 'package:midnight_village/features/game/presentation/shell/talk_screen.dart';
import 'package:midnight_village/features/game/presentation/shell/vote_screen.dart';
import 'package:midnight_village/features/game/presentation/shell/your_card_screen.dart';
import 'package:midnight_village/features/lobby/presentation/at_table_screen.dart';

import '../../../helpers/contract/server_json.dart' show serverMyTable;
import '../../../helpers/frame_pixels.dart';
import '../../../helpers/outcome_samples.dart';
import '../../../helpers/shell_setup.dart';

/// The dusk and the dawn through the real shell: the two changes of screen
/// that are a scene ([Motion.scene]); every other one stays a crossfade
/// ([Motion.settle]), and with reduce motion all are cuts. The moment of the
/// change is the one the shell shows the new screen in (a fetch answered).
const _ms = Duration(milliseconds: 1);

/// Pumps until [screen] is in the tree and the frame that starts its
/// change has been drawn: time zero of the change.
Future<void> _begun(WidgetTester tester, Finder screen) async {
  for (var i = 0; i < 40 && screen.evaluate().isEmpty; i++) {
    await tester.pump(const Duration(milliseconds: 5));
  }
  expect(screen, findsOneWidget);
  await tester.pump();
}

/// The paper edge of the sinking screen, while a scene runs.
Finder get _sceneArt => find.byKey(const ValueKey('scene'));

/// Where [button] of the arriving screen rests: where it is drawn less the
/// slide the arriving screen is still on (a touch lands where it will rest).
Offset _rest(WidgetTester tester, Finder button) {
  final slide = tester.widget<SlideTransition>(
    find.ancestor(of: button, matching: find.byType(SlideTransition)).first,
  );
  final height = tester.view.physicalSize.height / tester.view.devicePixelRatio;
  return tester.getCenter(button) - Offset(0, slide.position.value.dy * height);
}

/// The arriving screen's primary button is on show by [share] of the scene:
/// on the screen, and not under [leaving] (the screen that is sinking off it,
/// the dawn's) if there is one.
Future<void> _buttonShownBy(
  WidgetTester tester, {
  required Finder button,
  Finder? leaving,
  required double share,
}) async {
  await tester.pump(Motion.scene * share);
  final rect = tester.getRect(button);
  final height = tester.view.physicalSize.height / tester.view.devicePixelRatio;
  final reason = 'the button is on show by ${share * 100} % of the scene';
  expect(rect.top, greaterThanOrEqualTo(0), reason: reason);
  expect(rect.bottom, lessThanOrEqualTo(height), reason: reason);
  if (leaving != null) {
    expect(
      rect.bottom,
      lessThanOrEqualTo(tester.getTopLeft(leaving).dy),
      reason: reason,
    );
  }
}

/// Every picture on screen loaded for real (the test clock never waits for
/// image I/O), then drawn again.
Future<void> _loadPictures(WidgetTester tester) async {
  final images = [
    for (final element in find.byType(Image).evaluate())
      ((element.widget as Image).image, element),
  ];
  if (images.isEmpty) return;
  await tester.runAsync(
    () => Future.wait([
      for (final (provider, context) in images)
        precacheImage(provider, context),
    ]),
  );
  await tester.pump();
}

/// A phone's size, in whole pixels (so each frame is read quickly).
void _phone(WidgetTester tester) {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

/// Every frame of the scene running now, each 40 ms: no pixel of the window
/// is left unpainted (no gap opens at an edge of the screen).
Future<void> _noGaps(WidgetTester tester) async {
  await _loadPictures(tester);
  for (var at = 0; at <= Motion.scene.inMilliseconds + 40; at += 40) {
    await _loadPictures(tester);
    final frame = await FramePixels.of(tester);
    expect(frame.unpainted, 0, reason: 'a gap at $at ms');
    await tester.pump(const Duration(milliseconds: 40));
  }
}

Future<ShellSetup> _atNight(WidgetTester tester, {bool still = false}) async {
  final s = await ShellSetup.pump(
    tester,
    recordedMe('me_choose_prompt_seer'),
    learned: const {Cue.hold},
    disableAnimations: still,
    before: (s) => s.answerNightResultsSeen(),
  );
  await s.settle(tester);
  expect(find.byType(NightBoard), findsOneWidget);
  return s;
}

Future<ShellSetup> _atTable(WidgetTester tester, {bool still = false}) async {
  final s = await ShellSetup.pump(
    tester,
    recordedMe('me_look_stage'),
    disableAnimations: still,
  );
  await s.settle(tester);
  final code = s.me['lobby_code'] as String;
  s.answerLobby(code);
  s.answerTable(
    serverMyTable(code: code, isHost: true, gameId: s.gameId, phase: 'results'),
  );
  s.resume();
  await s.settle(tester);
  await s.settle(tester);
  expect(find.byType(AtTableScreen), findsOneWidget);
  return s;
}

/// Whether the layer [file] of [id] has been asked for (decoding or decoded)
/// at the size a 390 x 844 phone draws it: the key the shell's warm-up and the
/// screen's own picture share.
Future<bool> _asked(
  WidgetTester tester,
  LayeredSceneId id,
  String file,
  Size box,
) async {
  final art = SkinId.fallback.skin.art;
  final scene = art.layeredScene(id);
  final layer = scene.files.firstWhere((l) => l.file == file);
  final size = SceneGeometry.cover(scene, box).rect(layer.anchor, layer.size);
  final provider = art.layer(id, layer).decodedFor(size.size, 1);
  final key = await tester.runAsync(
    () => provider.obtainKey(ImageConfiguration.empty),
  );
  return PaintingBinding.instance.imageCache.statusForKey(key!).tracked;
}

void main() {
  group('the headers\' layers are decoded before their scenes', () {
    testWidgets('the shell asks for the village, and the dawn once this phone '
        'is at the night', (tester) async {
      _phone(tester);
      PaintingBinding.instance.imageCache.clear();
      const night = Size(390, 520);
      final sky = Size(390, TimerBand.skyFor(844));
      final s = await ShellSetup.pump(
        tester,
        recordedMe('me_look_stage'),
        learned: const {},
      );
      await s.settle(tester);
      // At the table (02) or the card (04): the village is asked for.
      expect(
        await _asked(tester, LayeredSceneId.nightVillage, 'moon', night),
        isTrue,
      );
      expect(
        await _asked(tester, LayeredSceneId.dawnGallows, 'roofs_near', sky),
        isTrue,
        reason: 'at the night the dawn is asked for',
      );
      await s.close(tester);
    });
  });

  group('the dawn: night to talk', () {
    testWidgets('runs for Motion.scene, not the crossfade, and finishes', (
      tester,
    ) async {
      final s = await _atNight(tester);
      s.answerMe(recordedMe('me_discussion_choose_seer'));
      s.resume();
      await _begun(tester, find.byType(TalkScreen));
      expect(find.byType(NightBoard), findsOneWidget, reason: 'leaving');
      expect(_sceneArt, findsOneWidget, reason: 'the paper edge');
      await tester.pump(Motion.settle + const Duration(milliseconds: 40));
      expect(
        find.byType(NightBoard),
        findsOneWidget,
        reason: 'a crossfade would be over by now',
      );
      await tester.pump(Motion.scene);
      await tester.pump();
      expect(find.byType(NightBoard), findsNothing);
      expect(find.byType(TalkScreen), findsOneWidget);
      expect(tester.hasRunningAnimations, isFalse);
      await s.close(tester);
    });

    testWidgets(
      'a tap in the first frames reaches the talk\'s own button (a night '
      'that told nothing: no sheet comes up over it)',
      (tester) async {
        final s = await _atNight(tester);
        s.answerMe(recordedMe('me_discussion_choose_villager'));
        s.resume();
        await _begun(tester, find.byType(TalkScreen));
        await tester.pump(_ms * 60);
        expect(find.byType(NightBoard), findsOneWidget, reason: 'mid-scene');
        s.answerPost('/ready/', 'game/ready_talk');
        // The night board, still showing, has a button too: the talk's own.
        final ready = find.descendant(
          of: find.byType(TalkScreen),
          matching: find.byType(PrimaryButton),
        );
        await tester.tapAt(_rest(tester, ready));
        await tester.pump();
        expect(
          tester.widget<PrimaryButton>(ready).label,
          CommonCopy.readyDone,
          reason: 'on the tap, mid-scene',
        );
        await tester.pump(_ms * 20);
        expect(s.posts('/ready/'), 1, reason: 'sent mid-scene');
        expect(find.byType(NightBoard), findsOneWidget, reason: 'still going');
        await tester.pump(Motion.scene);
        await s.close(tester);
      },
    );

    testWidgets('the Ready button is uncovered by 60% of the scene', (
      tester,
    ) async {
      final s = await _atNight(tester);
      s.answerMe(recordedMe('me_discussion_choose_seer'));
      s.resume();
      await _begun(tester, find.byType(TalkScreen));
      await _buttonShownBy(
        tester,
        button: find.descendant(
          of: find.byType(TalkScreen),
          matching: find.byType(PrimaryButton),
        ),
        leaving: find.byType(NightBoard),
        share: 0.6,
      );
      await tester.pump(Motion.scene);
      await s.close(tester);
    });

    testWidgets('the table answering before /me/: the day still breaks on '
        'the talk\'s own frame, and the talk arrives into the scene', (
      tester,
    ) async {
      final s = await _atNight(tester);
      final held = s.http.hold(
        method: 'GET',
        path: '/onuw/games/${s.gameId}/me/',
      );
      s.answerMe(recordedMe('me_discussion_choose_seer'));
      s.resume();
      // The talk's own sky and headline, no number yet: the scene's first
      // frame has the header to raise, not an empty ground.
      await _begun(tester, find.byType(TimerBand));
      expect(find.byType(TalkScreen), findsNothing, reason: '/me/ is held');
      expect(find.text(TalkCopy.headline), findsOneWidget);
      expect(find.byType(NightBoard), findsOneWidget, reason: 'leaving');
      expect(_sceneArt, findsOneWidget);
      await tester.pump(_ms * 100);
      held.releaseAll();
      await tester.pump(_ms * 60);
      expect(find.byType(TalkScreen), findsOneWidget, reason: 'arrived');
      expect(_sceneArt, findsOneWidget, reason: 'into the scene that runs');
      expect(find.byType(NightBoard), findsOneWidget);
      await tester.pump(Motion.scene);
      await tester.pump();
      expect(find.byType(NightBoard), findsNothing);
      expect(find.byType(TalkScreen), findsOneWidget);
      await s.close(tester);
    });

    testWidgets('while the talk\'s /me/ loads there is no sun (the table does '
        'not know where the talk is), and the talk then brings the one sun', (
      tester,
    ) async {
      _phone(tester);
      final s = await _atNight(tester);
      final held = s.http.hold(
        method: 'GET',
        path: '/onuw/games/${s.gameId}/me/',
      );
      s.answerMe(recordedMe('me_discussion_choose_seer'));
      s.resume();
      await _begun(tester, find.byType(TimerBand));
      Finder sun() => find.byWidgetPredicate(
        (w) =>
            w is Image &&
            w.image is ResizeImage &&
            ((w.image as ResizeImage).imageProvider as AssetImage).assetName
                .endsWith('/sun.webp'),
      );
      expect(find.byType(TalkScreen), findsNothing, reason: '/me/ is held');
      expect(sun(), findsNothing, reason: 'no sun drawn at the start');
      await tester.pump(_ms * 100);
      expect(sun(), findsNothing);
      held.releaseAll();
      await tester.pump(_ms * 60);
      expect(find.byType(TalkScreen), findsOneWidget);
      expect(sun(), findsOneWidget, reason: 'the one sun, where the clock is');
      await tester.pump(Motion.scene);
      await tester.pump();
      expect(sun(), findsOneWidget);
      await s.close(tester);
    });

    testWidgets('no frame leaves a gap anywhere in the window', (tester) async {
      _phone(tester);
      final s = await _atNight(tester);
      s.answerMe(recordedMe('me_discussion_choose_seer'));
      s.resume();
      await _begun(tester, find.byType(TalkScreen));
      await _noGaps(tester);
      await s.close(tester);
    });

    testWidgets('with reduce motion it is a cut', (tester) async {
      final s = await _atNight(tester, still: true);
      s.answerMe(recordedMe('me_discussion_choose_villager'));
      s.resume();
      await _begun(tester, find.byType(TalkScreen));
      expect(find.byType(NightBoard), findsNothing);
      expect(tester.hasRunningAnimations, isFalse);
      await s.close(tester);
    });
  });

  group('the dusk: the deal to the night', () {
    testWidgets(
      'the moon is lowered into its sky after the sheet has landed: '
      'still moving against the plate when the sheet is within 2 px of rest',
      (tester) async {
        _phone(tester);
        final s = await _atTable(tester);
        s.answerMe(recordedMe('me_look_stage'));
        s.resume();
        await _begun(tester, find.byType(YourCardScreen));
        final art = SkinId.fallback.skin.art;
        final scene = art.layeredScene(LayeredSceneId.nightVillage);
        Finder layer(String file) => find.byWidgetPredicate(
          (w) =>
              w is Image &&
              w.image is ResizeImage &&
              ((w.image as ResizeImage).imageProvider as AssetImage).assetName
                  .endsWith('/$file.webp'),
        );
        final moon = scene.files.firstWhere((l) => l.file == 'moon');
        final plate = scene.files.firstWhere((l) => l.file == 'village_plate');
        final scale =
            tester.getSize(layer('village_plate')).width / plate.size.width;
        // Where the moon lies against the plate, less where it rests.
        double away() =>
            (tester.getTopLeft(layer('moon')) -
                    tester.getTopLeft(layer('village_plate')) -
                    (moon.anchor - plate.anchor) * scale)
                .distance;
        // How far the sheet (the card's screen) is from where it lands, in px.
        double sheet() =>
            tester
                .widget<SlideTransition>(
                  find
                      .ancestor(
                        of: find.byType(YourCardScreen),
                        matching: find.byType(SlideTransition),
                      )
                      .first,
                )
                .position
                .value
                .dy
                .abs() *
            844;
        expect(away(), closeTo(moon.from.distance * scale, 0.5));
        var passed = 0;
        while (sheet() > 2 && passed < 500) {
          await tester.pump(_ms * 5);
          passed += 5;
        }
        expect(passed, lessThan(Motion.scene.inMilliseconds));
        final landed = away();
        expect(
          landed,
          greaterThan(10),
          reason: 'the sheet is down and the moon is still coming',
        );
        await tester.pump(_ms * 50);
        expect(away(), lessThan(landed - 5), reason: 'and it keeps moving');
        // It starts after the sheet is down to the eye, not with it: at the
        // first frames it has not begun (it is where it started).
        await tester.pump(Motion.scene);
        expect(away(), closeTo(0, 0.01), reason: 'then it rests');
        await s.close(tester);
      },
    );

    testWidgets('runs for Motion.scene, the table sinking off the card, '
        'and finishes', (tester) async {
      final s = await _atTable(tester);
      s.answerMe(recordedMe('me_look_stage'));
      s.resume();
      await _begun(tester, find.byType(YourCardScreen));
      expect(find.byType(AtTableScreen), findsOneWidget, reason: 'leaving');
      expect(_sceneArt, findsOneWidget, reason: 'the paper edge');
      await tester.pump(Motion.settle + const Duration(milliseconds: 40));
      expect(find.byType(AtTableScreen), findsOneWidget);
      await tester.pump(Motion.scene);
      await tester.pump();
      expect(find.byType(AtTableScreen), findsNothing);
      expect(_sceneArt, findsNothing);
      await s.close(tester);
    });

    testWidgets('the Ready button is uncovered by 60% of the scene', (
      tester,
    ) async {
      final s = await _atTable(tester);
      s.answerMe(recordedMe('me_look_stage'));
      s.resume();
      await _begun(tester, find.byType(YourCardScreen));
      await _buttonShownBy(
        tester,
        button: find.descendant(
          of: find.byType(YourCardScreen),
          matching: find.byType(PrimaryButton),
        ),
        share: 0.6,
      );
      await tester.pump(Motion.scene);
      await s.close(tester);
    });

    testWidgets('the table answering before /me/: the night still comes down '
        'on the card\'s own frame, and the card arrives into the scene', (
      tester,
    ) async {
      // A phone that has not read this game yet: at its table (02), the
      // game's `/me/` never fetched.
      final s = await ShellSetup.pump(
        tester,
        recordedMe('me_look_stage'),
        holdMe: true,
      );
      await s.settle(tester);
      final code = s.me['lobby_code'] as String;
      s.answerLobby(code);
      s.answerTable(serverMyTable(code: code, isHost: true));
      s.resume();
      await s.settle(tester);
      await s.settle(tester);
      expect(find.byType(AtTableScreen), findsOneWidget);
      final held = s.http.hold(
        method: 'GET',
        path: '/onuw/games/${s.gameId}/me/',
      );
      s.answerMe(recordedMe('me_look_stage'));
      s.resume();
      // The card's own frame, its village and headline, no card yet.
      await _begun(tester, find.text(CardCopy.headline));
      expect(find.byType(YourCardScreen), findsNothing, reason: '/me/ held');
      expect(find.byType(FaceDownCard), findsNothing);
      expect(find.byType(AtTableScreen), findsOneWidget, reason: 'leaving');
      expect(_sceneArt, findsOneWidget);
      await tester.pump(_ms * 100);
      held.releaseAll();
      await tester.pump(_ms * 60);
      expect(find.byType(YourCardScreen), findsOneWidget, reason: 'arrived');
      expect(_sceneArt, findsOneWidget, reason: 'into the scene that runs');
      await tester.pump(Motion.scene);
      await tester.pump();
      expect(find.byType(AtTableScreen), findsNothing);
      expect(_sceneArt, findsNothing);
      await s.close(tester);
    });

    testWidgets('no frame leaves a gap anywhere in the window', (tester) async {
      _phone(tester);
      final s = await _atTable(tester);
      s.answerMe(recordedMe('me_look_stage'));
      s.resume();
      await _begun(tester, find.byType(YourCardScreen));
      await _noGaps(tester);
      await s.close(tester);
    });

    testWidgets('with reduce motion it is a cut', (tester) async {
      final s = await _atTable(tester, still: true);
      s.answerMe(recordedMe('me_look_stage'));
      s.resume();
      await _begun(tester, find.byType(YourCardScreen));
      expect(find.byType(AtTableScreen), findsNothing);
      expect(_sceneArt, findsNothing);
      await s.close(tester);
    });
  });

  group('every other change of screen is still a crossfade', () {
    testWidgets('talk to vote (day to day)', (tester) async {
      final s = await ShellSetup.pump(
        tester,
        recordedMe('me_talk_ready'),
        before: (s) => s.answerNightResultsSeen(),
      );
      await s.settle(tester);
      expect(find.byType(TalkScreen), findsOneWidget);
      s.answerMe(recordedMe('me_voting_unpicked'));
      s.resume();
      await _begun(tester, find.byType(VoteScreen));
      expect(find.byType(TalkScreen), findsOneWidget, reason: 'leaving');
      expect(_sceneArt, findsNothing);
      await tester.pump(Motion.settle + _ms * 3);
      await tester.pump();
      expect(find.byType(TalkScreen), findsNothing);
      expect(find.byType(VoteScreen), findsOneWidget);
      await s.close(tester);
    });

    testWidgets('vote to the count (no wipe, decided 22 Nov 2026)', (
      tester,
    ) async {
      final results = recordedResults('results_doppelganger');
      final s = await ShellSetup.pump(
        tester,
        recordedMe('me_voting_locked'),
        learned: Cue.values.toSet(),
        before: (s) => s.answerResults(results),
      );
      await s.settle(tester);
      expect(find.byType(VoteScreen), findsOneWidget);
      s.answerMe(resultsMeFor(results, viewer: 'Ben', host: 'Ana'));
      s.resume();
      await _begun(tester, find.byType(CountScreen));
      expect(find.byType(VoteScreen), findsOneWidget, reason: 'leaving');
      expect(_sceneArt, findsNothing);
      await tester.pump(Motion.settle + _ms * 3);
      await tester.pump();
      expect(find.byType(VoteScreen), findsNothing);
      await s.close(tester);
    });

    testWidgets('04 to the night board (night to night)', (tester) async {
      final s = await ShellSetup.pump(tester, recordedMe('me_look_ready'));
      await s.settle(tester);
      s.answerMe(recordedMe('me_choose_prompt_seer'));
      s.resume();
      await _begun(tester, find.byType(NightBoard));
      expect(_sceneArt, findsNothing);
      await tester.pump(Motion.settle + _ms * 3);
      await tester.pump();
      expect(find.byType(YourCardScreen), findsNothing);
      await s.close(tester);
    });
  });
}
