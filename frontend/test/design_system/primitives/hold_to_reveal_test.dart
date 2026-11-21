import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/faces/face_content.dart';
import 'package:midnight_village/design_system/faces/held_face.dart';
import 'package:midnight_village/design_system/models/role.dart';
import 'package:midnight_village/design_system/primitives/hold_to_reveal.dart';
import 'package:midnight_village/design_system/skin/ground.dart';
import 'package:midnight_village/design_system/skin/ground_scope.dart';
import 'package:midnight_village/design_system/skin/skin_theme.dart';

import '../../helpers/pump_skinned.dart';
import '../../helpers/sheet/sheet_data.dart';

final _seer = FaceContent.roleText(RoleId.seer);

/// The recorded Seer's My night: two pages.
final _myNight = Viewer.seer.myNight;
const _cover = 'Face down';

/// The line the Seer's face shows first.
String get _secret => _seer.pages.first.lines.first;

class _Harness {
  _Harness({FaceContent? face}) : face = face ?? _seer;

  final FaceContent face;
  final changes = <bool>[];
  var revealed = 0;

  Widget build() => MaterialApp(
    theme: skinTheme(skinsUnderTest.values.first),
    builder: (context, child) =>
        GroundScope(ground: GroundKind.night, child: child!),
    home: Scaffold(
      body: Column(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          HoldToReveal(
            target: 'Your card',
            face: face,
            onRevealChanged: changes.add,
            onRevealed: () => revealed++,
            cover: SizedBox.square(dimension: 200, child: const Text(_cover)),
          ),
          // Somewhere else for the keyboard's focus to go.
          TextButton(onPressed: () {}, child: const Text('Elsewhere')),
          const SizedBox(height: 40),
        ],
      ),
    ),
  );
}

Finder get _card => find.byType(HoldToReveal);
Finder get _face => find.byType(HeldFace);

/// The card as read out.
final _label = RegExp('^Your card');

Future<TestGesture> _press(WidgetTester tester) =>
    tester.startGesture(tester.getCenter(_card));

Future<void> _activate(WidgetTester tester) async {
  tester.semantics.tap(find.semantics.byLabel(_label));
  await tester.pump();
}

void main() {
  group('timing', () {
    testWidgets('the face shows 120 ms after the press, not before, and '
        'hides on release', (tester) async {
      final h = _Harness();
      await tester.pumpWidget(h.build());
      final hold = await _press(tester);
      await tester.pump(const Duration(milliseconds: 100));
      expect(_face, findsNothing);
      await tester.pump(const Duration(milliseconds: 20));
      expect(_face, findsOneWidget);
      expect(find.text(_secret), findsOneWidget);

      await hold.up();
      await tester.pump();
      expect(_face, findsNothing);
      expect(h.changes, [true, false]);
    });

    testWidgets('a reveal counts after 0.8 s visible, once per showing', (
      tester,
    ) async {
      final h = _Harness();
      await tester.pumpWidget(h.build());
      final hold = await _press(tester);
      await tester.pump(HoldToReveal.holdDelay);
      await tester.pump(const Duration(milliseconds: 790));
      expect(h.revealed, 0);
      await tester.pump(const Duration(milliseconds: 20));
      expect(h.revealed, 1);
      await tester.pump(const Duration(seconds: 3));
      expect(h.revealed, 1);
      await hold.up();

      // A glance shorter than 0.8 s does not count.
      final glance = await _press(tester);
      await tester.pump(HoldToReveal.holdDelay);
      await tester.pump(const Duration(milliseconds: 500));
      await glance.up();
      await tester.pump(const Duration(seconds: 1));
      expect(h.revealed, 1);
    });

    testWidgets('it stays as long as it is held: no cap', (tester) async {
      await tester.pumpWidget(_Harness().build());
      final longHold = await _press(tester);
      await tester.pump(const Duration(seconds: 30));
      expect(_face, findsOneWidget);
      await longHold.up();
    });

    testWidgets('a quick tap does not flash the face', (tester) async {
      final h = _Harness();
      await tester.pumpWidget(h.build());
      await tester.tap(_card);
      await tester.pump(const Duration(milliseconds: 500));
      expect(_face, findsNothing);
      expect(h.changes, isEmpty);
    });

    testWidgets('two quick taps are taps, not a reveal: nothing waits for a '
        'second', (tester) async {
      final h = _Harness();
      await tester.pumpWidget(h.build());
      await tester.tap(_card);
      await tester.pump(const Duration(milliseconds: 50));
      await tester.tap(_card);
      await tester.pump();
      expect(_face, findsNothing);
      expect(h.revealed, 0);
    });
  });

  group('the face', () {
    testWidgets('is drawn above the touch point, never under the thumb', (
      tester,
    ) async {
      await tester.pumpWidget(_Harness().build());
      final hold = await _press(tester);
      await tester.pump(HoldToReveal.holdDelay);
      final face = tester.getRect(_face);
      expect(face.bottom, lessThanOrEqualTo(tester.getCenter(_card).dy));
      await hold.up();
    });

    testWidgets('every showing shows every page at once, stacked: nothing '
        'waits behind a second hold', (tester) async {
      await tester.pumpWidget(_Harness(face: _myNight).build());
      final lines = [for (final page in _myNight.pages) ...page.lines];
      expect(lines, hasLength(greaterThan(1)));
      for (var i = 0; i < 2; i++) {
        final hold = await _press(tester);
        await tester.pump(HoldToReveal.holdDelay);
        for (final line in lines) {
          expect(find.text(line), findsOneWidget, reason: 'showing $i: $line');
        }
        await hold.up();
        await tester.pump();
      }
    });
  });

  group('it hides by itself', () {
    testWidgets('when the app leaves the foreground, and stays hidden', (
      tester,
    ) async {
      await tester.pumpWidget(_Harness().build());
      await _press(tester);
      await tester.pump(HoldToReveal.holdDelay);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
      await tester.pump();
      expect(_face, findsNothing);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(_face, findsNothing);
    });

    testWidgets('when the keyboard\'s focus moves away', (tester) async {
      await tester.pumpWidget(_Harness().build());
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(_face, findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(_face, findsNothing);
    });

    testWidgets('when another route covers the screen, and it cannot be '
        'shown while covered', (tester) async {
      final semantics = tester.ensureSemantics();
      final h = _Harness();
      await tester.pumpWidget(h.build());
      await _activate(tester);
      expect(_face, findsOneWidget);
      showDialog<void>(
        context: tester.element(find.text('Elsewhere')),
        builder: (_) => const Text('A dialog'),
      );
      await tester.pump();
      expect(_face, findsNothing);
      expect(h.changes, [true, false]);

      // The handler a screen reader would call, behind the dialog.
      tester
          .widget<Semantics>(
            find.descendant(of: _card, matching: find.byType(Semantics)).first,
          )
          .properties
          .onTap
          ?.call();
      await tester.pump();
      expect(_face, findsNothing);
      semantics.dispose();
    });
  });

  group('the accessible way', () {
    testWidgets('until shown it is a button, "{target}, hidden. Activate to '
        'show.", and the face is not read', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(_Harness().build());
      final node = tester.getSemantics(_card);
      // The label, then the cover's own words ("Face down" here).
      expect(node.label, startsWith('Your card, hidden. Activate to show.'));
      expect(node, containsSemantics(isButton: true, hasTapAction: true));
      expect(find.bySemanticsLabel(RegExp(_secret)), findsNothing);
      semantics.dispose();
    });

    testWidgets('activating shows the face, reads it aloud and counts, '
        'until activated again', (tester) async {
      final semantics = tester.ensureSemantics();
      final h = _Harness();
      await tester.pumpWidget(h.build());
      await _activate(tester);
      expect(_face, findsOneWidget);
      expect(h.revealed, 1);
      expect(
        find.bySemanticsLabel(RegExp(RegExp.escape(_secret))),
        findsOneWidget,
      );
      await tester.pump(const Duration(minutes: 1));
      expect(_face, findsOneWidget);
      await _activate(tester);
      expect(_face, findsNothing);
      semantics.dispose();
    });

    testWidgets('a held face is never read out', (tester) async {
      final semantics = tester.ensureSemantics();
      await tester.pumpWidget(_Harness().build());
      await _press(tester);
      await tester.pump(HoldToReveal.holdDelay);
      expect(_face, findsOneWidget);
      expect(
        find.bySemanticsLabel(RegExp(RegExp.escape(_secret))),
        findsNothing,
      );
      semantics.dispose();
    });

    testWidgets('a keyboard or switch activates it, with a focus ring', (
      tester,
    ) async {
      await tester.pumpWidget(_Harness().build());
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      final ring = tester.widget<Container>(
        find.descendant(of: _card, matching: find.byType(Container)).first,
      );
      expect(ring.foregroundDecoration, isNotNull);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(_face, findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.space);
      await tester.pump();
      expect(_face, findsNothing);
    });
  });

  group('nothing about the hidden state depends on the secret', () {
    testWidgets('its size is the cover\'s; the face is the one frame\'s size '
        'whatever it says', (tester) async {
      final covers = <Size>[];
      final faces = <Size>[];
      for (final face in [
        FaceContent.roleText(RoleId.villager),
        FaceContent.roleText(RoleId.minion),
        Viewer.villager.myNight,
      ]) {
        await tester.pumpWidget(_Harness(face: face).build());
        covers.add(tester.getSize(_card));
        final hold = await _press(tester);
        await tester.pump(HoldToReveal.holdDelay);
        covers.add(tester.getSize(_card));
        faces.add(tester.getSize(_face));
        await hold.up();
        await tester.pumpWidget(const SizedBox());
      }
      expect(covers.toSet(), {const Size.square(200)});
      expect(faces.toSet(), hasLength(1));
    });

    testWidgets('what is read out, and what is built, until it is shown', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final read = <String>{};
      for (final role in [RoleId.seer, RoleId.werewolf]) {
        await tester.pumpWidget(
          _Harness(face: FaceContent.roleText(role)).build(),
        );
        final node = tester.getSemantics(_card);
        read.add('${node.label}|${node.hint}|${node.value}');
        expect(_face, findsNothing);
        await tester.pumpWidget(const SizedBox());
      }
      expect(read, hasLength(1));
      semantics.dispose();
    });
  });

  testWidgets('its text is capped at 1.6 times larger', (tester) async {
    tester.platformDispatcher.textScaleFactorTestValue = 3;
    addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
    await tester.pumpWidget(_Harness().build());
    await _press(tester);
    await tester.pump(HoldToReveal.holdDelay);
    final paragraph = tester.renderObject<RenderParagraph>(find.text(_secret));
    expect(paragraph.textScaler.scale(10), 16);
  });
}
