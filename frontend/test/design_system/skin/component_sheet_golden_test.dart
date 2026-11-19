import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/skin/ground.dart';
import 'package:midnight_village/design_system/skin/skin_id.dart';

import '../../helpers/component_sheet.dart';

// A few pages of the component sheet (test/helpers/component_sheet.dart) in
// each skin, pinned. Regenerate with `just flutter-golden-update` on Linux.

const _pages = [
  (ComponentPage.buttons, GroundKind.night),
  (ComponentPage.players, GroundKind.day),
  (ComponentPage.table, GroundKind.night),
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
