import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/primitives/candle_gauge.dart';
import 'package:midnight_village/design_system/primitives/world_timer.dart';
import 'package:midnight_village/design_system/skin/ground.dart';
import 'package:midnight_village/design_system/skin/skin_id.dart';

import '../../helpers/frame_pixels.dart';
import '../../helpers/pump_skinned.dart';

// The night's candle (polish pass 2): a drawn candle whose flame and wax
// shrink across the window, stepping with the clock, the seconds beside it.

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
}

/// How many pixels of the candle's flame (the accent) are drawn.
Future<int> _flamePixels(WidgetTester tester) async {
  final frame = await FramePixels.of(tester);
  final amber = _skin.night.accent.toARGB32();
  return frame.all.where((p) => p == amber).length;
}

/// How many pixels of the candle's stick (bone paper) are drawn.
Future<int> _waxPixels(WidgetTester tester) async {
  final frame = await FramePixels.of(tester);
  final bone = _skin.night.paper.toARGB32();
  return frame.all.where((p) => p == bone).length;
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

    testWidgets('a second later it is drawn smaller, flame and wax, in the '
        'next frame: no tween between the steps', (tester) async {
      final flames = <int>[];
      final waxes = <int>[];
      for (final share in [1.0, 0.75, 0.5, 0.25, 0.0]) {
        await tester.pumpWidget(const SizedBox());
        await _pump(tester, CandleGauge(share: share));
        flames.add(await _flamePixels(tester));
        waxes.add(await _waxPixels(tester));
      }
      for (var i = 1; i < flames.length; i++) {
        expect(flames[i], lessThan(flames[i - 1]), reason: 'flame $flames');
        expect(waxes[i], lessThan(waxes[i - 1]), reason: 'wax $waxes');
      }
      // A candle at a step is the candle drawn at that share, nothing in
      // between: the same share is the same picture.
      await tester.pumpWidget(const SizedBox());
      await _pump(tester, const CandleGauge(share: 0.5));
      expect(await _flamePixels(tester), flames[2]);
    });

    testWidgets('it holds still between the steps: nothing runs, so no '
        'flicker and nothing to draw a neighbour’s eye', (tester) async {
      await _pump(tester, const CandleGauge(share: 0.6));
      expect(tester.hasRunningAnimations, isFalse);
      final before = await _flamePixels(tester);
      await tester.pump(const Duration(seconds: 1));
      await tester.pump(const Duration(milliseconds: 333));
      expect(tester.hasRunningAnimations, isFalse);
      expect(await _flamePixels(tester), before);
    });

    testWidgets('reduce motion changes nothing: it steps the same way', (
      tester,
    ) async {
      await _pump(tester, const CandleGauge(share: 0.8), reduceMotion: true);
      final first = await _flamePixels(tester);
      await tester.pumpWidget(const SizedBox());
      await _pump(tester, const CandleGauge(share: 0.4), reduceMotion: true);
      expect(await _flamePixels(tester), lessThan(first));
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

    testWidgets('the number is the title’s size and the candle as high as '
        'the title’s room: bigger than the thumbnail it replaces', (
      tester,
    ) async {
      await _pump(
        tester,
        const WorldTimer.candleCompact(
          secondsLeft: 14,
          share: 0.6,
          candleHeight: 66,
        ),
      );
      expect(tester.getSize(find.byType(CandleGauge)).height, 66);
      expect(
        tester.widget<Text>(find.text('14 s')).style!.fontSize,
        _skin.typography.timerCompact.fontSize,
      );
      // The old thumbnail was 44 x 58 scaled to a 46 px unit.
      expect(tester.getSize(find.byType(CandleGauge)).height, greaterThan(46));
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
