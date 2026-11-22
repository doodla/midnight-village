import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/primitives/candle_gauge.dart';
import 'package:midnight_village/design_system/primitives/world_timer.dart';
import 'package:midnight_village/design_system/skin/ground.dart';
import 'package:midnight_village/design_system/skin/skin_id.dart';

import '../../helpers/frame_pixels.dart';
import '../../helpers/pump_skinned.dart';

// The night's candle (polish pass 2): the art's own paper candle, cut into
// the stick, the flame and the holder, whose wax burns down and whose flame
// shrinks across the window, stepping with the clock, the seconds beside it.

final _skin = SkinId.fallback.skin;

Future<void> _pump(
  WidgetTester tester,
  Widget child, {
  bool reduceMotion = false,
}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await pumpSkinned(
    tester,
    MediaQuery(
      data: MediaQueryData(
        size: const Size(390, 844),
        disableAnimations: reduceMotion,
      ),
      child: Align(alignment: Alignment.topLeft, child: child),
    ),
    ground: GroundKind.night,
  );
  // The cuts, loaded for real (the test clock never waits for I/O).
  await tester.runAsync(
    () => Future.wait([
      for (final element in find.byType(Image).evaluate())
        precacheImage((element.widget as Image).image, element),
    ]),
  );
  await tester.pump();
}

/// The top of the stick on screen, and the flame's height as drawn.
({double waxTop, double flame}) _drawn(WidgetTester tester) {
  final wax = tester.getTopLeft(find.byKey(const ValueKey(CandlePart.wax)));
  final flame = find.descendant(
    of: find.byKey(const ValueKey(CandlePart.flame)),
    matching: find.byType(Image),
  );
  return (
    waxTop: wax.dy,
    flame: tester.getBottomRight(flame).dy - tester.getTopLeft(flame).dy,
  );
}

/// How many pixels of the flame (warm orange) are drawn.
Future<int> _flamePixels(WidgetTester tester) async {
  final frame = await FramePixels.of(tester);
  return frame.all.where((p) {
    final r = FramePixels.red(p);
    final g = FramePixels.green(p);
    final b = FramePixels.blue(p);
    return r > 215 && g > 120 && g < 200 && b < 110;
  }).length;
}

void main() {
  group('the candle steps', () {
    test('the flame and the wax only ever shrink as the window runs out', () {
      var flame = double.infinity;
      var wax = double.infinity;
      for (var left = 20; left >= 0; left--) {
        final share = left / 20;
        expect(CandleGauge.flameScale(share), lessThanOrEqualTo(flame));
        expect(CandleGauge.waxScale(share), lessThanOrEqualTo(wax));
        flame = CandleGauge.flameScale(share);
        wax = CandleGauge.waxScale(share);
      }
      expect(CandleGauge.flameScale(1), 1);
      expect(CandleGauge.waxScale(1), 1);
    });

    test('it never goes out: a flame and a stub of wax at the end, and '
        'whole where the window is not known', () {
      expect(CandleGauge.flameScale(0), CandleGauge.lowFlame);
      expect(CandleGauge.waxScale(0), CandleGauge.lowWax);
      expect(CandleGauge.flameScale(0), greaterThan(0.25));
      expect(CandleGauge.flameScale(null), 1);
      expect(CandleGauge.waxScale(null), 1);
      // A share outside 0 to 1 (a clock a little off) is held in it.
      expect(CandleGauge.flameScale(-0.2), CandleGauge.lowFlame);
      expect(CandleGauge.flameScale(1.4), 1);
    });

    testWidgets('a second later the wax stands lower and the flame is '
        'smaller, in the next frame: no tween between the steps', (
      tester,
    ) async {
      final tops = <double>[];
      final flames = <double>[];
      final pixels = <int>[];
      for (final share in [1.0, 0.75, 0.5, 0.25, 0.0]) {
        await tester.pumpWidget(const SizedBox());
        await _pump(tester, CandleGauge(share: share, height: 180));
        final d = _drawn(tester);
        tops.add(d.waxTop);
        flames.add(d.flame);
        pixels.add(await _flamePixels(tester));
      }
      for (var i = 1; i < tops.length; i++) {
        expect(tops[i], greaterThan(tops[i - 1]), reason: 'wax $tops');
        expect(flames[i], lessThan(flames[i - 1]), reason: 'flame $flames');
        expect(pixels[i], lessThan(pixels[i - 1]), reason: 'lit $pixels');
      }
      // The last step is a candle still lit, with some wax left.
      expect(pixels.last, greaterThan(0));
      // A candle at a step is the candle drawn at that share, nothing in
      // between: the same share is the same picture.
      await tester.pumpWidget(const SizedBox());
      await _pump(tester, const CandleGauge(share: 0.5, height: 180));
      expect(_drawn(tester).waxTop, tops[2]);
    });

    testWidgets(
      'the burn is steeper toward the end: the last five seconds of a '
      'window of 30 take the wax down by a fifth of the stick, a step each '
      'second that shows at the size it is drawn',
      (tester) async {
        Future<double> top(double share) async {
          await tester.pumpWidget(const SizedBox());
          await _pump(tester, CandleGauge(share: share, height: 90));
          return _drawn(tester).waxTop;
        }

        final art = _skin.art.candleCut;
        final stick = (art.stickBottom - art.stickTop) * 90 / art.view.height;
        final tops = [
          for (var left = 5; left >= 0; left--) await top(left / 30),
        ];
        expect(
          tops.last - tops.first,
          greaterThan(0.2 * stick),
          reason: 'five seconds: $tops',
        );
        for (var i = 1; i < tops.length; i++) {
          expect(
            tops[i],
            greaterThan(tops[i - 1] + 1),
            reason: 'step $i: $tops',
          );
        }
        // And the first five seconds change it far less than the last five.
        final early = await top(30 / 30);
        final fifth = await top(25 / 30);
        expect(fifth - early, lessThan((tops.last - tops.first) / 3));
      },
    );

    testWidgets('it holds still between the steps: nothing runs, so no '
        'flicker and nothing to draw a neighbour’s eye', (tester) async {
      await _pump(tester, const CandleGauge(share: 0.6, height: 180));
      expect(tester.hasRunningAnimations, isFalse);
      final before = _drawn(tester);
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 333));
      expect(tester.hasRunningAnimations, isFalse);
      expect(_drawn(tester), before);
    });

    testWidgets('reduce motion changes nothing: it steps the same way', (
      tester,
    ) async {
      await _pump(
        tester,
        const CandleGauge(share: 0.8, height: 180),
        reduceMotion: true,
      );
      final first = _drawn(tester);
      await tester.pumpWidget(const SizedBox());
      await _pump(
        tester,
        const CandleGauge(share: 0.4, height: 180),
        reduceMotion: true,
      );
      expect(_drawn(tester).waxTop, greaterThan(first.waxTop));
    });

    testWidgets('the burnt-down wax stays inside its holder: its top never '
        'passes the dish, at every share', (tester) async {
      for (final share in [1.0, 0.5, 0.0]) {
        await tester.pumpWidget(const SizedBox());
        await _pump(tester, CandleGauge(share: share, height: 180));
        final dish = tester.getTopLeft(
          find.byKey(const ValueKey(CandlePart.holder)),
        );
        final art = _skin.art.candleCut;
        final scale = 180 / art.view.height;
        final stickBottom =
            dish.dy - (art.holder.at.dy - art.stickBottom) * scale;
        expect(
          _drawn(tester).waxTop,
          lessThan(stickBottom),
          reason: 'share $share',
        );
      }
    });
  });

  group('with the seconds', () {
    testWidgets('the number stays beside the candle, whatever the share: '
        'the candle is never the only carrier of the time', (tester) async {
      for (final share in [1.0, 0.5, 0.0, null]) {
        await tester.pumpWidget(const SizedBox());
        await _pump(
          tester,
          WorldTimer.candleCompact(secondsLeft: 9, share: share),
        );
        expect(find.text('9 s'), findsOneWidget, reason: '$share');
        expect(find.byType(CandleGauge), findsOneWidget);
        // The picture says nothing to a screen reader: the number does.
        expect(
          tester.getSemantics(find.byType(WorldTimer)).label,
          '9 s',
          reason: '$share',
        );
      }
    });

    testWidgets('the number is no bigger than it was in the thumbnail’s '
        'unit, and nothing shifts as the digits change', (tester) async {
      final sizes = <double>[];
      final candleLefts = <double>[];
      for (final seconds in [30, 14, 9, 1, 0]) {
        await tester.pumpWidget(const SizedBox());
        await _pump(
          tester,
          WorldTimer.candleCompact(
            secondsLeft: seconds,
            share: seconds / 30,
            candleHeight: 90,
            lineHeight: 36,
          ),
        );
        sizes.add(
          tester
              .widget<Text>(find.text(WorldTimer.format(seconds)))
              .style!
              .fontSize!,
        );
        candleLefts.add(tester.getTopLeft(find.byType(CandleGauge)).dx);
      }
      // The old unit drew the number at 34 x 46 / 58 = 27 px.
      expect(sizes.toSet(), {
        _skin.typography.timerCompact.fontSize! * WorldTimer.cornerNumberScale,
      });
      expect(sizes.first, lessThanOrEqualTo(27.5));
      expect(candleLefts.toSet(), hasLength(1), reason: '$candleLefts');
    });

    testWidgets('the number sits level with the title’s first line and the '
        'candle stands from the unit’s top', (tester) async {
      await _pump(
        tester,
        const WorldTimer.candleCompact(
          secondsLeft: 14,
          share: 0.6,
          candleHeight: 100,
          lineHeight: 36,
          lift: 14,
        ),
      );
      final unit = tester.getTopLeft(find.byType(WorldTimer));
      expect(tester.getTopLeft(find.byType(CandleGauge)).dy, unit.dy);
      final number = tester.getRect(find.text('14 s'));
      // Inside the first line's box, 14 px under the unit's top.
      expect(number.top, greaterThanOrEqualTo(unit.dy + 14));
      expect(number.bottom, lessThanOrEqualTo(unit.dy + 14 + 36 + 0.5));
    });

    testWidgets('the number stands to the left of the candle with a clear gap '
        '(at least the width of its "s") from the wax, the dish and the '
        'flame, full candle or stub, at every form of the clock', (
      tester,
    ) async {
      for (final (seconds, share) in const [
        (30, 1.0),
        (14, 0.47),
        (188, 1.0),
        (0, 0.0),
        (600, 1.0),
      ]) {
        await tester.pumpWidget(const SizedBox());
        await _pump(
          tester,
          WorldTimer.candleCompact(
            secondsLeft: seconds,
            share: share,
            candleHeight: 88,
            lineHeight: 36,
            lift: 6,
          ),
        );
        final number = tester.getRect(find.text(WorldTimer.format(seconds)));
        final candle = tester.getRect(find.byType(CandleGauge));
        final s = TextPainter(
          text: TextSpan(
            text: 's',
            style: _skin.typography.timerCompact.copyWith(
              fontSize:
                  _skin.typography.timerCompact.fontSize! *
                  WorldTimer.cornerNumberScale,
            ),
          ),
          textDirection: TextDirection.ltr,
        )..layout();
        // Where the picture's own paper starts: the dish, the widest part.
        final art = _skin.art.candleCut;
        final scale = 88 / art.view.height;
        final dish = candle.left + (art.holder.at.dx - art.view.left) * scale;
        expect(
          dish - number.right,
          greaterThanOrEqualTo(s.width - 0.5),
          reason: '${WorldTimer.format(seconds)}: the gap to the dish',
        );
        final wax = tester.getRect(find.byKey(const ValueKey(CandlePart.wax)));
        expect(wax.left - number.right, greaterThanOrEqualTo(s.width));
        expect(
          number.right,
          lessThanOrEqualTo(candle.left),
          reason: 'the number never lies over the candle',
        );
      }
    });

    testWidgets('a candle with no known window is whole, with no number '
        'made up', (tester) async {
      await _pump(
        tester,
        const WorldTimer.candleCompact(secondsLeft: null, share: null),
      );
      expect(find.byType(Text), findsNothing);
      expect(find.byType(CandleGauge), findsOneWidget);
    });
  });
}
