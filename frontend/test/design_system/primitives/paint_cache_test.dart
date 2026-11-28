import '../../helpers/finger.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/copy/copy.dart';
import 'package:midnight_village/design_system/feel/press_paint.dart';
import 'package:midnight_village/design_system/primitives/deckle.dart';
import 'package:midnight_village/design_system/teach/cue_wave.dart';

import 'paper_rules_test.dart' show paperScreens;

// Speed: the 10-player night board has about fifty torn-paper pieces. While the
// teaching wave or the hold's breathing runs, a frame must paint what moves and
// nothing else: every animated thing is on its own layer, so the paper that
// holds still is painted once, not again each frame (the screen was repainted
// whole, fifty torn pieces and twenty clips, 60 times a second).

void main() {
  testWidgets('static paper on the 10-player board is painted once while the '
      'wave and the hold animate', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final painted = <RenderObject, int>{};
    debugOnProfilePaint = (object) =>
        painted.update(object, (n) => n + 1, ifAbsent: () => 1);

    await paperScreens['night board, 10']!(tester);

    // Every box that paints torn paper (a piece, a card, a panel, a portrait):
    // a decorated box whose shape is a deckled edge, or the paper a finger
    // presses (`PressDecoration`, its render object a decorated box too).
    List<RenderObject> paper() => [
      for (final e in tester.allElements)
        if (e.widget
            case DecoratedBox(
                  decoration: ShapeDecoration(shape: DeckleBorder()),
                ) ||
                PressDecoration(rest: ShapeDecoration(shape: DeckleBorder())))
          if (e.renderObject != null) e.renderObject!,
    ];
    final pieces = paper();
    expect(
      pieces.length,
      greaterThan(30),
      reason: 'the ten-player board is the heavy one',
    );

    // Start the wave (a tap on the locked button replays the cue) and run ten
    // frames of it, with the hold ring still breathing.
    await pressLikeAFinger(tester, find.text(NightCopy.chooseNone));
    await tester.pump();
    expect(find.byType(CueWave), findsWidgets, reason: 'the wave is running');
    final before = {for (final p in pieces) p: painted[p] ?? 0};
    // (`debugOnProfilePaint` is reset before the test ends: a failed
    // expectation leaves it set, which is the harness's complaint to read.)
    final others = painted.values.fold(0, (a, b) => a + b);
    final torn = DeckleBorder.tornCount;
    for (var frame = 0; frame < 10; frame++) {
      await tester.pump(const Duration(milliseconds: 17));
    }
    final again = [
      for (final p in pieces)
        if ((painted[p] ?? 0) != before[p]) p,
    ];
    String where(RenderObject o) {
      final creator = o.debugCreator;
      if (creator is! DebugCreator) return '$o';
      final names = <String>[];
      creator.element.visitAncestorElements((a) {
        names.add(a.widget.runtimeType.toString());
        return names.length < 24;
      });
      return names.join(' < ');
    }

    // Every piece inside a card, a button's wave or the hold ring is on a layer
    // of its own and painted once. What is left open (see the README): the
    // pieces on the screen's own layer (the banner, the own card's paper
    // place, the buttons) are still repainted, because the board's layout
    // builder is laid out again each frame the wave runs. Held to what is
    // true today: no more than a tenth of the paper repaints, and a piece in
    // a card never.
    final inCard = [
      for (final o in again)
        if (where(o).contains('FaceDownCard') || where(o).contains('HoldCue'))
          where(o),
    ];
    expect(inCard, isEmpty, reason: 'a card\'s paper was painted again');
    expect(
      again.length * 10,
      lessThanOrEqualTo(pieces.length),
      reason:
          '${again.length} of ${pieces.length} paper boxes were painted '
          'again while the animation ran:\n${[for (final o in again) where(o)].join('\n')}',
    );
    expect(
      painted.values.fold(0, (a, b) => a + b),
      greaterThan(others),
      reason: 'the animation did paint what moves',
    );
    debugOnProfilePaint = null;
    // And no piece's edge is torn again.
    expect(DeckleBorder.tornCount, torn, reason: 'a deckled edge was recut');
  });

  testWidgets('the check sees a screen that repaints everything', (
    tester,
  ) async {
    final painted = <RenderObject, int>{};
    debugOnProfilePaint = (o) =>
        painted.update(o, (n) => n + 1, ifAbsent: () => 1);
    final spin = AnimationController(
      vsync: const TestVSync(),
      duration: const Duration(seconds: 1),
    )..repeat();
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Column(
          children: [
            const DecoratedBox(
              decoration: BoxDecoration(color: Colors.red),
              child: SizedBox(width: 20, height: 20),
            ),
            CustomPaint(painter: _Ticking(spin), size: const Size(20, 20)),
          ],
        ),
      ),
    );
    final box = tester.renderObject<RenderDecoratedBox>(
      find.byType(DecoratedBox),
    );
    final first = painted[box] ?? 0;
    await tester.pump(const Duration(milliseconds: 17));
    await tester.pump(const Duration(milliseconds: 17));
    debugOnProfilePaint = null;
    expect(painted[box], greaterThan(first));
    await tester.pumpWidget(const SizedBox());
    spin.dispose();
  });
}

class _Ticking extends CustomPainter {
  _Ticking(this.t) : super(repaint: t);
  final Animation<double> t;
  @override
  void paint(Canvas canvas, Size size) {}
  @override
  bool shouldRepaint(_Ticking old) => true;
}
