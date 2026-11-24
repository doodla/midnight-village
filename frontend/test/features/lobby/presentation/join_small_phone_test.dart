import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/copy/copy.dart';

import '../../../../test_screens/table_fixtures.dart';
import '../../../helpers/table_setup.dart';

// 01 on a small phone (360 x 640): the picture is decoration and gives way
// first, so the way in is on the first screen, whatever the line above the
// buttons says; at large text and with the keyboard up the page scrolls to the
// rest, the field being typed in staying above the keyboard.

const _phone = Size(360, 640);
const _keyboard = 336.0;

void _phoneOf(WidgetTester tester, {double text = 1}) {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = _phone;
  tester.platformDispatcher.textScaleFactorTestValue = text;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
}

Rect _of(WidgetTester tester, String label) =>
    tester.getRect(find.text(label).first);

/// Nothing scrolled: what is on screen is the page as it opens.
double _scrolled(WidgetTester tester) => tester
    .state<ScrollableState>(find.byType(Scrollable).first)
    .position
    .pixels;

void main() {
  const screen = Rect.fromLTWH(0, 0, 360, 640);

  for (final (name, pump) in [
    ('a table closed (a refusal line)', pumpJoinClosed),
    ('a table not sent (the line and its Try again)', pumpStartNotSent),
    ('a fresh phone', pumpJoinFresh),
  ]) {
    testWidgets('$name: Join a table and Start a table are on the first '
        'screen at 360 x 640, text x1', (tester) async {
      _phoneOf(tester);
      await pump(tester);
      expect(_scrolled(tester), 0);
      for (final label in [JoinCopy.joinTable, JoinCopy.startTable]) {
        expect(
          screen.contains(_of(tester, label).topLeft) &&
              screen.contains(_of(tester, label).bottomRight),
          isTrue,
          reason: '"$label" at ${_of(tester, label)}',
        );
      }
    });
  }

  testWidgets('at text x1.6 the way in still fits the first screen at '
      '360 x 640, the numbers under it', (tester) async {
    _phoneOf(tester, text: 1.6);
    await pumpJoinClosed(tester);
    expect(_of(tester, JoinCopy.startTable).bottom, lessThan(640));
    expect(
      _of(tester, JoinCopy.startTable).bottom,
      lessThan(_of(tester, JoinCopy.online.fill({'n': 23})).top),
    );
  });

  for (final text in [1.0, 1.6]) {
    testWidgets('with the keyboard up (text x$text) the name field and '
        '"Join a table" stay above it, the numbers a scroll away', (
      tester,
    ) async {
      _phoneOf(tester, text: text);
      await TableSetup.pump(tester, androidWeb: true, keyboard: _keyboard);
      final above = _phone.height - _keyboard;
      expect(
        tester.getRect(find.byType(TextField).first).bottom,
        lessThan(above),
      );
      expect(_of(tester, JoinCopy.joinTable).bottom, lessThan(above));
      // The numbers are in the page, below the form, not pinned over it.
      final online = _of(tester, JoinCopy.online.fill({'n': 23}));
      expect(online.top, greaterThan(_of(tester, JoinCopy.startTable).bottom));
    });
  }
}
