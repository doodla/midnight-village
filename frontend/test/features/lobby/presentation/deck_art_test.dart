import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/copy/copy.dart';
import 'package:midnight_village/design_system/models/role.dart';
import 'package:midnight_village/design_system/primitives/role_card.dart';
import 'package:midnight_village/design_system/skin/skin_id.dart';

import '../../../helpers/art_decoded.dart';
import '../../../helpers/table_setup.dart';

// The owner (23 November 2026, the live app): on 03, the deck set-up page, with
// no game yet, the Werewolf's tile and its card sheet showed an empty red
// frame. Every role's portrait is painted from a real file here, with the real
// asset bundle, on every page a player sees before any game.

final _lunge = SkinId.fallback.skin.art.role(RoleId.werewolf).path;

Finder _wolfCard() =>
    find.byWidgetPredicate((w) => w is RoleCard && w.role == RoleId.werewolf);

void main() {
  testWidgets('03: no game, the Werewolf\'s tile and its sheet paint the '
      'lunge, decoded, from a file the app has', (tester) async {
    final setup = await TableSetup.pump(
      tester,
      lobby: v2Lobby('created_with_defaults'),
      viewer: 'Ana',
    );
    await tester.tap(find.text(TableCopy.editDeck));
    await setup.settle(tester);
    expect(find.text(DeckCopy.headline), findsOneWidget);
    await loadPictures(tester);

    final tile = paintedPictures(tester, of: _wolfCard());
    expect(tile.map((p) => p.path), [_lunge]);
    expect(tile.single.decoded, isTrue, reason: '$tile');
    expect(File(_lunge).existsSync(), isTrue);

    // Every role's tile, not only the wolf's.
    final all = paintedPictures(tester, part: '/roles/');
    expect(all, hasLength(RoleId.values.length));
    expect(all.where((p) => !p.decoded), isEmpty, reason: '$all');

    // Held: the sheet over it.
    await tester.longPress(_wolfCard());
    await setup.settle(tester);
    await loadPictures(tester);
    final sheet = paintedPictures(tester, part: 'werewolf');
    // The tile behind the sheet and the sheet's own portrait.
    expect(sheet, hasLength(2));
    expect(sheet.map((p) => p.path).toSet(), {_lunge});
    expect(sheet.where((p) => !p.decoded), isEmpty, reason: '$sheet');
    await setup.close(tester);
  });

  testWidgets('02: the table\'s deck strip paints decoded portraits with no '
      'game', (tester) async {
    final setup = await TableSetup.pump(
      tester,
      lobby: v2Lobby('detail_auto_deck_9'),
      viewer: 'Ana',
    );
    await loadPictures(tester);
    final pictures = paintedPictures(tester, part: '/roles/');
    expect(pictures, isNotEmpty);
    expect(pictures.where((p) => !p.decoded), isEmpty, reason: '$pictures');
    await setup.close(tester);
  });
}
