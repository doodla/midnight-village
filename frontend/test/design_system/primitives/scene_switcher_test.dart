import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/layout/space.dart';
import 'package:midnight_village/design_system/primitives/scene_arrival.dart';
import 'package:midnight_village/design_system/primitives/scene_switcher.dart';
import 'package:midnight_village/design_system/skin/ground.dart';
import 'package:midnight_village/design_system/skin/ground_scope.dart';
import 'package:midnight_village/design_system/skin/skin_id.dart';
import 'package:midnight_village/design_system/skin/skin_theme.dart';

import '../../helpers/frame_pixels.dart';

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
  ('night', 'talk') || ('wait', 'talk') => SceneKind.dawn,
  _ => null,
};

Widget _app(
  String stage,
  Map<String, int> taps, {
  bool still = false,
  Widget Function(String stage)? build,
}) => MaterialApp(
  debugShowCheckedModeBanner: false,
  theme: skinTheme(SkinId.fallback.skin),
  builder: (context, app) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: still),
    child: GroundScope(ground: GroundKind.night, child: app!),
  ),
  home: SceneSwitcher<String>(
    stage: stage,
    sceneBetween: _between,
    child: build?.call(stage) ?? _Screen(stage, taps),
  ),
);

/// The paper edge of the moving sheet: there while a scene runs.
Finder get _edge => find.byKey(const ValueKey('scene'));

/// A screen that is one flat colour, to read the frame's pixels.
const _flat = {
  'table': Color(0xFFFF0000),
  'wait': Color(0xFF00FF00),
  'night': Color(0xFF0000FF),
  'talk': Color(0xFFFF0000),
};

Widget _flatScreen(String stage) => ColoredBox(color: _flat[stage]!);

/// What the arriving screen of a scene is told, in the order of its frames.
class _Watcher extends StatelessWidget {
  const _Watcher(this.name, this.seen);

  final String name;
  final List<(String, double?)> seen;

  @override
  Widget build(BuildContext context) {
    final arrival = SceneArrival.maybeOf(context);
    if (arrival == null) {
      seen.add((name, null));
      return const SizedBox.expand();
    }
    return AnimatedBuilder(
      animation: arrival,
      builder: (context, _) {
        seen.add((name, arrival.value));
        return const SizedBox.expand();
      },
    );
  }
}

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

  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(200, 400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
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

    for (final (from, to) in [('table', 'night'), ('night', 'talk')]) {
      testWidgets('$from to $to: no fade is ever laid over a screen', (
        tester,
      ) async {
        await change(tester, from, to, {});
        await tester.pump();
        for (var at = 0; at <= scene.inMilliseconds; at += 25) {
          for (final fade in tester.widgetList<FadeTransition>(
            find.byType(FadeTransition),
          )) {
            final laidOver = find.descendant(
              of: find.byWidget(fade),
              matching: find.byType(TextButton),
            );
            if (laidOver.evaluate().isEmpty) continue;
            expect(fade.opacity.value, 1.0, reason: 'a screen at $at ms');
          }
          await tester.pump(ms * 25);
        }
      });

      testWidgets('$from to $to: no frame shows one screen through the '
          'other', (tester) async {
        phone(tester);
        await tester.pumpWidget(_app(from, {}, build: _flatScreen));
        await tester.pumpWidget(_app(to, {}, build: _flatScreen));
        await tester.pump();
        for (var at = 0; at <= scene.inMilliseconds; at += 20) {
          final frame = await FramePixels.of(tester);
          // The paper edge (tan: the one thing here with any green in it) and
          // the rows its soft ends touch are not a screen seen through
          // another.
          final edgeRows = {
            for (final (_, y, p) in frame.cells)
              if (FramePixels.green(p) > 20) ...[y - 2, y - 1, y, y + 1, y + 2],
          };
          final mixed = [
            for (final (_, y, p) in frame.cells)
              if (!edgeRows.contains(y) &&
                  FramePixels.red(p) > 40 &&
                  FramePixels.blue(p) > 40)
                p,
          ];
          expect(mixed, isEmpty, reason: 'a blend of the two at $at ms');
          expect(frame.unpainted, 0, reason: 'a gap at $at ms');
          await tester.pump(ms * 20);
        }
      });

      testWidgets('$from to $to: the screens move one way only', (
        tester,
      ) async {
        await change(tester, from, to, {});
        await tester.pump();
        final fromTop = <double>[];
        final toTop = <double>[];
        for (var at = 0; at <= scene.inMilliseconds; at += 50) {
          fromTop.add(tester.getTopLeft(find.byKey(Key('button-$from'))).dy);
          toTop.add(tester.getTopLeft(find.byKey(Key('button-$to'))).dy);
          await tester.pump(ms * 50);
        }
        List<double> sorted(List<double> l) => [...l]..sort();
        if (from == 'table') {
          // The dusk: the arriving sheet comes down, onto where it rests; the
          // table under it barely moves.
          expect(toTop, orderedEquals(sorted(toTop)), reason: 'only down');
          expect(toTop.last - toTop.first, greaterThan(300));
          expect(fromTop.last - fromTop.first, lessThan(40));
        } else {
          // The dawn: the night sinks; the day stays where it is.
          expect(fromTop, orderedEquals(sorted(fromTop)), reason: 'only down');
          expect(fromTop.last - fromTop.first, greaterThan(100));
          expect(toTop.toSet(), hasLength(1), reason: 'the day does not move');
        }
        await tester.pump(scene);
      });
    }

    testWidgets('only the arriving screen is told how far the scene has '
        'brought it', (tester) async {
      final seen = <(String, double?)>[];
      Widget watched(String stage) => _Watcher(stage, seen);
      await tester.pumpWidget(_app('table', {}, build: watched));
      await tester.pumpWidget(_app('night', {}, build: watched));
      await tester.pump();
      await tester.pump(ms * 100);
      await tester.pump(ms * 350);
      final arriving = [
        for (final (name, progress) in seen)
          if (name == 'night' && progress != null) progress,
      ];
      expect(arriving, isNotEmpty);
      expect(arriving.first, lessThan(0.1));
      expect(arriving.last, 1.0, reason: 'landed before the scene is over');
      expect(
        arriving,
        orderedEquals([...arriving]..sort()),
        reason: 'only towards landed',
      );
      await tester.pump(scene);
      await tester.pump();
      expect(seen.last, ('night', null), reason: 'told nothing at rest');
      expect(
        seen.where((s) => s.$1 == 'table' && s.$2 != null),
        isEmpty,
        reason: 'the leaving screen is told nothing',
      );
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

    testWidgets('the new screen fades in over the old, which stays whole', (
      tester,
    ) async {
      phone(tester);
      await tester.pumpWidget(_app('talk', {}, build: _flatScreen));
      await tester.pumpWidget(_app('night', {}, build: _flatScreen));
      await tester.pump();
      await tester.pump(Motion.settle ~/ 2);
      final mid = (await FramePixels.of(tester)).at(100, 200);
      // Blue fading in over red, which stays whole under it: the two share
      // the pixel exactly (a fade of both would leave the ground showing).
      expect(FramePixels.blue(mid), inInclusiveRange(1, 254));
      expect(
        FramePixels.red(mid) + FramePixels.blue(mid),
        inInclusiveRange(254, 256),
      );
    });
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

  testWidgets('a scene that cuts a crossfade short takes both of its screens '
      'in the sheet: nothing pops, and they go on fading inside it', (
    tester,
  ) async {
    phone(tester);
    // blue (night) fades to green (wait); 100 ms in, the dawn (red) begins.
    await tester.pumpWidget(_app('night', {}, build: _flatScreen));
    await tester.pumpWidget(_app('wait', {}, build: _flatScreen));
    await tester.pump();
    await tester.pump(ms * 100);
    final before = (await FramePixels.of(tester)).at(100, 380);
    await tester.pumpWidget(_app('talk', {}, build: _flatScreen));
    await tester.pump();
    final after = (await FramePixels.of(tester)).at(100, 380);
    expect(after, before, reason: 'the same mix of the two, not a cut');
    // The fade goes on inside the sheet: 200 ms on (the crossfade is long
    // over) the lower part of the screen, still the sheet, is all green.
    await tester.pump(ms * 200);
    final later = await FramePixels.of(tester);
    expect(FramePixels.green(later.at(100, 395)), 255);
    expect(FramePixels.red(later.at(100, 395)), 0);
    await tester.pump(scene);
  });
}
