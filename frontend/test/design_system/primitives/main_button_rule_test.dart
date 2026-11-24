// Guard file: a change here needs its line in the pull request (tool/guard_edits.py).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/layout/space.dart';
import 'package:midnight_village/design_system/primitives/nudge.dart';
import 'package:midnight_village/design_system/primitives/primary_button.dart';
import 'package:midnight_village/design_system/primitives/secondary_button.dart';

import '../../helpers/finger.dart';
import '../../helpers/pump_skinned.dart';

/// A screen's main action never sits silently disabled (the owner, 23
/// November 2026: a dimmed "Deal to 5" and no word of why). The buttons do not
/// take an `onPressed` of null (a type error), and this test is the second
/// lock: it reads every call of the two button classes in `lib/` and fails on
/// a null, or a choice that can come out null, handed to `onPressed`.
void main() {
  group('no main button is bare-disabled', () {
    final calls = RegExp(r'\b(PrimaryButton|SecondaryButton)(\.\w+)?\(');

    /// The text of the call that opens at [open] (the "(" of its arguments).
    String argumentsFrom(String source, int open) {
      var depth = 0;
      for (var i = open; i < source.length; i++) {
        final c = source[i];
        if (c == '(') depth++;
        if (c == ')' && --depth == 0) return source.substring(open + 1, i);
      }
      return source.substring(open + 1);
    }

    /// The expression given as `onPressed:` in [arguments], to the comma that
    /// ends it at the call's own level.
    String? onPressedOf(String arguments) {
      final at = RegExp(r'\bonPressed:').firstMatch(arguments);
      if (at == null) return null;
      var depth = 0;
      for (var i = at.end; i < arguments.length; i++) {
        final c = arguments[i];
        if ('([{'.contains(c)) depth++;
        if (')]}'.contains(c)) depth--;
        if (depth < 0 || (depth == 0 && c == ',')) {
          return arguments.substring(at.end, i);
        }
      }
      return arguments.substring(at.end);
    }

    final sources = [
      for (final file in Directory('lib').listSync(recursive: true))
        if (file is File &&
            file.path.endsWith('.dart') &&
            !file.path.endsWith('.g.dart') &&
            !file.path.endsWith('.freezed.dart'))
          file,
    ];

    test('lib/ is read: the scan sees buttons to check', () {
      var seen = 0;
      for (final file in sources) {
        seen += calls.allMatches(file.readAsStringSync()).length;
      }
      expect(seen, greaterThan(20));
    });

    test('no PrimaryButton or SecondaryButton is given an onPressed that is, '
        'or can be, null', () {
      final bare = <String>[];
      for (final file in sources) {
        final source = file.readAsStringSync();
        // The two classes themselves declare the fields.
        if (file.path.endsWith('primary_button.dart') ||
            file.path.endsWith('secondary_button.dart')) {
          continue;
        }
        for (final call in calls.allMatches(source)) {
          final arguments = argumentsFrom(source, call.end - 1);
          final given = onPressedOf(arguments);
          if (given != null && RegExp(r'\bnull\b').hasMatch(given)) {
            final line = '\n'
                .allMatches(source.substring(0, call.start))
                .length;
            bare.add('${file.path}:${line + 1}: onPressed:$given');
          }
        }
      }
      expect(
        bare,
        isEmpty,
        reason:
            'a main button that cannot act is PrimaryButton.locked (a tap '
            'leads to the fix), .waiting (a change on its way) or says what to '
            'do and does it (frontend/CLAUDE.md, "The app\'s rules")',
      );
    });

    test('the two classes take no nullable onPressed in a constructor', () {
      for (final name in ['primary_button', 'secondary_button']) {
        final source = File(
          'lib/design_system/primitives/$name.dart',
        ).readAsStringSync();
        expect(
          RegExp(
            r'required\s+VoidCallback\?\s+(this\.)?onPressed',
          ).hasMatch(source),
          isFalse,
          reason: '$name: onPressed is never nullable',
        );
        expect(
          RegExp(r'(?<!VoidCallback )this\.onPressed').hasMatch(source),
          isFalse,
          reason:
              '$name: every constructor takes a VoidCallback this.onPressed',
        );
      }
    });
  });

  group('the locked and waiting buttons', () {
    testWidgets('a locked SecondaryButton is drawn as live and, tapped, leads '
        'to what it lacks', (tester) async {
      var led = 0;
      await pumpSkinned(
        tester,
        SecondaryButton.locked(
          label: 'Start a table',
          onLockedTap: () => led++,
        ),
      );
      await pressLikeAFinger(tester, find.text('Start a table'));
      expect(led, 1);
      // Not dimmed: the words in the ink a live button has.
      final live = await _wordsColour(tester, 'Start a table');
      await pumpSkinned(
        tester,
        SecondaryButton(label: 'Start a table', onPressed: () {}),
      );
      expect(live, await _wordsColour(tester, 'Start a table'));
    });

    testWidgets('a waiting button says why to a screen reader and takes no '
        'tap', (tester) async {
      final semantics = tester.ensureSemantics();
      var taps = 0;
      await pumpSkinned(
        tester,
        const Column(
          children: [
            PrimaryButton.waiting(
              label: Words.forTest('Pick a name'),
              reason: 'Pick first',
            ),
            SecondaryButton.waiting(label: 'Join a table', reason: 'Working'),
          ],
        ),
      );
      await pressLikeAFinger(tester, find.text('Pick a name'));
      await pressLikeAFinger(tester, find.text('Join a table'));
      expect(taps, 0);
      expect(
        tester.getSemantics(find.byType(PrimaryButton)),
        containsSemantics(label: 'Pick a name', hint: 'Pick first'),
      );
      semantics.dispose();
    });
  });

  group('Nudge', () {
    final key = GlobalKey<NudgeState>();
    Widget field() => Nudge(
      key: key,
      child: const SizedBox(width: 100, height: 40, child: TextField()),
    );

    testWidgets('shakes sideways, then rests where it was; the field keeps '
        'its text and its place in the tree', (tester) async {
      await pumpSkinned(tester, field());
      await tester.enterText(find.byType(TextField), 'Ana');
      final rest = tester.getTopLeft(find.byType(TextField));
      key.currentState!.nudge();
      await tester.pump();
      await tester.pump(Motion.settle ~/ 12);
      expect(tester.getTopLeft(find.byType(TextField)).dx, isNot(rest.dx));
      await tester.pump(Motion.settle);
      expect(tester.getTopLeft(find.byType(TextField)), rest);
      expect(find.text('Ana'), findsOneWidget);
    });

    testWidgets('with reduced motion it does not move: it flashes in colour', (
      tester,
    ) async {
      await pumpSkinned(
        tester,
        MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: field(),
        ),
      );
      final rest = tester.getTopLeft(find.byType(TextField));
      Color? flash() =>
          (tester
                      .widget<DecoratedBox>(
                        find
                            .descendant(
                              of: find.byType(Nudge),
                              matching: find.byType(DecoratedBox),
                            )
                            .first,
                      )
                      .decoration
                  as BoxDecoration)
              .color;
      expect(flash()?.a ?? 0, 0);
      key.currentState!.nudge();
      await tester.pump();
      await tester.pump(Motion.settle ~/ 12);
      expect(tester.getTopLeft(find.byType(TextField)), rest);
      expect(flash()!.a, greaterThan(0));
      await tester.pump(Motion.settle);
      expect(flash()?.a ?? 0, 0);
    });
  });
}

/// The colour the words [text] are set in.
Future<Color?> _wordsColour(WidgetTester tester, String text) async => tester
    .widget<RichText>(
      find
          .descendant(
            of: find.byType(SecondaryButton),
            matching: find.byType(RichText),
          )
          .first,
    )
    .text
    .style
    ?.color;
