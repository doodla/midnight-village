import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/core/perf/field_recorder.dart';
import 'package:midnight_village/core/perf/perf_report.dart';
import 'package:midnight_village/design_system/perf/perf_strip.dart';
import 'package:midnight_village/design_system/skin/ground.dart';
import 'package:midnight_village/design_system/skin/ground_scope.dart';
import 'package:midnight_village/design_system/skin/skin_id.dart';
import 'package:midnight_village/design_system/skin/skin_theme.dart';

import '../../helpers/finger.dart';

const _app = Key('app');

Future<FieldRecorder> _pump(WidgetTester tester, {double bar = 24}) async {
  final recorder = FieldRecorder(now: () => 0, controlAt: (_, _) => null);
  await tester.binding.setSurfaceSize(const Size(412, 915));
  addTearDown(() => tester.binding.setSurfaceSize(null));
  tester.view.padding = FakeViewPadding(
    bottom: bar * tester.view.devicePixelRatio,
  );
  addTearDown(tester.view.resetPadding);
  await tester.pumpWidget(
    MaterialApp(
      theme: skinTheme(SkinId.fallback.skin),
      builder: (context, child) => GroundScope(
        ground: GroundKind.night,
        child: PerfStrip(recorder: recorder, child: child!),
      ),
      home: Builder(
        builder: (context) => SizedBox.expand(
          key: _app,
          child: Text('${MediaQuery.paddingOf(context).bottom}'),
        ),
      ),
    ),
  );
  return recorder;
}

void main() {
  testWidgets('the strip runs edge to edge at the bottom, above the system '
      'bar, and the app sits above it, never under it', (tester) async {
    await _pump(tester);
    final strip = tester.getRect(find.text(PerfWords.noTap));
    final app = tester.getRect(find.byKey(_app));
    expect(app.top, 0);
    expect(app.bottom, lessThanOrEqualTo(strip.top));
    expect(app.width, 412);
    final paper = tester.getRect(
      find
          .ancestor(
            of: find.text(PerfWords.noTap),
            matching: find.byType(RepaintBoundary),
          )
          .first,
    );
    expect(paper.left, 0);
    expect(paper.right, 412);
    expect(paper.bottom, 915);
    expect(strip.bottom, lessThanOrEqualTo(915 - 24), reason: 'above the bar');
    // The bar is the strip's: the app is told of none.
    expect(find.text('0.0'), findsOneWidget);
  });

  testWidgets('tapped, it opens the report with its copies; the scrim closes '
      'it', (tester) async {
    await _pump(tester);
    await pressLikeAFinger(tester, find.text(PerfWords.noTap));
    await tester.pumpAndSettle();
    expect(find.text(PerfWords.copyReport), findsOneWidget);
    expect(find.text(PerfWords.copyAll), findsOneWidget);
    expect(find.text(PerfWords.clear), findsOneWidget);
    await pressAtLikeAFinger(tester, const Offset(206, 20));
    await tester.pumpAndSettle();
    expect(find.text(PerfWords.copyReport), findsNothing);
  });

  test('off, the app is drawn as it is', () {
    const app = SizedBox();
    expect(perfStripAround(app), same(app));
  });
}
