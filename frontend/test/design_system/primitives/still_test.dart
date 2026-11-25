import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/primitives/still.dart';

/// Counts how often it is painted, and paints a band of [color].
class _Counting extends CustomPainter {
  _Counting(this.color, this.paints);

  final Color color;
  final List<int> paints;

  @override
  void paint(Canvas canvas, Size size) {
    paints[0]++;
    canvas.drawRect(Offset.zero & size, Paint()..color = color);
  }

  @override
  bool shouldRepaint(_Counting old) => old.color != color;
}

/// A loop above the still part (as an ambient candle will be): it asks for a
/// frame every tick, in its own repaint boundary.
class _Loop extends StatefulWidget {
  const _Loop();

  @override
  State<_Loop> createState() => _LoopState();
}

class _LoopState extends State<_Loop> with SingleTickerProviderStateMixin {
  late final _c = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 300),
  )..repeat();

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => RepaintBoundary(
    child: AnimatedBuilder(
      animation: _c,
      builder: (context, _) => Opacity(
        opacity: 0.2 + 0.6 * _c.value,
        child: const SizedBox(
          width: 20,
          height: 20,
          child: ColoredBox(color: Colors.amber),
        ),
      ),
    ),
  );
}

void main() {
  Widget still(Color color, List<int> paints, {bool live = false}) =>
      Directionality(
        textDirection: TextDirection.ltr,
        child: Stack(
          children: [
            Positioned.fill(
              child: Still(
                live: live,
                child: CustomPaint(painter: _Counting(color, paints)),
              ),
            ),
            const Center(child: _Loop()),
          ],
        ),
      );

  testWidgets('a loop above a still part never draws it again', (tester) async {
    final paints = [0];
    await tester.pumpWidget(still(Colors.indigo, paints));
    final made = Still.made;
    final box = tester.renderObject<RenderStill>(find.byType(Still).last.first);
    expect(box.picture, isNotNull);
    for (var i = 0; i < 20; i++) {
      await tester.pump(const Duration(milliseconds: 17));
    }
    expect(paints[0], 1);
    expect(Still.made, made);
  });

  testWidgets('a change inside makes the picture again, once', (tester) async {
    final paints = [0];
    await tester.pumpWidget(still(Colors.indigo, paints));
    final made = Still.made;
    await tester.pumpWidget(still(Colors.teal, paints));
    await tester.pump(const Duration(milliseconds: 17));
    expect(paints[0], 2);
    expect(Still.made, made + 1);
  });

  testWidgets('live, it is drawn as it is and keeps no picture', (
    tester,
  ) async {
    final paints = [0];
    await tester.pumpWidget(still(Colors.indigo, paints, live: true));
    final box = tester.renderObject<RenderStill>(find.byType(Still).last.first);
    expect(box.picture, isNull);
    expect(paints[0], 1);
  });

  testWidgets('a still part inside a still part is held by the outer one', (
    tester,
  ) async {
    final paints = [0];
    await tester.pumpWidget(
      Directionality(
        textDirection: TextDirection.ltr,
        child: Still(
          child: Still(
            child: CustomPaint(painter: _Counting(Colors.indigo, paints)),
          ),
        ),
      ),
    );
    expect(
      tester.renderObjectList(find.byType(Still)).whereType<RenderStill>(),
      hasLength(1),
    );
  });

  testWidgets(
    'a thing that repaints by itself inside a still part is refused',
    (tester) async {
      await tester.pumpWidget(
        const Directionality(
          textDirection: TextDirection.ltr,
          child: Still(child: RepaintBoundary(child: SizedBox.expand())),
        ),
      );
      expect(tester.takeException(), isA<FlutterError>());
    },
  );
}
