import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/night/night_board.dart';
import 'package:midnight_village/design_system/skin/dress.dart';
import 'package:midnight_village/design_system/skin/ground.dart';
import 'package:midnight_village/design_system/skin/ground_scope.dart';
import 'package:midnight_village/design_system/skin/skin_theme.dart';
import 'package:midnight_village/features/lobby/presentation/at_table_screen.dart';

import 'component_sheet.dart';
import 'pump_skinned.dart';
import 'sheet/night_pages.dart';
import 'sheet/sheet_data.dart';
import 'sheet/table_pages.dart';

// The sweeps (text scales, long names, narrow phones) must test the look
// players get. The test pages take their dress from the screen itself
// (`NightBoard.defaultDress`, `AtTableView.defaultDress`: what the live
// screens use when nothing says otherwise); a sweep that asks for another
// dress, or a page that bakes in one of its own, fails here.

Future<Dress> _dressOf(WidgetTester tester, Widget page, Type under) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: learnedOverrides(ComponentPage.action.learned),
      child: MaterialApp(
        theme: skinTheme(skinsUnderTest.values.first),
        builder: (context, child) =>
            GroundScope(ground: GroundKind.night, child: child!),
        home: page,
      ),
    ),
  );
  await tester.pump();
  return tester
      .widget<DressScope>(
        find
            .descendant(
              of: find.byType(under),
              matching: find.byType(DressScope),
            )
            .first,
      )
      .dress;
}

void main() {
  testWidgets('the night board test page is dressed as the live screen is', (
    tester,
  ) async {
    final seen = await _dressOf(
      tester,
      BoardPage(viewer: Viewer.drunk),
      NightBoard,
    );
    // Inside the board: what its children read.
    expect(seen, NightBoard.defaultDress);
  });

  testWidgets('the table test page is dressed as the live screen is', (
    tester,
  ) async {
    final seen = await _dressOf(tester, const TablePage(), AtTableView);
    expect(seen, AtTableView.defaultDress);
  });

  test('the live screens never pass a dress of their own to their view', () {
    for (final (path, call) in [
      ('lib/features/game/presentation/shell/night_screen.dart', 'NightBoard('),
      ('lib/features/lobby/presentation/at_table_screen.dart', 'AtTableView('),
    ]) {
      final source = File(path).readAsStringSync();
      final start = source.indexOf(call);
      expect(start, isNonNegative, reason: path);
      final end = source.indexOf(');', start);
      expect(
        source.substring(start, end).contains('dress:'),
        isFalse,
        reason: '$path: the view\'s own default is the one source',
      );
    }
  });

  test('no sweep renders a screen in a dress other than the screen\'s own', () {
    for (final path in [
      'test/design_system/night/board_sweep_test.dart',
      'test/design_system/skin/fit_sweep_test.dart',
    ]) {
      final source = File(path).readAsStringSync();
      expect(source.contains('Dress.'), isFalse, reason: path);
    }
  });
}
