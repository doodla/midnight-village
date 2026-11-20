import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/primitives/hold_to_reveal.dart';
import 'package:midnight_village/design_system/skin/ground.dart';
import 'package:midnight_village/design_system/skin/ground_scope.dart';
import 'package:midnight_village/design_system/skin/skin_theme.dart';

import '../../helpers/pump_skinned.dart';

const _secret = 'You are the Seer';

class _Harness {
  _Harness({this.secretText = _secret, this.secretSize = 200});

  final String secretText;
  final double secretSize;
  final changes = <bool>[];
  var secretBuilds = 0;

  Widget build() => MaterialApp(
    theme: skinTheme(skinsUnderTest.values.first),
    builder: (context, child) =>
        GroundScope(ground: GroundKind.night, child: child!),
    home: Scaffold(
      body: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          HoldToReveal(
            semanticLabel: 'Your card',
            onRevealChanged: changes.add,
            cover: const SizedBox.square(
              dimension: 200,
              child: Text('Face down'),
            ),
            secret: (_) {
              secretBuilds++;
              return SizedBox.square(
                dimension: secretSize,
                child: Text(secretText),
              );
            },
          ),
          // Somewhere else for the keyboard's focus to go.
          TextButton(onPressed: () {}, child: const Text('Elsewhere')),
        ],
      ),
    ),
  );
}

Finder get _card => find.byType(HoldToReveal);

/// The card as read out: its name, then what is showing.
final _label = RegExp('^Your card');

Future<void> _hold(WidgetTester tester) async {
  await tester.startGesture(tester.getCenter(_card));
  await tester.pump(HoldToReveal.holdDelay * 2);
}

Future<void> _toggle(WidgetTester tester) async {
  tester.semantics.tap(find.semantics.byLabel(_label));
  await tester.pump();
}

void main() {
  testWidgets('the secret shows only while held', (tester) async {
    final h = _Harness();
    await tester.pumpWidget(h.build());
    expect(find.text(_secret), findsNothing);

    final hold = await tester.startGesture(tester.getCenter(_card));
    await tester.pump(HoldToReveal.holdDelay * 2);
    expect(find.text(_secret), findsOneWidget);

    await hold.up();
    await tester.pump();
    expect(find.text(_secret), findsNothing);
    expect(find.text('Face down'), findsOneWidget);
    expect(h.changes, [true, false]);
  });

  testWidgets('a quick tap does not flash the secret', (tester) async {
    final h = _Harness();
    await tester.pumpWidget(h.build());
    await tester.tap(_card);
    await tester.pump();
    expect(find.text(_secret), findsNothing);
    expect(h.changes, isEmpty);
    expect(h.secretBuilds, 0);
  });

  testWidgets('a cancelled hold hides it', (tester) async {
    final h = _Harness();
    await tester.pumpWidget(h.build());
    final hold = await tester.startGesture(tester.getCenter(_card));
    await tester.pump(HoldToReveal.holdDelay * 2);
    await hold.cancel();
    await tester.pump();
    expect(find.text(_secret), findsNothing);
  });

  testWidgets('leaving the app while holding hides it', (tester) async {
    final h = _Harness();
    await tester.pumpWidget(h.build());
    await _hold(tester);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    expect(find.text(_secret), findsNothing);

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(
      find.text(_secret),
      findsNothing,
      reason: 'it stays hidden on return',
    );
  });

  testWidgets('a screen reader toggles it instead of holding', (tester) async {
    final semantics = tester.ensureSemantics();
    final h = _Harness();
    await tester.pumpWidget(h.build());

    final node = tester.getSemantics(_card);
    expect(
      node,
      containsSemantics(
        hint: 'Press and hold, or activate, to show',
        isButton: true,
        hasTapAction: true,
        isFocusable: true,
      ),
    );
    expect(find.bySemanticsLabel(RegExp(_secret)), findsNothing);

    await _toggle(tester);
    expect(find.text(_secret), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(_secret)), findsOneWidget);

    await _toggle(tester);
    expect(find.text(_secret), findsNothing);
    semantics.dispose();
  });

  group('a toggled secret hides by itself', () {
    testWidgets('when the app leaves the foreground', (tester) async {
      final semantics = tester.ensureSemantics();
      final h = _Harness();
      await tester.pumpWidget(h.build());
      await _toggle(tester);

      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      expect(h.changes, [true, false]);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
      await tester.pump();
      expect(find.text(_secret), findsNothing);
      semantics.dispose();
    });

    testWidgets('after a while', (tester) async {
      final semantics = tester.ensureSemantics();
      final h = _Harness();
      await tester.pumpWidget(h.build());
      await _toggle(tester);
      await tester.pump(
        HoldToReveal.toggleTimeout - const Duration(seconds: 1),
      );
      expect(find.text(_secret), findsOneWidget);

      await tester.pump(const Duration(seconds: 1));
      expect(find.text(_secret), findsNothing);
      expect(h.changes, [true, false]);
      semantics.dispose();
    });

    testWidgets('when the keyboard\'s focus moves away', (tester) async {
      final h = _Harness();
      await tester.pumpWidget(h.build());
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(find.text(_secret), findsOneWidget);

      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      expect(find.text(_secret), findsNothing);
    });

    testWidgets('when the screen reader moves on', (tester) async {
      final semantics = tester.ensureSemantics();
      final h = _Harness();
      await tester.pumpWidget(h.build());
      await _toggle(tester);
      final id = tester.getSemantics(_card).id;
      tester.binding.performSemanticsAction(
        SemanticsActionEvent(
          type: SemanticsAction.didLoseAccessibilityFocus,
          nodeId: id,
          viewId: tester.view.viewId,
        ),
      );
      await tester.pump();
      expect(find.text(_secret), findsNothing);
      semantics.dispose();
    });
  });

  testWidgets('another route over the screen hides it, held or toggled, so no '
      'scrim ever has the secret faintly behind it', (tester) async {
    final semantics = tester.ensureSemantics();
    final h = _Harness();
    await tester.pumpWidget(h.build());
    await _toggle(tester);
    expect(find.text(_secret), findsOneWidget);

    final context = tester.element(find.text('Elsewhere'));
    showDialog<void>(context: context, builder: (_) => const Text('A dialog'));
    await tester.pump();
    expect(find.text(_secret), findsNothing);
    expect(h.changes, [true, false]);

    // While covered it cannot be shown at all.
    await _toggleBehind(tester);
    expect(find.text(_secret), findsNothing);
    semantics.dispose();
  });

  testWidgets('a keyboard or switch activates it, with a visible focus ring', (
    tester,
  ) async {
    final h = _Harness();
    await tester.pumpWidget(h.build());
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();
    final ring = tester.widget<Container>(
      find.descendant(of: _card, matching: find.byType(Container)).first,
    );
    expect(ring.foregroundDecoration, isNotNull);

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(find.text(_secret), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(find.text(_secret), findsNothing);
  });

  group('nothing about the hidden state depends on the secret', () {
    testWidgets('its size, hidden and shown, is the cover\'s', (tester) async {
      final sizes = <Size>[];
      for (final (text, size) in [('Seer', 120.0), (_secret * 4, 320.0)]) {
        await tester.pumpWidget(
          _Harness(secretText: text, secretSize: size).build(),
        );
        sizes.add(tester.getSize(_card));
        await _hold(tester);
        sizes.add(tester.getSize(_card));
        await tester.pumpWidget(const SizedBox());
      }
      expect(sizes.toSet(), {const Size.square(200)});
    });

    testWidgets('what is read out, and what is built, until it is shown', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      final read = <String>[];
      for (final text in ['Seer', 'Werewolf']) {
        final h = _Harness(secretText: text);
        await tester.pumpWidget(h.build());
        final node = tester.getSemantics(_card);
        read.add('${node.label}|${node.hint}|${node.value}');
        expect(h.secretBuilds, 0);
        await tester.pumpWidget(const SizedBox());
      }
      expect(read.toSet(), hasLength(1));
      semantics.dispose();
    });
  });
}

/// A screen reader's activate while another route covers the card.
Future<void> _toggleBehind(WidgetTester tester) async {
  final state = tester.state(_card);
  // The semantics node is hidden behind the dialog; call the same handler a
  // screen reader would.
  final semantics = tester.widget<Semantics>(
    find.descendant(of: _card, matching: find.byType(Semantics)).first,
  );
  semantics.properties.onTap?.call();
  expect(state.mounted, isTrue);
  await tester.pump();
}
