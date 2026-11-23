import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/primitives/primary_button.dart';

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
