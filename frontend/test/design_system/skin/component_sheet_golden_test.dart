import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/primitives/mood.dart';
import 'package:midnight_village/design_system/skin/ground.dart';
import 'package:midnight_village/design_system/skin/skin_id.dart';

import '../../helpers/component_sheet.dart';

// A few pages of the component sheet (test/helpers/component_sheet.dart) in
// each skin, pinned. Regenerate with `just flutter-golden-update` on Linux.

const _pages = [
  (ComponentPage.buttons, GroundKind.night),
  (ComponentPage.players, GroundKind.day),
  (ComponentPage.action, GroundKind.night),
  (ComponentPage.vote, GroundKind.day),
];

/// Asset images load on real I/O, which the test clock never waits for.
Future<void> _loadImages(WidgetTester tester) async {
  await tester.runAsync(
    () => Future.wait([
      for (final element in find.byType(Image).evaluate())
        precacheImage((element.widget as Image).image, element),
    ]),
  );
  await tester.pump();
  // The screen's mood is composed once its village layers are decoded, which
  // is real I/O of a speed that differs between machines: a picture taken
  // before it is ready shows the bare ground (CI saw exactly that). Wait for it.
  if (find.byType(Mood).evaluate().isNotEmpty) {
    for (var i = 0; i < 500 && Mood.cachedPictures == 0; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 10)),
      );
      await tester.pump();
    }
    expect(Mood.cachedPictures, greaterThan(0), reason: 'mood never composed');
  }
}

void main() {
  for (final skin in SkinId.values) {
    for (final (page, ground) in _pages) {
      testWidgets('${skin.label}: ${page.name} on ${ground.name}', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);

        Mood.forget();
        await pumpComponentPage(tester, page, ground, skin: skin.skin);
        await _loadImages(tester);

        await expectLater(
          find.byType(MaterialApp),
          matchesGoldenFile(
            'goldens/skin_${skin.name}_${page.name}_${ground.name}.png',
          ),
        );
      }, tags: ['golden']);
    }
  }
}
