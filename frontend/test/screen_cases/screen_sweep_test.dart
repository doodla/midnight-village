import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/primitives/paper_card.dart';
import 'package:midnight_village/design_system/primitives/primary_button.dart';
import 'package:midnight_village/design_system/primitives/secondary_button.dart';

import '../helpers/finger.dart';
import '../helpers/pump_skinned.dart';
import '../helpers/screen_sweep.dart';

// The sweep sees what it is for: a screen that breaks a rule is reported,
// one that keeps them is not.

Widget _page(Widget body, {VoidCallback? onPressed}) => Column(
  mainAxisAlignment: MainAxisAlignment.end,
  children: [
    body,
    PrimaryButton(label: 'Go', onPressed: onPressed ?? () {}),
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
    child: PrimaryButton(key: ValueKey(_down), label: 'Go', onPressed: () {}),
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
      label: 'Go',
      onPressed: () {},
    ),
  );
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
              : PrimaryButton(label: 'Go', onPressed: () {}),
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
      SecondaryButton(label: 'Leave', onPressed: () {}),
    );
    await tester.tap(find.byType(SecondaryButton));
    expect(tester.takeException().toString(), contains('pressLikeAFinger'));
    await pressLikeAFinger(tester, find.byType(SecondaryButton));
    expect(tester.takeException(), isNull);
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
