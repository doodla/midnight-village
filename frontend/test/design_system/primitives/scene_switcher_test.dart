import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/layout/space.dart';
import 'package:midnight_village/design_system/primitives/scene_switcher.dart';
import 'package:midnight_village/design_system/skin/ground.dart';
import 'package:midnight_village/design_system/skin/ground_scope.dart';
import 'package:midnight_village/design_system/skin/skin_id.dart';
import 'package:midnight_village/design_system/skin/skin_theme.dart';

/// A screen with one button where every screen has it; [taps] counts them.
class _Screen extends StatelessWidget {
  const _Screen(this.name, this.taps);

  final String name;
  final Map<String, int> taps;

  @override
  Widget build(BuildContext context) => Material(
    child: Align(
      alignment: Alignment.bottomCenter,
      child: TextButton(
        key: Key('button-$name'),
        onPressed: () => taps.update(name, (n) => n + 1, ifAbsent: () => 1),
        child: Text('Tap $name'),
      ),
    ),
  );
}

SceneKind? _between(String from, String to) => switch ((from, to)) {
  ('table', 'night') => SceneKind.dusk,
  ('night', 'talk') => SceneKind.dawn,
  _ => null,
};

Widget _app(String stage, Map<String, int> taps, {bool still = false}) =>
    MaterialApp(
      theme: skinTheme(SkinId.fallback.skin),
      builder: (context, app) => MediaQuery(
        data: MediaQuery.of(context).copyWith(disableAnimations: still),
        child: GroundScope(ground: GroundKind.night, child: app!),
      ),
      home: SceneSwitcher<String>(
        stage: stage,
        sceneBetween: _between,
        child: _Screen(stage, taps),
      ),
    );

/// The paper edge of the sinking screen: there while a scene runs.
Finder get _edge => find.byKey(const ValueKey('scene'));

void main() {
  const scene = Motion.scene;
  const ms = Duration(milliseconds: 1);

  Future<void> change(
    WidgetTester tester,
    String from,
    String to,
    Map<String, int> taps, {
    bool still = false,
  }) async {
    await tester.pumpWidget(_app(from, taps, still: still));
    await tester.pumpWidget(_app(to, taps, still: still));
  }

  group('the dusk and the dawn run and finish', () {
    for (final (from, to) in [('table', 'night'), ('night', 'talk')]) {
      testWidgets('$from to $to takes Motion.scene, then only $to is left', (
        tester,
      ) async {
        await change(tester, from, to, {});
        await tester.pump();
        expect(find.byKey(Key('button-$from')), findsOneWidget);
        expect(find.byKey(Key('button-$to')), findsOneWidget);
        await tester.pump(scene - ms * 2);
        expect(
          find.byKey(Key('button-$from')),
          findsOneWidget,
          reason: 'still going, not a ${Motion.settle.inMilliseconds} ms fade',
        );
        await tester.pump(ms * 3);
        await tester.pump();
        expect(find.byKey(Key('button-$from')), findsNothing);
        expect(find.byKey(Key('button-$to')), findsOneWidget);
        expect(tester.hasRunningAnimations, isFalse);
      });
    }

    testWidgets('the paper edge goes with the scene', (tester) async {
      await change(tester, 'table', 'night', {});
      await tester.pump();
      expect(_edge, findsOneWidget);
      await tester.pump(scene + ms * 3);
      await tester.pump();
      expect(_edge, findsNothing);
    });

    for (final (from, to) in [('table', 'night'), ('night', 'talk')]) {
      testWidgets('$from to $to: no screen is ever seen through another', (
        tester,
      ) async {
        await change(tester, from, to, {});
        await tester.pump();
        for (var at = 0; at <= scene.inMilliseconds; at += 25) {
          for (final name in [from, to]) {
            final fade = tester.widget<FadeTransition>(
              find
                  .ancestor(
                    of: find.byKey(Key('button-$name')),
                    matching: find.byType(FadeTransition),
                  )
                  .first,
            );
            expect(fade.opacity.value, 1.0, reason: '$name at $at ms');
          }
          await tester.pump(ms * 25);
        }
      });

      testWidgets('$from to $to: the leaving screen sinks off the arriving '
          'one, which stays in place', (tester) async {
        await change(tester, from, to, {});
        await tester.pump();
        final leavingTop = <double>[];
        for (var at = 0; at < scene.inMilliseconds * 0.8; at += 50) {
          leavingTop.add(tester.getTopLeft(find.byKey(Key('button-$from'))).dy);
          await tester.pump(ms * 50);
        }
        expect(
          leavingTop,
          orderedEquals([...leavingTop]..sort()),
          reason: 'only ever down',
        );
        expect(leavingTop.last, greaterThan(leavingTop.first + 100));
        await tester.pump(scene);
      });
    }

    testWidgets('the arriving screen keeps its state from the first frame '
        'to the last', (tester) async {
      final taps = <String, int>{};
      await change(tester, 'night', 'talk', taps);
      await tester.pump();
      final button = find.byKey(const Key('button-talk'));
      final before = tester.state<State>(button);
      await tester.pump(scene + ms * 3);
      await tester.pump();
      expect(tester.state<State>(button), same(before));
    });
  });

  group('a tap in the scene lands on the arriving screen at once', () {
    for (final (from, to) in [('table', 'night'), ('night', 'talk')]) {
      for (final at in [0, 60, 250, 480]) {
        testWidgets('$from to $to, $at ms in', (tester) async {
          final taps = <String, int>{};
          await tester.pumpWidget(_app(from, taps));
          final rest = tester.getCenter(find.byKey(Key('button-$from')));
          await tester.pumpWidget(_app(to, taps));
          await tester.pump();
          if (at > 0) await tester.pump(ms * at);
          expect(find.byKey(Key('button-$from')), findsOneWidget);
          await tester.tapAt(rest);
          await tester.pump();
          expect(taps[to], 1, reason: 'the new screen took the tap');
          expect(taps[from], isNull, reason: 'the old one is for the eyes');
          await tester.pump(scene);
        });
      }
    }
  });

  group('with reduce motion the change is a cut', () {
    for (final (from, to) in [('table', 'night'), ('night', 'talk')]) {
      testWidgets('$from to $to: the first frame is the new screen alone', (
        tester,
      ) async {
        await change(tester, from, to, {}, still: true);
        expect(find.byKey(Key('button-$from')), findsNothing);
        expect(find.byKey(Key('button-$to')), findsOneWidget);
        expect(_edge, findsNothing);
        expect(tester.hasRunningAnimations, isFalse);
      });
    }
  });

  group('every other change is a crossfade of Motion.settle', () {
    for (final (from, to) in [
      ('night', 'night2'),
      ('talk', 'vote'),
      ('vote', 'count'),
      ('night', 'table'),
      ('talk', 'night'),
    ]) {
      testWidgets('$from to $to', (tester) async {
        final taps = <String, int>{};
        await change(tester, from, to, taps);
        await tester.pump();
        expect(find.byKey(Key('button-$from')), findsOneWidget);
        expect(_edge, findsNothing, reason: 'no paper edge');
        await tester.pump(Motion.settle - ms * 2);
        expect(find.byKey(Key('button-$from')), findsOneWidget);
        await tester.pump(ms * 3);
        await tester.pump();
        expect(find.byKey(Key('button-$from')), findsNothing);
        expect(find.byKey(Key('button-$to')), findsOneWidget);
        // And a tap in it lands on the new screen too.
        await tester.tap(find.byKey(Key('button-$to')));
        expect(taps[to], 1);
      });
    }
  });

  testWidgets('a change while a scene runs swaps the arriving screen in '
      'place and lets the scene finish', (tester) async {
    final taps = <String, int>{};
    await change(tester, 'table', 'night', taps);
    await tester.pump();
    await tester.pump(ms * 100);
    await tester.pumpWidget(_app('night-card', taps));
    await tester.pump();
    expect(find.byKey(const Key('button-night')), findsNothing);
    expect(find.byKey(const Key('button-night-card')), findsOneWidget);
    expect(find.byKey(const Key('button-table')), findsOneWidget);
    await tester.pump(scene - ms * 150);
    expect(find.byKey(const Key('button-table')), findsOneWidget);
    await tester.pump(ms * 200);
    await tester.pump();
    expect(find.byKey(const Key('button-table')), findsNothing);
    expect(find.byKey(const Key('button-night-card')), findsOneWidget);
  });
}
