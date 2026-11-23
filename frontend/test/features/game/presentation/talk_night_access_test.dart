// "My night" on 08 is held, and a hold is not a gesture everyone can make: a
// screen reader's activate, a switch or the keyboard shows it too, until
// activated again (HoldToReveal's own action, on the note and nowhere else).
// Under the note there is exactly one tap target, named; the night is cleared
// when the screen changes, another route covers it, or the app leaves the
// foreground. The night that opens by itself is put away by its own named
// "Close", by a touch and by Back (back_test.dart).

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter/semantics.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/copy/copy.dart';
import 'package:midnight_village/design_system/faces/held_face.dart';
import 'package:midnight_village/design_system/primitives/hold_to_reveal.dart';
import 'package:midnight_village/design_system/teach/learned_store.dart';
import 'package:midnight_village/features/game/domain/game_me.dart';
import 'package:midnight_village/features/game/presentation/shell/talk_screen.dart';
import 'package:midnight_village/features/game/presentation/shell/talk_square.dart';

import '../../../helpers/component_sheet.dart' show learnedOverrides;
import '../../../helpers/pump_skinned.dart';
import '../../../helpers/sheet/sheet_data.dart' as sheet;

final _hidden = RegExp('^${RegExp.escape(TalkCopy.myNight)}, hidden');

Future<void> _pump(WidgetTester tester, {bool openNight = false}) async {
  tester.view.physicalSize = const Size(390, 844);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await pumpSkinned(
    tester,
    ProviderScope(
      overrides: learnedOverrides({...Cue.values}),
      child: TalkView(
        me: GameMe.fromJson(sheet.recordedMe('me_talk_results_seen')),
        secondsLeft: 192,
        onReady: () {},
        openNight: openNight,
      ),
    ),
  );
  await tester.pump();
}

/// The semantics nodes at or under [node] that can be tapped.
List<SemanticsNode> _tappable(SemanticsNode node) {
  final found = <SemanticsNode>[];
  void walk(SemanticsNode n) {
    if (n.getSemanticsData().hasAction(SemanticsAction.tap)) found.add(n);
    n.visitChildren((c) {
      walk(c);
      return true;
    });
  }

  walk(node);
  return found;
}

Future<void> _activate(WidgetTester tester) async {
  tester.semantics.tap(find.semantics.byLabel(_hidden));
  await tester.pump();
}

void main() {
  group('a screen reader, a switch or the keyboard opens My night', () {
    testWidgets('activating the note shows the night on the board until it '
        'is activated again', (tester) async {
      final semantics = tester.ensureSemantics();
      await _pump(tester);
      expect(find.byType(MyNightPanel), findsNothing);
      expect(find.byType(HeldFace), findsNothing);

      await _activate(tester);
      expect(find.byType(MyNightPanel), findsOneWidget);
      expect(find.byType(HeldFace), findsOneWidget);
      expect(
        find.semantics.byLabel(_hidden),
        findsNothing,
        reason: 'shown: the note no longer says hidden',
      );

      tester.semantics.tap(find.semantics.byLabel(RegExp('^My night')));
      await tester.pump();
      expect(find.byType(MyNightPanel), findsNothing);
      expect(find.byType(HeldFace), findsNothing);
      expect(find.semantics.byLabel(_hidden), findsOneWidget);
      semantics.dispose();
    });

    testWidgets('the keyboard (Enter) does the same', (tester) async {
      await _pump(tester);
      final note = find.byType(HoldToReveal);
      await tester.sendKeyEvent(LogicalKeyboardKey.tab);
      await tester.pump();
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(note, findsOneWidget);
      expect(find.byType(MyNightPanel), findsOneWidget);
      await tester.sendKeyEvent(LogicalKeyboardKey.enter);
      await tester.pump();
      expect(find.byType(MyNightPanel), findsNothing);
    });

    testWidgets('one named tap target under the note: the seal adds no '
        'unnamed second one', (tester) async {
      final semantics = tester.ensureSemantics();
      await _pump(tester);
      final targets = _tappable(tester.getSemantics(find.byType(HoldToReveal)));
      expect(targets, hasLength(1));
      expect(targets.single.label, startsWith(TalkCopy.myNight));
      semantics.dispose();
    });

    testWidgets('shown by activation, it is cleared when the app leaves the '
        'foreground', (tester) async {
      final semantics = tester.ensureSemantics();
      await _pump(tester);
      await _activate(tester);
      expect(find.byType(MyNightPanel), findsOneWidget);
      tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
      await tester.pump();
      expect(find.byType(MyNightPanel), findsNothing);
      expect(find.byType(HeldFace), findsNothing);
      semantics.dispose();
    });

    testWidgets('shown by activation, it is cleared when another route '
        'covers the screen, and is not back when it uncovers', (tester) async {
      final semantics = tester.ensureSemantics();
      await _pump(tester);
      await _activate(tester);
      expect(find.byType(MyNightPanel), findsOneWidget);
      final navigator = tester.state<NavigatorState>(find.byType(Navigator));
      unawaited(
        navigator.push(
          MaterialPageRoute<void>(builder: (_) => const Text('Another')),
        ),
      );
      await tester.pumpAndSettle();
      expect(find.byType(HeldFace, skipOffstage: false), findsNothing);
      navigator.pop();
      await tester.pumpAndSettle();
      expect(find.byType(MyNightPanel), findsNothing);
      semantics.dispose();
    });

    testWidgets('shown by activation, it is gone when the screen changes '
        '(the phase moves on)', (tester) async {
      final semantics = tester.ensureSemantics();
      await _pump(tester);
      await _activate(tester);
      expect(find.byType(HeldFace), findsOneWidget);
      await tester.pumpWidget(const SizedBox());
      expect(find.byType(HeldFace), findsNothing);
      expect(tester.takeException(), isNull);
      semantics.dispose();
    });
  });

  testWidgets('the night that opens by itself has one tap target, named '
      '"Close", which puts it away', (tester) async {
    final semantics = tester.ensureSemantics();
    await _pump(tester, openNight: true);
    expect(find.byType(MyNightPanel), findsOneWidget);
    final close = find.semantics.byLabel(RoleSheetCopy.close);
    expect(close, findsOneWidget);
    tester.semantics.tap(close);
    await tester.pump();
    expect(find.byType(MyNightPanel), findsNothing);
    expect(find.semantics.byLabel(RoleSheetCopy.close), findsNothing);
    semantics.dispose();
  });
}
