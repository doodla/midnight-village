import 'dart:math';

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/copy/copy.dart';
import 'package:midnight_village/design_system/faces/face_content.dart';
import 'package:midnight_village/design_system/faces/held_face.dart';
import 'package:midnight_village/design_system/models/role.dart';
import 'package:midnight_village/design_system/night/night_pick.dart';
import 'package:midnight_village/design_system/primitives/hold_to_reveal.dart';
import 'package:midnight_village/design_system/primitives/primary_button.dart';

import '../../helpers/sheet/sheet_data.dart';
import 'board_harness.dart';

// The night uniformity test (first-time play spec, section 5, hook 8), at the
// widget level: a bystander must not tell one phone's night from another's.
// The board is built for every role, a player with no choice, and the
// Doppelganger before and after her copy, with the same table; what is
// compared, with the held face aside (only a hold shows it, and every phone
// holds):
// - the render tree (every box's size, place and paint, every word), the
//   widget tree and the semantics tree, with identity hashes left out;
// - the screen's pixels, as PNG;
// - after each step of one tap sequence: those trees, the button's label and
//   phase, and which cards are lifted;
// - when the face shows and when Choose unlocks (to the millisecond);
// - what the board sends: the same picks for every role.

/// What a phone's prompt is in window 2, by its dealt card.
NightPrompt _windowTwoPrompt(RoleId role) => switch (role) {
  RoleId.werewolf => NightPrompt.loneWerewolf,
  RoleId.seer => NightPrompt.seer,
  RoleId.robber => NightPrompt.robber,
  RoleId.troublemaker => NightPrompt.troublemaker,
  RoleId.drunk => NightPrompt.drunk,
  _ => NightPrompt.noChoice,
};

/// Every phone's "You" in window 1: the Doppelganger's look, everyone
/// else's nothing; and hers once her copy is back.
final _windowOne = <String, FaceContent>{
  for (final role in RoleId.values)
    role.name: FaceContent.nightYou(
      dealt: role,
      prompt: role == RoleId.doppelganger
          ? NightPrompt.doppelgangerLook
          : NightPrompt.noChoice,
    ),
  'doppelganger after her copy': FaceContent.copied(
    name: cleo.name,
    role: RoleId.robber,
  ),
};

/// Every phone's "You" in window 2, after a window 1: its prompt, and what
/// window 1 told it on the second page.
final _windowTwo = <String, FaceContent>{
  for (final role in RoleId.values)
    role.name: FaceContent.nightYou(
      dealt: role,
      prompt: _windowTwoPrompt(role),
      windowOne: role == RoleId.doppelganger
          ? CopiedResult(
              name: cleo.name,
              role: RoleId.robber,
              followUp: const NewCardResult(RoleId.werewolf),
            )
          : const WindowOneSlept(),
    ),
  'no choice, and no window 1': FaceContent.nightYou(
    dealt: RoleId.villager,
    prompt: NightPrompt.noChoice,
  ),
};

/// One player's run through the board, as a bystander sees it.
typedef _Seen = ({List<String> steps, List<List<NightPick>> sent});

/// The same taps on every phone: three picks (the third replaces the
/// oldest), an unpick, a quick tap on "You", a hold of "You", Choose.
Future<_Seen> _play(WidgetTester tester, BoardHarness board) async {
  await board.pump(tester);
  final steps = <String>[];
  void note(String step) => steps.add(
    '$step | ${button(tester)} | ${lifted(tester)}\n${visibleTrees(tester)}',
  );

  note('opened');
  for (final caption in [
    cleo.name,
    NightCopy.left,
    NightCopy.right,
    NightCopy.right,
    NightCopy.you,
  ]) {
    await tapCard(tester, caption);
    note('tapped $caption');
  }

  // The hold: the face shows at 120 ms, Choose unlocks at 0.8 s visible.
  final hold = await tester.startGesture(tester.getCenter(you));
  await tester.pump(HoldToReveal.holdDelay - const Duration(milliseconds: 1));
  final before = find.byType(HeldFace).evaluate().length;
  await tester.pump(const Duration(milliseconds: 1));
  final at = find.byType(HeldFace).evaluate().length;
  await tester.pump(
    HoldToReveal.revealedAfter - const Duration(milliseconds: 1),
  );
  final unlockedEarly = button(tester).$2;
  await tester.pump(const Duration(milliseconds: 1));
  steps.add(
    'face at 119 ms: $before, at 120 ms: $at; Choose at 0.799 s: '
    '$unlockedEarly, at 0.8 s: ${button(tester).$2}',
  );
  await hold.up();
  await tester.pump(kDoubleTapTimeout);
  note('held and let go');

  await tester.tap(find.byType(PrimaryButton));
  await tester.pump();
  note('chose');
  return (steps: steps, sent: board.sent);
}

/// Where every phone's runs differ from the first's: empty when all agree.
List<String> _differences(Map<String, Object> seen) {
  final first = seen.entries.first;
  return [
    for (final MapEntry(:key, :value) in seen.entries.skip(1))
      if ('$value' != '${first.value}')
        '$key differs from ${first.key}: '
            '${_firstDifference('${first.value}', '$value')}',
  ];
}

/// Where two snapshots part, for the failure message.
String _firstDifference(String a, String b) {
  final (x, y) = (a.split('\n'), b.split('\n'));
  for (var i = 0; i < x.length && i < y.length; i++) {
    if (x[i] != y[i]) {
      String cut(String s) {
        final words = s.replaceAll(RegExp(r'[\s│╎└├─┊┄]+'), ' ').trim();
        return words.substring(0, min(200, words.length));
      }

      return 'line $i, "${cut(x[i])}" against "${cut(y[i])}"';
    }
  }
  return '${x.length} lines against ${y.length}';
}

void main() {
  for (final (window, faces) in [
    (NightWindow.one, _windowOne),
    (NightWindow.two, _windowTwo),
  ]) {
    group('window ${window.chooses == 2 ? 1 : 2}', () {
      testWidgets('every phone draws the same board: trees and pixels', (
        tester,
      ) async {
        final trees = <String, String>{};
        final pixels = <String, String>{};
        for (final MapEntry(key: phone, value: face) in faces.entries) {
          await BoardHarness(face: face, window: window).pump(tester);
          trees[phone] = visibleTrees(tester);
          pixels[phone] = await screenPixels(tester);
          await tester.pumpWidget(const SizedBox());
        }
        expect(_differences(trees), isEmpty);
        expect(_differences(pixels), isEmpty);
      });

      testWidgets('the same taps give the same states, at the same times, '
          'and send the same picks', (tester) async {
        final seen = <String, _Seen>{};
        for (final MapEntry(key: phone, value: face) in faces.entries) {
          seen[phone] = await _play(
            tester,
            BoardHarness(face: face, window: window),
          );
          await tester.pumpWidget(const SizedBox());
        }
        expect(
          _differences({
            for (final MapEntry(:key, :value) in seen.entries) key: value.steps,
          }),
          isEmpty,
        );
        expect(
          {for (final s in seen.values) '${s.sent}'},
          {
            '${[
              [const CenterPick(0), const SelfPick()],
            ]}',
          },
        );
        expect(
          seen.values.first.steps.firstWhere((s) => s.startsWith('face at')),
          'face at 119 ms: 0, at 120 ms: 1; Choose at 0.799 s: '
          '${ButtonPhase.locked}, at 0.8 s: ${ButtonPhase.ready}',
        );
      });
    });
  }

  testWidgets('window 1: the Doppelganger\'s copy arriving changes nothing '
      'a bystander sees', (tester) async {
    final trees = <String, String>{};
    for (final (phone, before, after) in [
      (
        'doppelganger',
        _windowOne['doppelganger']!,
        _windowOne['doppelganger after her copy']!,
      ),
      ('villager', _windowOne['villager']!, _windowOne['villager']!),
    ]) {
      final board = BoardHarness(face: before, window: NightWindow.one);
      await board.pump(tester);
      await tapCard(tester, cleo.name);
      await tester.startGesture(tester.getCenter(you)).then((hold) async {
        await tester.pump(HoldToReveal.holdDelay + HoldToReveal.revealedAfter);
        await hold.up();
        await tester.pump(kDoubleTapTimeout);
      });
      await tester.tap(find.byType(PrimaryButton));
      await tester.pump();
      // Her result arrives with her follow-up prompt: a new face for "You".
      board.face = after;
      await tester.pumpWidget(board.build());
      await tester.pump();
      trees[phone] = visibleTrees(tester);
      await tester.pumpWidget(const SizedBox());
    }
    expect(_differences(trees), isEmpty);
  });

  group('the check fails on a tell', () {
    // A board whose phone draws one role-dependent word, small, in a corner:
    // what a careless change could add. Both comparisons must see it.
    Widget Function(Widget) leak(RoleId role) =>
        (board) => Stack(
          textDirection: TextDirection.ltr,
          children: [
            board,
            Positioned(
              left: 0,
              bottom: 0,
              child: Text(
                role.name,
                textDirection: TextDirection.ltr,
                style: const TextStyle(fontSize: 6, color: Color(0xFF808080)),
              ),
            ),
          ],
        );

    testWidgets('in the trees and in the pixels', (tester) async {
      final trees = <String, String>{};
      final pixels = <String, String>{};
      for (final role in [RoleId.seer, RoleId.villager]) {
        await BoardHarness(
          face: _windowTwo[role.name]!,
        ).pump(tester, wrap: leak(role));
        trees[role.name] = visibleTrees(tester);
        pixels[role.name] = await screenPixels(tester);
        await tester.pumpWidget(const SizedBox());
      }
      expect(_differences(trees), isNotEmpty);
      expect(_differences(pixels), isNotEmpty);
    });
  });
}
