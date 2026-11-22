import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/primitives/band.dart';
import 'package:midnight_village/design_system/primitives/layered_art.dart';
import 'package:midnight_village/design_system/primitives/scene_arrival.dart';
import 'package:midnight_village/design_system/skin/art_set.dart';
import 'package:midnight_village/design_system/skin/ground.dart';
import 'package:midnight_village/design_system/skin/skin_id.dart';

import '../../helpers/pump_skinned.dart';

// 08's one sun: the paper sprite on the layered dawn, standing where the talk
// is (stepped by the clock, never tweened), under the hills, and coming up
// from behind them when the dawn brings the screen in.

final _scene = SkinId.fallback.skin.art.layeredScene(
  LayeredSceneId.dawnGallows,
);
final _arc = _scene.layers.whereType<SceneSlot>().single.arc!;

/// The images of the band, bottom to top, by file name.
List<String> _order(WidgetTester tester) => [
  for (final image in tester.widgetList<Image>(find.byType(Image)))
    (((image.image as ResizeImage).imageProvider as AssetImage).assetName)
        .split('/')
        .last
        .replaceAll('.webp', ''),
];

Finder _image(String file) => find.byWidgetPredicate(
  (w) =>
      w is Image &&
      w.image is ResizeImage &&
      ((w.image as ResizeImage).imageProvider as AssetImage).assetName.endsWith(
        '/$file.webp',
      ),
);

Widget _band(double? elapsed) => TimerBand.sun(
  secondsLeft: 200,
  elapsed: elapsed,
  title: 'The village wakes',
);

/// Where the sun's centre is, in the band, for the share of the talk.
Offset _sun(WidgetTester tester) {
  final box = tester.getRect(find.byType(LayeredArt));
  final sun = tester.getRect(_image('sun'));
  return sun.center - box.topLeft;
}

/// Where the arc puts the sun [along] of the way, in the band (by length).
Offset _onArc(WidgetTester tester, double along) {
  final box = tester.getRect(find.byType(LayeredArt));
  final geometry = SceneGeometry.cover(_scene, box.size);
  final path = Path()
    ..moveTo(geometry.point(_arc.start).dx, geometry.point(_arc.start).dy)
    ..quadraticBezierTo(
      geometry.point(_arc.control).dx,
      geometry.point(_arc.control).dy,
      geometry.point(_arc.end).dx,
      geometry.point(_arc.end).dy,
    );
  final metric = path.computeMetrics().first;
  return metric.getTangentForOffset(metric.length * along)!.position;
}

void main() {
  void phone(WidgetTester tester) {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
  }

  testWidgets('the sun stands on its path where the talk is, and every '
      'change of the clock is a jump, not a glide', (tester) async {
    phone(tester);
    final xs = <double>[];
    for (final elapsed in [0.0, 0.25, 0.5, 0.75, 1.0]) {
      await pumpSkinned(tester, _band(elapsed), ground: GroundKind.day);
      final along = _arc.rise + (_arc.set - _arc.rise) * elapsed;
      final want = _onArc(tester, along);
      expect(_sun(tester).dx, closeTo(want.dx, 0.01), reason: '$elapsed');
      expect(_sun(tester).dy, closeTo(want.dy, 0.01), reason: '$elapsed');
      xs.add(_sun(tester).dx);
    }
    expect(xs, [...xs]..sort(), reason: 'it climbs one way, left to right');

    // A tick: one pump, and it is there. Nothing is left to animate.
    await pumpSkinned(tester, _band(0.3), ground: GroundKind.day);
    final before = _sun(tester);
    await pumpSkinned(tester, _band(0.31), ground: GroundKind.day);
    final after = _sun(tester);
    expect(after.dx, greaterThan(before.dx));
    expect(tester.hasRunningAnimations, isFalse);
  });

  testWidgets('a talk with no share known has the sun at its resting place', (
    tester,
  ) async {
    phone(tester);
    await pumpSkinned(tester, _band(null), ground: GroundKind.day);
    final resting = _sun(tester);
    await pumpSkinned(
      tester,
      _band(TimerBand.restingSun),
      ground: GroundKind.day,
    );
    expect(resting, _sun(tester));
  });

  testWidgets('the sun is one paper sprite, under the hills, so the path and '
      'the sun at its ends are behind them', (tester) async {
    phone(tester);
    await pumpSkinned(tester, _band(0.3), ground: GroundKind.day);
    final order = _order(tester);
    expect(order.where((f) => f == 'sun'), hasLength(1));
    expect(order.indexOf('sun'), greaterThan(order.indexOf('sky_plate')));
    expect(order.indexOf('sun'), lessThan(order.indexOf('hills_far')));
    expect(order.indexOf('sun'), lessThan(order.indexOf('roofs_near')));
  });

  testWidgets('the dawn brings the sun up from behind the hills to the place '
      'the clock gives it', (tester) async {
    phone(tester);
    final arrival = AnimationController(vsync: tester);
    addTearDown(arrival.dispose);
    await pumpSkinned(
      tester,
      SceneArrival(progress: arrival, child: _band(0.3)),
      ground: GroundKind.day,
    );
    final from = _sun(tester);
    arrival.value = 0.5;
    await tester.pump();
    final half = _sun(tester);
    arrival.value = 1;
    await tester.pump();
    final place = _sun(tester);
    final scale = SceneGeometry.cover(
      _scene,
      tester.getRect(find.byType(LayeredArt)).size,
    ).scale;
    expect(
      from.dx,
      closeTo(place.dx, 0.01),
      reason: 'it rises, it does not slide',
    );
    expect(from.dy - place.dy, closeTo(_arc.dip * scale, 0.01));
    expect(half.dy, allOf(lessThan(from.dy), greaterThan(place.dy)));
    // Nothing is left over: at rest it is where the clock says.
    final along = _arc.rise + (_arc.set - _arc.rise) * 0.3;
    expect(place.dy, closeTo(_onArc(tester, along).dy, 0.01));
  });
}
