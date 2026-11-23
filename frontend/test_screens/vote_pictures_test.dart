// The vote's locked row in pictures, for a look: the locked state, the moment
// of the lock as four frames, and the vote at several table sizes (one long name, a large text
// size). Run it with `just vote-pictures`; it is not part of `just test`.
// `just contact-sheet <folder>` makes one sheet of a folder.
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/primitives/primary_button.dart';
import 'package:midnight_village/design_system/skin/ground.dart';
import 'package:midnight_village/design_system/teach/learned_store.dart';
import 'package:midnight_village/features/game/domain/game_me.dart';
import 'package:midnight_village/features/game/presentation/shell/vote_screen.dart';

import '../test/helpers/component_sheet.dart' show learnedOverrides;
import '../test/helpers/pump_skinned.dart';
import '../test/helpers/sheet/sheet_data.dart' as sheet;

/// Where the pictures go: `--dart-define=VOTE_PICTURES_DIR=/some/folder`.
const _dir = String.fromEnvironment(
  'VOTE_PICTURES_DIR',
  defaultValue: 'build/vote_pictures',
);
const _width = int.fromEnvironment('VOTE_PICTURES_WIDTH', defaultValue: 360);
const _height = 740.0;
const _ratio = 2.0;
const _long = 'Rosalind Fairweather-Okonkwo';

class _Host extends StatefulWidget {
  const _Host({required this.me});

  final GameMe me;

  @override
  State<_Host> createState() => _HostState();
}

class _HostState extends State<_Host> {
  late GameMe _me = widget.me;

  @override
  Widget build(BuildContext context) => ProviderScope(
    overrides: learnedOverrides(Cue.values.toSet()),
    child: VoteView(
      me: _me,
      secondsLeft: 72,
      remaining: 0.6,
      onPick: (id) =>
          setState(() => _me = _me.withVote(MyVote.local(id, locked: false))),
      onLock: (id) =>
          setState(() => _me = _me.withVote(MyVote.local(id, locked: true))),
    ),
  );
}

/// A table of [players] (this phone one of them), one seat with a long name
/// where there are six or more.
Map<String, dynamic> _table(int players, {bool long = false}) {
  final recorded = sheet.recordedMe('me_voting_unpicked');
  final me = players > 5
      ? sheet.tableOf(
          recorded,
          add: players - 5,
          rename: long ? const {'Seat 32': _long} : const {},
        )
      : recorded;
  final seats = (me['players'] as List).cast<Map<String, dynamic>>();
  final targets = <int>[];
  for (final p in seats.skip(players > 5 ? 5 : 0)) {
    if (players > 5) targets.add(p['player_id'] as int);
  }
  if (players > 5) {
    (me['vote_targets'] as List).addAll(targets);
  } else {
    me['vote_targets'] = (me['vote_targets'] as List)
        .take(players - 1)
        .toList();
  }
  return me;
}

Future<void> _show(
  WidgetTester tester,
  Map<String, dynamic> me, {
  double textScale = 1,
}) async {
  const phone = Size(_width * 1.0, _height);
  tester.view.physicalSize = phone * _ratio;
  tester.view.devicePixelRatio = _ratio;
  addTearDown(tester.view.reset);
  await pumpSkinned(
    tester,
    MediaQuery(
      data: MediaQueryData(
        size: phone,
        textScaler: TextScaler.linear(textScale),
      ),
      child: SizedBox.fromSize(
        size: phone,
        child: _Host(me: GameMe.fromJson(me)),
      ),
    ),
    ground: GroundKind.day,
  );
  await tester.pump();
  await tester.runAsync(
    () => Future.wait([
      for (final e in find.byType(Image).evaluate())
        precacheImage((e.widget as Image).image, e),
    ]),
  );
  await tester.pump();
}

Future<void> _save(WidgetTester tester, String name) async {
  // The test binding turns blurred shadows into solid blocks as it paints;
  // the pictures show the real ones, and the binding's check is given them
  // back.
  debugDisableShadows = false;
  final png = await tester.runAsync(() async {
    final image = await captureImage(tester.binding.rootElement!);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return bytes!.buffer.asUint8List();
  });
  debugDisableShadows = true;
  Directory(_dir).createSync(recursive: true);
  File('$_dir/$name.png').writeAsBytesSync(Uint8List.fromList(png!));
}

Future<void> _pick(WidgetTester tester, String name) async {
  await tester.tap(find.text(name));
  await tester.pump(const Duration(milliseconds: 400));
}

void main() {
  {
    const label = 'blood-fill';

    testWidgets('locked, $label: six players', (tester) async {
      await _show(tester, _table(6, long: true));
      await _pick(tester, sheet.cleo.name);
      await tester.tap(find.byType(PrimaryButton).last);
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 600));
      await _save(tester, 'locked-$label');
    });

    testWidgets('the moment of the lock, $label: four frames', (tester) async {
      await _show(tester, _table(6, long: true));
      await _pick(tester, sheet.cleo.name);
      await _save(tester, 'moment-$label-0-picked');
      await tester.tap(find.byType(PrimaryButton).last);
      var at = 0;
      for (final (i, ms) in [0, 50, 110, 400].indexed) {
        await tester.pump(Duration(milliseconds: ms - at));
        at = ms;
        await _save(tester, 'moment-$label-${i + 1}-${ms}ms');
      }
    });
  }

  for (final (name, players, long, scale) in [
    ('sizes-3', 3, false, 1.0),
    ('sizes-4', 4, false, 1.0),
    ('sizes-6', 6, false, 1.0),
    ('sizes-10', 10, false, 1.0),
    ('sizes-long-name', 6, true, 1.0),
    ('sizes-large-text', 6, true, 1.6),
  ]) {
    testWidgets('$name: locked on one', (tester) async {
      await _show(tester, _table(players, long: long), textScale: scale);
      await _pick(tester, long ? _long : sheet.cleo.name);
      await tester.tap(find.byType(PrimaryButton).last);
      await tester.pump(const Duration(milliseconds: 1));
      await tester.pump(const Duration(milliseconds: 600));
      expect(tester.takeException(), isNull);
      await _save(tester, name);
    });
  }
}
