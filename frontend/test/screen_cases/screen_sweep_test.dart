import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/faces/face_content.dart';
import 'package:midnight_village/design_system/faces/held_face.dart';
import 'package:midnight_village/design_system/models/role.dart';
import 'package:midnight_village/design_system/primitives/paper_card.dart';
import 'package:midnight_village/design_system/primitives/primary_button.dart';
import 'package:midnight_village/design_system/primitives/secondary_button.dart';
import 'package:midnight_village/design_system/primitives/until_touched.dart';

import '../helpers/finger.dart';
import '../helpers/pump_skinned.dart';
import '../helpers/screen_sweep.dart';

// The sweep sees what it is for: a screen that breaks a rule is reported,
// one that keeps them is not.

Widget _page(Widget body, {VoidCallback? onPressed}) => Column(
  mainAxisAlignment: MainAxisAlignment.end,
  children: [
    body,
    PrimaryButton(label: Words.forTest('Go'), onPressed: onPressed ?? () {}),
  ],
);

/// A main button that rebuilds as a new widget on the frame a finger lands,
/// so the finger's lift reaches a button it never went down on.
class _Jumpy extends StatefulWidget {
  const _Jumpy();

  @override
  State<_Jumpy> createState() => _JumpyState();
}

class _JumpyState extends State<_Jumpy> {
  var _down = 0;

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: (_) => setState(() => _down++),
    child: PrimaryButton(
      key: ValueKey(_down),
      label: Words.forTest('Go'),
      onPressed: () {},
    ),
  );
}

/// A main button whose press sets off an animation that, as it settles a
/// few frames later (while the finger is still down), rebuilds the button as
/// a new one: nothing changes on the frame the finger lands.
class _SettlesUnderTheFinger extends StatefulWidget {
  const _SettlesUnderTheFinger();

  @override
  State<_SettlesUnderTheFinger> createState() => _SettlesState();
}

class _SettlesState extends State<_SettlesUnderTheFinger>
    with SingleTickerProviderStateMixin {
  late final _sink =
      AnimationController(
        vsync: this,
        duration: const Duration(milliseconds: 40),
      )..addStatusListener((s) {
        if (s == AnimationStatus.completed) setState(() => _settled++);
      });
  var _settled = 0;

  @override
  void dispose() {
    _sink.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Listener(
    onPointerDown: (_) => _sink.forward(from: 0),
    child: PrimaryButton(
      key: ValueKey(_settled),
      label: Words.forTest('Go'),
      onPressed: () {},
    ),
  );
}

/// A main button under a layer that takes the first touch: put away by it
/// ([goes]) or not, [marked] as the kit marks such a layer or not.
class _UpUntilTouched extends StatefulWidget {
  // A key each: one test pumps three, and a state kept from the one before
  // would already be put away.
  const _UpUntilTouched({super.key, required this.goes, this.marked = true});

  final bool goes;
  final bool marked;

  @override
  State<_UpUntilTouched> createState() => _UpUntilTouchedState();
}

class _UpUntilTouchedState extends State<_UpUntilTouched> {
  var _up = true;

  @override
  Widget build(BuildContext context) {
    final layer = GestureDetector(
      behavior: HitTestBehavior.opaque,
      onTapDown: (_) {
        if (widget.goes) setState(() => _up = false);
      },
    );
    return Stack(
      children: [
        _page(const SizedBox(height: 10)),
        if (_up)
          Positioned.fill(
            child: widget.marked ? UntilTouched(child: layer) : layer,
          ),
      ],
    );
  }
}

/// A sample's player name ("Ana") with a paper card laid [over] it or under.
Widget _nameAnd({required bool over}) {
  const name = Text('Ana');
  final card = PaperCard(child: const SizedBox(width: 80, height: 40));
  return _page(
    SizedBox(
      width: 120,
      height: 60,
      child: Stack(children: over ? [name, card] : [card, name]),
    ),
  );
}

void main() {
  testWidgets('a screen that keeps the rules passes', (tester) async {
    final problems = await sweepScreen(
      tester,
      (t) => pumpSkinned(t, _page(const SizedBox(height: 10))),
      const SweepPlan(main: MainAction.button()),
    );
    expect(problems, isEmpty);
  });

  testWidgets('an overflow is reported, at the size it happens', (
    tester,
  ) async {
    final problems = await sweepScreen(
      tester,
      (t) => pumpSkinned(t, _page(const SizedBox(height: 700))),
      const SweepPlan(),
    );
    expect(problems.join('\n'), contains('360x640'));
    expect(problems.join('\n'), contains('overflowed'));
  });

  testWidgets('a main button under another piece is reported', (tester) async {
    final problems = await sweepScreen(
      tester,
      (t) => pumpSkinned(
        t,
        Stack(
          children: [
            _page(const SizedBox.shrink()),
            const Positioned.fill(child: ColoredBox(color: Colors.black)),
          ],
        ),
      ),
      const SweepPlan(),
    );
    expect(problems.join('\n'), contains('main button under a piece'));
  });

  testWidgets('a press a finger loses is reported', (tester) async {
    final problems = await sweepScreen(
      tester,
      (t) => pumpSkinned(
        t,
        const Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [_Jumpy()],
        ),
      ),
      const SweepPlan(),
    );
    expect(problems.join('\n'), contains('did not reach the main button'));
  });

  testWidgets('a press lost to an animation settling mid-press is reported', (
    tester,
  ) async {
    final problems = await sweepScreen(
      tester,
      (t) => pumpSkinned(
        t,
        const Column(
          mainAxisAlignment: MainAxisAlignment.end,
          children: [_SettlesUnderTheFinger()],
        ),
      ),
      const SweepPlan(),
    );
    expect(problems.join('\n'), contains('did not reach the main button'));
  });

  testWidgets('a player\'s name under a piece is reported, over one is not', (
    tester,
  ) async {
    final covered = await sweepScreen(
      tester,
      (t) => pumpSkinned(t, _nameAnd(over: true)),
      const SweepPlan(),
    );
    expect(covered.join('\n'), contains('Ana ("Ana") is covered'));
    final onTop = await sweepScreen(
      tester,
      (t) => pumpSkinned(t, _nameAnd(over: false)),
      const SweepPlan(),
    );
    expect(onTop, isEmpty);
  });

  testWidgets('what a hold shows may lie on a name; it must be whole on the '
      'screen itself', (tester) async {
    // The held face is there only while the finger is down: it is read over
    // the screen, so it covers names by design (06, 08's My night).
    Widget held({required double top}) => _page(
      SizedBox(
        width: 300,
        height: 400,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            const Text('Ana'),
            Positioned(
              left: 0,
              top: top,
              width: 280,
              height: 380,
              child: HeldFace(
                content: FaceContent.roleText(RoleId.villager),
                page: 0,
                fill: true,
              ),
            ),
          ],
        ),
      ),
    );
    final over = await sweepScreen(
      tester,
      (t) => pumpSkinned(t, held(top: 0)),
      const SweepPlan(),
    );
    expect(over.where((p) => p.contains('is covered')), isEmpty);
    expect(over.where((p) => p.contains('held face')), isEmpty);
    final off = await sweepScreen(
      tester,
      (t) => pumpSkinned(t, held(top: -2000)),
      const SweepPlan(),
    );
    expect(
      off.join('\n'),
      contains('the held face is not whole on the screen'),
    );
  });

  testWidgets('a layer up until touched may lie on the main button when one '
      'touch puts it away; one that stays is reported', (tester) async {
    final goes = await sweepScreen(
      tester,
      (t) =>
          pumpSkinned(t, const _UpUntilTouched(key: ValueKey(1), goes: true)),
      const SweepPlan(main: MainAction.button()),
    );
    expect(goes, isEmpty);
    final stays = await sweepScreen(
      tester,
      (t) =>
          pumpSkinned(t, const _UpUntilTouched(key: ValueKey(2), goes: false)),
      const SweepPlan(main: MainAction.button()),
    );
    expect(stays.join('\n'), contains('one touch did not put away'));
    // Without the kit's mark the same layer is a piece over the main button.
    final unmarked = await sweepScreen(
      tester,
      (t) => pumpSkinned(
        t,
        const _UpUntilTouched(key: ValueKey(3), goes: true, marked: false),
      ),
      const SweepPlan(main: MainAction.button()),
    );
    expect(unmarked.join('\n'), contains('main button under a piece'));
  });

  testWidgets('a tree that keeps its own text size is reported', (
    tester,
  ) async {
    final problems = await sweepScreen(
      tester,
      (t) => pumpSkinned(
        t,
        Builder(
          builder: (context) => MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(textScaler: TextScaler.noScaling),
            child: _page(const Text('Words')),
          ),
        ),
      ),
      const SweepPlan(),
    );
    expect(problems.join('\n'), contains('text x1.3 did not take'));
  });

  testWidgets('a main button a lazy list never builds is none', (tester) async {
    final problems = await sweepScreen(
      tester,
      (t) => pumpSkinned(
        t,
        ListView.builder(
          itemCount: 60,
          itemBuilder: (_, i) => i < 59
              ? const SizedBox(height: 60)
              : PrimaryButton(label: Words.forTest('Go'), onPressed: () {}),
        ),
      ),
      const SweepPlan(),
    );
    expect(problems.join('\n'), contains('no main button acts (none built)'));
  });

  testWidgets('a state with no main action passes when it says why', (
    tester,
  ) async {
    final problems = await sweepScreen(
      tester,
      (t) => pumpSkinned(t, const Text('Waiting')),
      SweepPlan.noMainAction('it waits'),
    );
    expect(problems, isEmpty);
  });

  testWidgets('a plain tap on any of the kit\'s actions fails the test', (
    tester,
  ) async {
    await pumpSkinned(
      tester,
      SecondaryButton(label: Words.forTest('Leave'), onPressed: () {}),
    );
    await tester.tap(find.byType(SecondaryButton));
    expect(tester.takeException().toString(), contains('pressLikeAFinger'));
    await pressLikeAFinger(tester, find.byType(SecondaryButton));
    expect(tester.takeException(), isNull);
  });

  testWidgets('a plain tap on anything that takes a tap fails the test: a part '
      'nobody listed, and one made tomorrow', (tester) async {
    var taps = 0;
    await pumpSkinned(
      tester,
      // Not one of the kit's parts: only a detector that recognises a tap.
      GestureDetector(
        onTap: () => taps++,
        child: const SizedBox(
          width: 120,
          height: 120,
          child: ColoredBox(color: Color(0xFF000000)),
        ),
      ),
    );
    await tester.tap(find.byType(GestureDetector));
    expect(tester.takeException().toString(), contains('pressLikeAFinger'));
    await pressLikeAFinger(tester, find.byType(GestureDetector));
    expect(tester.takeException(), isNull);
    expect(taps, 2, reason: 'the rule watches; it takes no tap away');
  });

  test('every file still let off the rule still taps plainly: the list only '
      'shrinks', () {
    for (final MapEntry(key: file, value: why) in notYetHeld.entries) {
      expect(why, isNotEmpty);
      expect(File(file).existsSync(), isTrue, reason: '$file is gone');
      expect(
        File(file).readAsStringSync(),
        contains('tester.tap('),
        reason: '$file no longer taps plainly: take it off `notYetHeld`',
      );
    }
  });

  testWidgets('a drag, a press with time on the glass, and a tap on what takes '
      'none are not instant taps', (tester) async {
    await pumpSkinned(
      tester,
      GestureDetector(
        onTap: () {},
        child: const SizedBox(
          width: 200,
          height: 200,
          child: ColoredBox(color: Color(0xFF000000)),
        ),
      ),
    );
    await tester.drag(find.byType(GestureDetector), const Offset(0, 80));
    expect(tester.takeException(), isNull, reason: 'the finger moved');
    final finger = await tester.startGesture(
      tester.getCenter(find.byType(GestureDetector)),
    );
    await tester.pump(const Duration(milliseconds: 50));
    await finger.up();
    expect(tester.takeException(), isNull, reason: 'time passed');
    await pumpSkinned(tester, const Text('Waiting'));
    await tester.tap(find.text('Waiting'));
    expect(tester.takeException(), isNull, reason: 'nothing there takes a tap');
  });

  testWidgets('a state that says it shows a main button and shows none', (
    tester,
  ) async {
    final problems = await sweepScreen(
      tester,
      (t) => pumpSkinned(t, const SizedBox.shrink()),
      const SweepPlan(main: MainAction.button()),
    );
    expect(problems.join('\n'), contains('no main button acts'));
  });

  testWidgets('a plain tap on a main button fails the test that does it', (
    tester,
  ) async {
    await pumpSkinned(tester, _page(const SizedBox.shrink()));
    await tester.tap(find.byType(PrimaryButton));
    expect(tester.takeException().toString(), contains('pressLikeAFinger'));
    await pressLikeAFinger(tester, find.byType(PrimaryButton));
    expect(tester.takeException(), isNull);
  });
}
