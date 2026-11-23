// The vote's choosing and locking in motion: a finger on a row, the pick, the
// lock tap and the stamp landing, one PNG per 17 ms step (real speed for a
// 60 Hz phone) into a folder, for a recording. Run it with `just vote-frames`
// (see frontend/test/README.md); it is not part of `just test`.
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/primitives/primary_button.dart';
import 'package:midnight_village/design_system/teach/learned_store.dart';

import '../test/helpers/shell_setup.dart';
import '../test/helpers/sheet/sheet_data.dart' as sheet;

/// Where the frames go: `--dart-define=VOTE_FRAMES_DIR=/some/folder`.
const _dir = String.fromEnvironment(
  'VOTE_FRAMES_DIR',
  defaultValue: 'build/vote_frames',
);

/// What to call the run (a folder name inside it), for before and after.
const _label = String.fromEnvironment('VOTE_FRAMES_LABEL', defaultValue: 'run');

/// The phone's width: `--dart-define=VOTE_FRAMES_WIDTH=390`.
const _width = int.fromEnvironment('VOTE_FRAMES_WIDTH', defaultValue: 360);

/// One frame every this many milliseconds: a 60 Hz phone's frame.
const _step = Duration(milliseconds: 17);

const _height = 740.0;
const _ratio = 2.0;

class _Film {
  _Film(this.name) {
    Directory('$_dir/$_label/$name').createSync(recursive: true);
  }

  final String name;
  var _n = 0;
  var _at = Duration.zero;

  Future<void> frame(WidgetTester tester, [String note = '']) async {
    // The test binding turns blurred shadows into solid blocks as it paints;
    // the film shows the real shadows.
    final png = await tester.runAsync(() async {
      final image = await captureImage(tester.binding.rootElement!);
      final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
      image.dispose();
      return bytes!.buffer.asUint8List();
    });
    File(
      '$_dir/$_label/$name/${(_n++).toString().padLeft(3, '0')}'
      '-${_at.inMilliseconds}ms${note.isEmpty ? '' : '-$note'}.png',
    ).writeAsBytesSync(Uint8List.fromList(png!));
  }

  Future<void> run(
    WidgetTester tester,
    Duration span, [
    String note = '',
  ]) async {
    for (var t = Duration.zero; t < span; t += _step) {
      await tester.pump(_step);
      _at += _step;
      await frame(tester, note);
    }
  }
}

/// Six at the table, the sixth with a long name (game 7 and one more).
Map<String, dynamic> _six() {
  final me = sheet.tableOf(
    sheet.recordedMe('me_voting_unpicked'),
    add: 1,
    rename: const {'Seat 32': 'Rosalind Fairweather-Okonkwo'},
  );
  // The new seat is one more this phone may vote for.
  final last = (me['players'] as List).last as Map<String, dynamic>;
  (me['vote_targets'] as List).add(last['player_id']);
  return me;
}

void main() {
  testWidgets('vote: finger, pick, lock; six players, one long name', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(_width * _ratio, _height * _ratio);
    tester.view.devicePixelRatio = _ratio;
    addTearDown(tester.view.reset);
    WidgetsApp.debugAllowBannerOverride = false;
    addTearDown(() => WidgetsApp.debugAllowBannerOverride = true);
    debugDisableShadows = false;
    final me = _six();
    final s = await ShellSetup.pump(
      tester,
      me,
      learned: Cue.values.toSet(),
      clock: DateTime.parse(
        me['deadline'] as String,
      ).subtract(const Duration(seconds: 14)),
    );
    await s.settle(tester);
    final film = _Film('vote');
    await film.frame(tester, 'open');
    s.answerPost('/vote/', 'game/vote_repicked');
    final cleo = find.text(sheet.cleo.name);
    final finger = await tester.startGesture(tester.getCenter(cleo));
    await film.run(tester, const Duration(milliseconds: 85), 'finger');
    await finger.up();
    await film.run(tester, const Duration(milliseconds: 340), 'picked');
    await s.settle(tester);
    await film.frame(tester, 'choosing');
    s.answerPost('/vote/', 'game/vote_locked');
    final down = await tester.startGesture(
      tester.getCenter(find.byType(PrimaryButton).last),
    );
    await film.run(tester, const Duration(milliseconds: 68), 'lock-down');
    await down.up();
    await film.run(tester, const Duration(milliseconds: 510), 'lock');
    await s.settle(tester);
    await film.frame(tester, 'locked');
    debugDisableShadows = true;
    await s.close(tester);
  });
}
