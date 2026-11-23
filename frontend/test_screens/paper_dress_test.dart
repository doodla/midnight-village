// The dressed-up pass in pictures, for a look: every paper part in both
// dresses side by side (the parts page), and the table, your card and the night
// board in paper dress. Run it with `just paper-dress`; it is not part of
// `just test`. `just contact-sheet <folder>` makes one sheet.
import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/models/role.dart';
import 'package:midnight_village/design_system/primitives/chips.dart';
import 'package:midnight_village/design_system/primitives/fanned.dart';
import 'package:midnight_village/design_system/primitives/fit_line.dart';
import 'package:midnight_village/design_system/primitives/lantern_pool.dart';
import 'package:midnight_village/design_system/primitives/paper_banner.dart';
import 'package:midnight_village/design_system/primitives/paper_card.dart';
import 'package:midnight_village/design_system/primitives/paper_mark.dart';
import 'package:midnight_village/design_system/primitives/player_row.dart';
import 'package:midnight_village/design_system/primitives/primary_button.dart';
import 'package:midnight_village/design_system/primitives/role_card.dart';
import 'package:midnight_village/design_system/primitives/screen_frame.dart';
import 'package:midnight_village/design_system/primitives/secondary_button.dart';
import 'package:midnight_village/design_system/primitives/tag_chip.dart';
import 'package:midnight_village/design_system/primitives/text_backing.dart';
import 'package:midnight_village/design_system/skin/dress.dart';
import 'package:midnight_village/design_system/skin/ground.dart';
import 'package:midnight_village/design_system/skin/ground_scope.dart';
import 'package:midnight_village/design_system/skin/skin.dart';
import 'package:midnight_village/design_system/skin/skin_theme.dart';

import '../test/helpers/component_sheet.dart';
import '../test/helpers/pump_skinned.dart';
import '../test/helpers/shell_setup.dart';
import '../test/helpers/sheet/night_pages.dart';
import '../test/helpers/sheet/sheet_data.dart';
import '../test/helpers/sheet/table_pages.dart';
import 'shell_fixtures.dart';

/// Where the pictures go: `--dart-define=PAPER_DRESS_DIR=/some/folder`.
const _dir = String.fromEnvironment(
  'PAPER_DRESS_DIR',
  defaultValue: 'build/paper_dress',
);
const _ratio = 2.0;

Future<void> _save(WidgetTester tester, String name) async {
  // The test binding turns blurred shadows into solid blocks as it paints;
  // the pictures show the real ones.
  debugDisableShadows = false;
  final png = await tester.runAsync(() async {
    final image = await captureImage(tester.binding.rootElement!);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return bytes!.buffer.asUint8List();
  });
  debugDisableShadows = true;
  Directory(_dir).createSync(recursive: true);
  File('$_dir/$name.png').writeAsBytesSync(Uint8List.fromList(png!));
}

Future<void> _settle(WidgetTester tester) async {
  await tester.runAsync(
    () => Future<void>.delayed(const Duration(milliseconds: 900)),
  );
  await tester.runAsync(
    () => Future.wait([
      for (final e in find.byType(Image).evaluate())
        precacheImage((e.widget as Image).image, e),
    ]),
  );
  await tester.pump(const Duration(milliseconds: 400));
  await tester.pump();
}

void _phone(WidgetTester tester, double width, double height) {
  tester.view.physicalSize = Size(width * _ratio, height * _ratio);
  tester.view.devicePixelRatio = _ratio;
  addTearDown(tester.view.reset);
}

/// Every paper part, as a screen of its own dress would have it.
Widget _parts(Dress dress, String title) => ScreenFrame(
  ground: GroundKind.night,
  dress: dress,
  body: Builder(
    builder: (context) => Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: 14,
      children: [
        PaperBanner(
          id: #parts,
          child: (context) => FitLine(
            title,
            style: context.skin.typography.screenTitle.copyWith(
              color: context.ground.text,
            ),
          ),
        ),
        const PlayerRow(token: null, name: 'Ana', own: true),
        const PlayerRow(token: null, name: 'Bartholomew', picked: true),
        const PlayerRow(token: null, name: 'Cleo'),
        Row(
          spacing: 10,
          children: [
            const TagChip('Werewolf'),
            const TagChip.danger('Wolf team', small: true),
            PresetChip(label: 'Classic', selected: true, onTap: () {}),
            const PaperMark(size: 30),
          ],
        ),
        PaperCard(
          pinned: true,
          id: #parts,
          lift: PaperLift.slab,
          child: Text(
            'A pinned notice',
            style: TextStyle(color: context.skin.paper.text),
          ),
        ),
        Row(
          spacing: 6,
          children: [
            for (final (i, role) in [
              RoleId.seer,
              RoleId.robber,
              RoleId.werewolf,
              RoleId.drunk,
            ].indexed)
              Expanded(
                child: Fanned(
                  index: i,
                  count: 4,
                  child: RoleCard(
                    role: role,
                    size: RoleCardSize.thumbSmall,
                    count: 1,
                    onTap: () {},
                  ),
                ),
              ),
          ],
        ),
        const TextBacking(
          child: Text(
            'Words over the village keep a backing',
            style: TextStyle(color: Color(0xFFE9E2D0)),
          ),
        ),
        LanternPool(
          child: SecondaryButton(label: 'A pinned scrap', onPressed: () {}),
        ),
        PrimaryButton(label: 'The plaque', onPressed: () {}),
        const PrimaryButton.done(label: 'Ready'),
      ],
    ),
  ),
);

void main() {
  for (final dress in Dress.values) {
    testWidgets('the parts page, ${dress.name}', (tester) async {
      _phone(tester, 390, 1000);
      await pumpSkinned(tester, _parts(dress, 'Every part'));
      await _settle(tester);
      await _save(tester, 'parts-${dress.name}');
    });
  }

  for (final width in [360.0, 390.0]) {
    final w = width.round();
    testWidgets('the table, paper dress, $w wide', (tester) async {
      _phone(tester, width, 800);
      await tester.pumpWidget(
        ProviderScope(
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: skinTheme(skinsUnderTest.values.first),
            builder: (context, child) =>
                GroundScope(ground: GroundKind.night, child: child!),
            home: const TablePage(dress: Dress.paper),
          ),
        ),
      );
      await _settle(tester);
      await _save(tester, '02-table-$w');
    });

    testWidgets('the night board, paper dress, $w wide', (tester) async {
      _phone(tester, width, 800);
      await tester.pumpWidget(
        ProviderScope(
          overrides: learnedOverrides(ComponentPage.action.learned),
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            theme: skinTheme(skinsUnderTest.values.first),
            builder: (context, child) =>
                GroundScope(ground: GroundKind.night, child: child!),
            home: BoardPage(viewer: Viewer.seer, dress: Dress.paper),
          ),
        ),
      );
      await _settle(tester);
      await _save(tester, '06-night-board-$w');
    });

    testWidgets('your card, paper dress, $w wide', (tester) async {
      _phone(tester, width, 800);
      ShellSetup.pinnedDress = Dress.paper;
      addTearDown(() => ShellSetup.pinnedDress = null);
      await pumpYourCard(tester);
      await _settle(tester);
      await _save(tester, '04-your-card-$w');
    });
  }
}
