import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/skin/art_set.dart';
import 'package:midnight_village/features/game/domain/screen_table.dart';
import 'package:midnight_village/features/game/presentation/shell/art_ahead.dart';
import 'package:midnight_village/features/lobby/presentation/deck_screen.dart';

import '../../../../test_screens/table_fixtures.dart';

/// The pictures a pumped screen draws, as decoded.
Set<ArtDecode> _drawn(WidgetTester tester) => {
  for (final e in find.byType(Image).evaluate())
    if ((e.widget as Image).image case final ArtDecode d) d,
};

String _key(ArtDecode d) => '${d.art.path}@${d.width}';

void main() {
  test('every screen says what can come after it', () {
    for (final screen in AppScreen.values) {
      expect(ArtAhead.comesNext.containsKey(screen), isTrue, reason: '$screen');
    }
  });

  // The owner's phone (412 x 915 at 2.625) and the smallest the app is
  // drawn for (320 wide, three across or two).
  for (final (size, ratio) in [
    (const Size(412, 915), 2.625),
    (const Size(360, 640), 3.0),
    (const Size(320, 640), 2.0),
  ]) {
    testWidgets('03 opens on the portraits 02 decoded ahead, '
        '${size.width.toInt()} wide at $ratio', (tester) async {
      tester.view.devicePixelRatio = ratio;
      tester.view.physicalSize = size * ratio;
      addTearDown(tester.view.reset);
      await pumpDeckGrid(tester);
      final drawn = _drawn(tester).map(_key).toSet();
      final context = tester.element(find.byType(DeckScreen));
      final ahead = {
        for (final p in ArtAhead.artOf(context, AppScreen.deck))
          _key(p as ArtDecode),
      };
      final portraits = {
        for (final k in drawn)
          if (k.contains('/roles/')) k,
      };
      expect(portraits, isNotEmpty);
      expect(portraits.difference(ahead), isEmpty);
    });
  }
}
