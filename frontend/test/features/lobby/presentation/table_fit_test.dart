import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/copy/copy.dart';
import 'package:midnight_village/design_system/layout/space.dart';
import 'package:midnight_village/design_system/primitives/player_row.dart';
import 'package:midnight_village/design_system/primitives/primary_button.dart';
import 'package:midnight_village/design_system/primitives/qr_picture.dart';
import 'package:midnight_village/design_system/primitives/role_card.dart';

import '../../../helpers/table_setup.dart';

// 02 on a small phone: once the table is past nearly empty, the host sees
// who is here, the deck (its chip and cards face up) and Deal without
// scrolling, for six at 390 x 844 and five at 360 x 640; the QR code never
// under its scannable least. The bodies are recorded tables (a member or
// two fewer for six: the layout's case, not the deal's).

/// The lowest a thing may end and still be read: above the body's fade.
const _fade = Space.xxl;

Future<TableSetup> _pumpAt(
  WidgetTester tester,
  Size size,
  Map<String, dynamic> lobby,
  String viewer,
) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  return TableSetup.pump(tester, lobby: lobby, viewer: viewer);
}

/// Everything the host needs next ends above the Deal button's top, less
/// the fade, with nothing scrolled.
void _expectAllInView(WidgetTester tester, {required int players}) {
  final deal = tester.getRect(find.byType(PrimaryButton).last);
  final limit = deal.top - _fade;
  final rows = find.byType(PlayerRow);
  expect(rows, findsNWidgets(players));
  for (final rect in [
    for (final e in rows.evaluate()) tester.getRect(find.byWidget(e.widget)),
    for (final e in find.byType(RoleCard).evaluate())
      tester.getRect(find.byWidget(e.widget)),
  ]) {
    expect(rect.bottom, lessThanOrEqualTo(limit));
  }
  expect(find.byType(RoleCard), findsWidgets);
  final qr = tester.getSize(find.byType(QrPicture));
  expect(qr.width, greaterThanOrEqualTo(Sizes.qrScannable));
}

void main() {
  testWidgets('six at 390 x 844: the rows, the deck and Deal in view', (
    tester,
  ) async {
    final body = v2Lobby('detail_v2_deck_classic_7');
    (body['players'] as List).removeLast();
    final setup = await _pumpAt(tester, const Size(390, 844), body, 'Kai');

    _expectAllInView(tester, players: 6);
    expect(find.text(TableCopy.editDeck), findsOneWidget);
    await setup.close(tester);
  });

  testWidgets('five at 360 x 640: the rows, the deck and Deal in view', (
    tester,
  ) async {
    final setup = await _pumpAt(
      tester,
      const Size(360, 640),
      v2Lobby('detail_v2_auto_deck_5'),
      'Ana',
    );

    _expectAllInView(tester, players: 5);
    await setup.close(tester);
  });

  testWidgets('at 320 the QR code stacks over the code, still scannable', (
    tester,
  ) async {
    final setup = await _pumpAt(
      tester,
      const Size(320, 692),
      v2Lobby('detail_v2_auto_deck_5'),
      'Ana',
    );

    final qr = tester.getRect(find.byType(QrPicture));
    final code = tester.getRect(find.text('V9YC2J'));
    expect(qr.width, greaterThanOrEqualTo(Sizes.qrScannable));
    expect(code.top, greaterThanOrEqualTo(qr.bottom));
    await setup.close(tester);
  });

  testWidgets('alone: the picture, the QR code large and centred', (
    tester,
  ) async {
    final setup = await _pumpAt(
      tester,
      const Size(390, 844),
      v2Lobby('created_with_defaults'),
      'Ana',
    );

    final qr = tester.getRect(find.byType(QrPicture));
    expect(qr.width, greaterThan(Sizes.qrScannable));
    expect(qr.center.dx, closeTo(390 / 2, Space.lg));
    await setup.close(tester);
  });
}
