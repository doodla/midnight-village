import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/copy/copy.dart';
import 'package:midnight_village/design_system/primitives/primary_button.dart';
import 'package:midnight_village/design_system/primitives/secondary_button.dart';
import 'package:midnight_village/design_system/skin/dress.dart';
import 'package:midnight_village/features/lobby/presentation/join_screen.dart';

import '../../../../test_screens/table_fixtures.dart';
import '../../../helpers/finger.dart';

// 01 has exactly one amber plaque at any moment (the coordinator's rule, 24
// November 2026): "Join" once the code field holds a whole code (typed,
// scanned, or the link's), else "Start a table". The other way in is a bone
// scrap, or beside a code not yet whole the kit's locked form saying "Code".
// The two keep their places when the plaque moves: only the paper changes.

/// The acting amber plaques on screen, by label.
List<String> _plaques(WidgetTester tester) => [
  for (final e in find.byType(PrimaryButton).evaluate())
    if ((e.widget as PrimaryButton).phase == ButtonPhase.ready)
      (e.widget as PrimaryButton).label,
];

/// The button (of either kind) whose words are [label].
Finder _button(String label) => find.ancestor(
  of: find.text(label),
  matching: find.byWidgetPredicate(
    (w) => w is PrimaryButton || w is SecondaryButton,
  ),
);

/// Long enough for a piece's lift and turn to settle.
const _settled = Duration(seconds: 1);

void main() {
  group('which way in is the plaque', () {
    test('Join only with a whole code or a link', () {
      for (final (link, open, code, want) in [
        (null, false, '', JoinPlaque.start),
        (null, true, '', JoinPlaque.start),
        (null, true, 'V9Y', JoinPlaque.start),
        (null, true, 'V9YC2J', JoinPlaque.join),
        // A code kept from before, with the field closed: not in view.
        (null, false, 'V9YC2J', JoinPlaque.start),
        ('V9YC2J', false, '', JoinPlaque.join),
      ]) {
        expect(
          JoinView.plaqueOf(link: link, codeOpen: open, code: code),
          want,
          reason: 'link $link, open $open, code "$code"',
        );
      }
    });

    test('01 is dressed in paper', () {
      expect(JoinView.defaultDress, Dress.paper);
    });
  });

  testWidgets('a new phone, no name: Start a table is the one plaque, and a '
      'press leads to the name instead of starting', (tester) async {
    await pumpJoinFresh(tester);
    expect(_plaques(tester), [JoinCopy.startTable]);
    expect(tester.widget(_button(JoinCopy.joinTable)), isA<SecondaryButton>());
    await pressLikeAFinger(tester, find.text(JoinCopy.startTable));
    await tester.pump();
    final name = tester.widget<EditableText>(find.byType(EditableText).first);
    expect(name.focusNode.hasFocus, isTrue);
  });

  testWidgets('the code typed moves the plaque to Join and back, the two '
      'ways in keeping their places', (tester) async {
    await pumpJoinCodeOpen(tester);
    await tester.pump(_settled);
    expect(_plaques(tester), [JoinCopy.startTable]);
    // Join waits in the kit's locked form, saying what it needs.
    final locked = tester.widget<PrimaryButton>(_button(JoinCopy.codeHint));
    expect(locked.phase, ButtonPhase.locked);
    final joinAt = tester.getCenter(_button(JoinCopy.codeHint));
    final startAt = tester.getCenter(_button(JoinCopy.startTable)).dy;

    await tester.enterText(find.byType(TextField).last, 'V9YC2J');
    await tester.pump();
    expect(_plaques(tester), [JoinCopy.join]);
    expect(tester.widget(_button(JoinCopy.startTable)), isA<SecondaryButton>());
    expect(tester.getCenter(_button(JoinCopy.join)), joinAt);
    expect(tester.getCenter(_button(JoinCopy.startTable)).dy, startAt);

    // One character taken back: Start a table is the plaque again.
    await tester.enterText(find.byType(TextField).last, 'V9YC2');
    await tester.pump(_settled);
    expect(_plaques(tester), [JoinCopy.startTable]);
    expect(tester.getCenter(_button(JoinCopy.startTable)).dy, startAt);
  });

  testWidgets('a whole code and the name taken back: Join stays the plaque '
      'and a press leads to the name', (tester) async {
    await pumpJoinCode(tester);
    await tester.enterText(find.byType(TextField).first, '');
    await tester.pump();
    expect(_plaques(tester), [JoinCopy.join]);
    await pressLikeAFinger(tester, find.text(JoinCopy.join));
    await tester.pump();
    final name = tester.widget<EditableText>(find.byType(EditableText).first);
    expect(name.focusNode.hasFocus, isTrue);
  });

  for (final (name, pump) in [
    ('no name', pumpJoinLink),
    ('a name typed', pumpJoinLinkNamed),
  ]) {
    testWidgets('from a table\'s link, $name: Join is the one plaque', (
      tester,
    ) async {
      await pump(tester);
      expect(_plaques(tester), [JoinCopy.join]);
    });
  }
}
