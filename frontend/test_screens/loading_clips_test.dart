// What a wait and a failed send look like in motion (issue 10): four short
// scenes of the real app, a PNG per frame, put together as looping WebPs by
// `tool/loading_clips.sh` (`just loading-clips`). Not part of `just test`.
//
// The frames are drawn on the test's clock (so the same every run): a step
// is 83 ms (12 per second); a long wait is stepped wider, and each frame
// says how long it stays (`<clip>/NNN-<ms>.png`).
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/copy/copy.dart';
import 'package:midnight_village/design_system/primitives/face_down_card.dart';
import 'package:midnight_village/design_system/teach/learned_store.dart';

import '../test/helpers/contract/contract_samples.dart';
import '../test/helpers/contract/server_json.dart' show serverMyTable;
import '../test/helpers/mock_http_client.dart';
import '../test/helpers/outcome_samples.dart';
import '../test/helpers/shell_setup.dart';
import '../test/helpers/table_setup.dart';

const _dir = String.fromEnvironment(
  'CLIPS_DIR',
  defaultValue: 'build/loading_clips',
);

const _width = 390.0;
const _height = 844.0;

/// 12 frames a second.
const _step = Duration(milliseconds: 83);

/// One clip: frames written as they are drawn.
class _Clip {
  _Clip(this.tester, this.name) {
    final dir = Directory('$_dir/$name');
    if (dir.existsSync()) dir.deleteSync(recursive: true);
    dir.createSync(recursive: true);
  }

  final WidgetTester tester;
  final String name;
  var _n = 0;

  /// Draws the frame now, to stay [ms] on screen.
  Future<void> shoot(int ms) async {
    final images = [
      for (final element in find.byType(Image).evaluate())
        ((element.widget as Image).image, element),
    ];
    if (images.isNotEmpty) {
      await tester.runAsync(
        () => Future.wait([
          for (final (provider, context) in images)
            precacheImage(provider, context),
        ]),
      );
      // The pictures are in the cache: draw them (no time passes).
      await tester.pump();
    }
    final bytes = await tester.runAsync(() async {
      final image = await captureImage(tester.binding.rootElement!);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      return data!.buffer.asUint8List();
    });
    final index = (_n++).toString().padLeft(3, '0');
    File('$_dir/$name/$index-$ms.png').writeAsBytesSync(bytes!);
  }

  /// Runs the clock for [total] in frames of [step], drawing each.
  Future<void> run(Duration total, {Duration step = _step}) async {
    for (var left = total; left > Duration.zero; left -= step) {
      await tester.pump(step);
      await shoot(step.inMilliseconds);
    }
  }
}

Future<void> _phone(WidgetTester tester) async {
  // One pixel per logical pixel: the clips are 390 wide.
  tester.view.physicalSize = const Size(_width, _height);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  WidgetsApp.debugAllowBannerOverride = false;
  addTearDown(() => WidgetsApp.debugAllowBannerOverride = true);
}

void main() {
  testWidgets('tap-busy-done: Start a table, busy in the frame of the tap, '
      'then 02', (tester) async {
    await _phone(tester);
    late HeldReplies start;
    final setup = await TableSetup.pump(
      tester,
      signedInAs: 'Ana',
      userId: memberId(v2Lobby('created_with_defaults'), 'Ana'),
      lastWon: false,
      timesOut: false,
      before: (s) {
        start = s.http.hold(method: 'POST', path: '/lobbies/');
        s.http.answer(
          'POST',
          '/lobbies/',
          v2Lobby('created_with_defaults'),
          status: 201,
        );
      },
    );
    final clip = _Clip(tester, 'tap-busy-done');
    await clip.run(_step * 3);
    final finger = await tester.startGesture(
      tester.getCenter(find.text(JoinCopy.startTable)),
    );
    await clip.run(_step * 2);
    await finger.up();
    await clip.run(_step * 8);
    setup.sitAt(v2Lobby('created_with_defaults'), 'Ana');
    start.releaseAll();
    await clip.run(_step * 14);
    await setup.close(tester);
  });

  testWidgets('slow-join: a join that takes seven seconds', (tester) async {
    await _phone(tester);
    late HeldReplies join;
    final setup = await TableSetup.pump(
      tester,
      signedInAs: 'Ben',
      lastWon: false,
      timesOut: false,
      before: (s) {
        join = s.http.hold(method: 'POST', path: '/lobbies/V9YC2J/join/');
        s.http.answer(
          'POST',
          '/lobbies/V9YC2J/join/',
          ContractSamples.map('http/lobby/joined'),
        );
      },
    );
    await tester.tap(find.text(JoinCopy.joinTable));
    await tester.pump();
    await tester.enterText(find.byType(TextField).last, 'V9YC2J');
    await tester.pump();
    final clip = _Clip(tester, 'slow-join');
    await clip.run(_step * 3);
    final finger = await tester.startGesture(
      tester.getCenter(find.text(JoinCopy.join)),
    );
    await clip.run(_step * 2);
    await finger.up();
    // The first second at full rate (the lanterns come in at 0.3 s), the
    // rest of the wait stepped wider.
    await clip.run(const Duration(seconds: 1));
    await clip.run(
      const Duration(seconds: 6),
      step: const Duration(milliseconds: 250),
    );
    setup.sitAt(v2Lobby('detail_auto_deck_5'), 'Ben');
    join.releaseAll();
    await clip.run(_step * 14);
    await setup.close(tester);
  });

  testWidgets('failed-send-retry: Play again with no answer, "Not sent.", '
      '"Try again", then 02', (tester) async {
    await _phone(tester);
    final results = recordedResults('results');
    final s = await ShellSetup.pump(
      tester,
      resultsMeFor(results, viewer: 'Ana', host: 'Ana'),
      learned: Cue.values.toSet(),
      before: (s) => s.answerResults(results),
    );
    await s.settle(tester);
    for (var i = 0; i < 40; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.tap(find.text(CountCopy.seeWhoWon));
    await s.settle(tester);
    final code = s.me['lobby_code'] as String;
    final path = '/lobbies/$code/play-again/';
    late HeldReplies first;
    first = s.http.hold(method: 'POST', path: path);
    s.http.answer('POST', path, 'Server Error', status: 503);

    final clip = _Clip(tester, 'failed-send-retry');
    await clip.run(_step * 3);
    final finger = await tester.startGesture(
      tester.getCenter(find.text(ResultsCopy.playAgain)),
    );
    await clip.run(_step * 2);
    await finger.up();
    await clip.run(_step * 8);
    first.releaseAll();
    s.http.stopHolding(method: 'POST', path: path);
    await clip.run(_step * 10);
    // The phone is back: the very same request, sent again.
    s.http.answer('POST', path, ContractSamples.load('http/lobby/play_again'));
    s.answerLobby(code);
    s.answerTable(
      serverMyTable(
        code: code,
        isHost: true,
        gameId: s.gameId,
        phase: 'results',
      ),
    );
    final again = await tester.startGesture(
      tester.getCenter(find.text(BannerCopy.tryAgain)),
    );
    await clip.run(_step * 2);
    await again.up();
    await clip.run(_step * 14);
    await s.close(tester);
  });

  testWidgets('reconnect: a game on screen loses the server and gets it '
      'back', (tester) async {
    await _phone(tester);
    final me = recordedMe('me_look_stage');
    final s = await ShellSetup.pump(tester, me, learned: Cue.values.toSet());
    await s.settle(tester);
    final clip = _Clip(tester, 'reconnect');
    await clip.run(_step * 4);
    s.socket(connected: false);
    s.failMe();
    s.resume();
    await clip.run(_step * 14);
    s.answerMe(me);
    s.socket(connected: true);
    await clip.run(_step * 14);
    expect(find.byType(FaceDownCard), findsOneWidget);
    await s.close(tester);
  });
}
