import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/primitives/hold_to_reveal.dart';

const _secret = 'You are the Seer';

class _Harness {
  final changes = <bool>[];

  Widget build() => MaterialApp(
    home: Scaffold(
      body: Center(
        child: HoldToReveal(
          semanticLabel: 'Your card',
          onRevealChanged: changes.add,
          cover: const SizedBox.square(
            dimension: 200,
            child: Text('Face down'),
          ),
          secret: (_) =>
              const SizedBox.square(dimension: 200, child: Text(_secret)),
        ),
      ),
    ),
  );
}

Finder get _card => find.byType(HoldToReveal);

/// The card as read out: its name, then what is showing.
final _label = RegExp('^Your card');

void main() {
  testWidgets('the secret shows only while held', (tester) async {
    final h = _Harness();
    await tester.pumpWidget(h.build());
    expect(find.text(_secret), findsNothing);

    final hold = await tester.startGesture(tester.getCenter(_card));
    await tester.pump(HoldToReveal.holdDelay * 2);
    expect(find.text(_secret), findsOneWidget);
    expect(find.text('Face down'), findsNothing);

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
    final hold = await tester.startGesture(tester.getCenter(_card));
    await tester.pump(HoldToReveal.holdDelay * 2);

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
    await hold.up();
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
    expect(node.label, startsWith('Your card'));
    expect(find.bySemanticsLabel(RegExp(_secret)), findsNothing);

    tester.semantics.tap(find.semantics.byLabel(_label));
    await tester.pump();
    expect(find.text(_secret), findsOneWidget);
    expect(find.bySemanticsLabel(RegExp(_secret)), findsOneWidget);

    tester.semantics.tap(find.semantics.byLabel(_label));
    await tester.pump();
    expect(find.text(_secret), findsNothing);
    semantics.dispose();
  });

  testWidgets('a toggled reveal hides when the app leaves the foreground', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    final h = _Harness();
    await tester.pumpWidget(h.build());
    tester.semantics.tap(find.semantics.byLabel(_label));
    await tester.pump();

    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    expect(h.changes, [true, false]);

    // Nothing is drawn while paused; the first frame back shows the cover.
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pump();
    expect(find.text(_secret), findsNothing);
    semantics.dispose();
  });

  testWidgets('a keyboard or switch activates it', (tester) async {
    final h = _Harness();
    await tester.pumpWidget(h.build());
    await tester.sendKeyEvent(LogicalKeyboardKey.tab);
    await tester.pump();

    await tester.sendKeyEvent(LogicalKeyboardKey.enter);
    await tester.pump();
    expect(find.text(_secret), findsOneWidget);

    await tester.sendKeyEvent(LogicalKeyboardKey.space);
    await tester.pump();
    expect(find.text(_secret), findsNothing);
  });
}
