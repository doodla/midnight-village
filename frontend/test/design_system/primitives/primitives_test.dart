import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/primitives/player_row.dart';
import 'package:midnight_village/design_system/primitives/primary_button.dart';
import 'package:midnight_village/design_system/primitives/progress_pips.dart';
import 'package:midnight_village/design_system/primitives/screen_frame.dart';
import 'package:midnight_village/design_system/primitives/secondary_button.dart';
import 'package:midnight_village/design_system/primitives/sheet_scaffold.dart';
import 'package:midnight_village/design_system/primitives/world_timer.dart';
import 'package:midnight_village/design_system/skin/art_set.dart';
import 'package:midnight_village/design_system/skin/ground.dart';
import 'package:midnight_village/design_system/skin/ground_scope.dart';
import 'package:midnight_village/design_system/skin/skin_theme.dart';

import '../../helpers/pump_skinned.dart';

void main() {
  group('PrimaryButton', () {
    testWidgets('a label ending in a check mark draws the mark as an icon '
        "(the skin's fonts have none) and still says it whole", (tester) async {
      final semantics = tester.ensureSemantics();
      await pumpSkinned(
        tester,
        const PrimaryButton.done(label: 'Ready${PrimaryButton.checkMark}'),
      );
      expect(find.text('Ready'), findsOneWidget);
      expect(find.byIcon(Icons.check), findsOneWidget);
      expect(
        find.bySemanticsLabel('Ready${PrimaryButton.checkMark}'),
        findsOneWidget,
      );
      semantics.dispose();
    });

    testWidgets('a tap acts; disabled or busy, it does not', (tester) async {
      var taps = 0;
      Future<void> pump({bool enabled = true, bool busy = false}) =>
          pumpSkinned(
            tester,
            PrimaryButton(
              label: 'Deal the cards',
              onPressed: enabled ? () => taps++ : null,
              busy: busy,
            ),
          );

      await pump();
      await tester.tap(find.byType(PrimaryButton));
      expect(taps, 1);

      await pump(enabled: false);
      await tester.tap(find.byType(PrimaryButton));
      await pump(busy: true);
      await tester.tap(find.byType(PrimaryButton));
      expect(taps, 1);
      expect(find.byType(CircularProgressIndicator), findsOneWidget);
    });

    testWidgets('a locked gate keeps its label and, tapped, asks for its cue '
        'instead of acting', (tester) async {
      var cue = 0;
      await pumpSkinned(
        tester,
        PrimaryButton.locked(label: 'Ready', onLockedTap: () => cue++),
      );
      await tester.tap(find.text('Ready'));
      expect(cue, 1);
      expect(
        tester.getSemantics(find.byType(PrimaryButton)),
        containsSemantics(label: 'Ready', isEnabled: false),
      );
    });

    testWidgets('only a ready button is amber, with an ink edge by day; done '
        'is settled: no fill, no outline, a check and its word', (
      tester,
    ) async {
      final skin = skinsUnderTest.values.first;
      Future<BoxDecoration> drawn(Widget button, GroundKind ground) async {
        await pumpSkinned(tester, button, ground: ground);
        return tester
                .widget<AnimatedContainer>(find.byType(AnimatedContainer))
                .decoration!
            as BoxDecoration;
      }

      final night = await drawn(
        PrimaryButton(label: 'Deal to 5', onPressed: () {}),
        GroundKind.night,
      );
      expect(night.color, skin.night.accent);
      expect(night.border, isNull);
      final day = await drawn(
        PrimaryButton(label: 'Lock in Cleo', onPressed: () {}),
        GroundKind.day,
      );
      expect(day.color, skin.day.accent);
      expect((day.border! as Border).top.color, skin.day.accentEdge);
      for (final quiet in [
        const PrimaryButton(label: 'Pick a name', onPressed: null),
        PrimaryButton.locked(label: 'Ready', onLockedTap: () {}),
        PrimaryButton.quiet(label: 'Ready to vote', onPressed: () {}),
      ]) {
        final outline = await drawn(quiet, GroundKind.day);
        expect(outline.color, isNull, reason: quiet.label);
        expect(outline.border, isNotNull, reason: quiet.label);
      }
      for (final ground in GroundKind.values) {
        for (final label in ['Chosen', 'Locked', 'Ready ✓']) {
          final done = await drawn(PrimaryButton.done(label: label), ground);
          expect(done.color, isNull, reason: '$label: nothing to press');
          expect(done.border, isNull, reason: '$label: no gate outline');
          expect(find.byIcon(Icons.check), findsOneWidget, reason: label);
          expect(find.text('Ready ✓'), findsNothing, reason: 'one check');
        }
      }
    });

    testWidgets('one form of "Ready ✓": the check before the word, both as '
        'done and as a toggle (still outlined: a button)', (tester) async {
      for (final button in [
        const PrimaryButton.done(label: 'Ready ✓'),
        PrimaryButton.quiet(label: 'Ready ✓', onPressed: () {}),
      ]) {
        await pumpSkinned(tester, button, ground: GroundKind.day);
        final check = tester.getCenter(find.byIcon(Icons.check));
        final word = tester.getCenter(find.text('Ready'));
        expect(check.dx, lessThan(word.dx), reason: button.phase.name);
      }
      final toggle =
          tester
                  .widget<AnimatedContainer>(find.byType(AnimatedContainer))
                  .decoration!
              as BoxDecoration;
      expect(toggle.border, isNotNull, reason: 'the toggle is a button');
    });

    testWidgets('it goes down while pressed and comes back up', (tester) async {
      await pumpSkinned(
        tester,
        PrimaryButton(label: 'Deal the cards', onPressed: () {}),
      );
      final rest = tester.getTopLeft(find.text('Deal the cards'));

      final press = await tester.startGesture(
        tester.getCenter(find.byType(PrimaryButton)),
      );
      await tester.pumpAndSettle();
      final down = tester.getTopLeft(find.text('Deal the cards'));
      expect(down.dx, greaterThan(rest.dx));
      expect(down.dy, greaterThan(rest.dy));

      await press.up();
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.text('Deal the cards')), rest);
    });

    testWidgets('it says what it is and whether it can be used', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pumpSkinned(
        tester,
        const PrimaryButton(label: 'Lock in Cleo', onPressed: null),
      );
      expect(
        tester.getSemantics(find.byType(PrimaryButton)),
        containsSemantics(
          label: 'Lock in Cleo',
          isButton: true,
          hasEnabledState: true,
          isEnabled: false,
        ),
      );
      semantics.dispose();
    });
  });

  testWidgets('SecondaryButton acts on a tap', (tester) async {
    var taps = 0;
    await pumpSkinned(
      tester,
      SecondaryButton(label: 'Do nothing tonight', onPressed: () => taps++),
    );
    await tester.tap(find.text('Do nothing tonight'));
    expect(taps, 1);
  });

  testWidgets('PlayerRow reads as a selectable button when it can be picked', (
    tester,
  ) async {
    final semantics = tester.ensureSemantics();
    var picked = 0;
    await pumpSkinned(
      tester,
      ground: GroundKind.day,
      SizedBox(
        width: 340,
        child: PlayerRow(
          token: TokenId.moth,
          name: 'Cleo',
          picked: true,
          size: PlayerRowSize.large,
          onTap: () => picked++,
        ),
      ),
    );
    await tester.tap(find.text('Cleo'));
    expect(picked, 1);
    expect(
      tester.getSemantics(find.byType(PlayerRow)),
      containsSemantics(
        isButton: true,
        hasSelectedState: true,
        isSelected: true,
      ),
    );
    semantics.dispose();
  });

  testWidgets('a long name is cut short, not wrapped or overflowed', (
    tester,
  ) async {
    await pumpSkinned(
      tester,
      const SizedBox(
        width: 240,
        child: PlayerRow(
          token: TokenId.scythe,
          name: 'Florentyna-Bartholomew of the Hill',
        ),
      ),
    );
    expect(tester.takeException(), isNull);
  });

  testWidgets('ProgressPips reads out its words, not its dots', (tester) async {
    final semantics = tester.ensureSemantics();
    await pumpSkinned(
      tester,
      const ProgressPips(done: 3, total: 5, label: '3 of 5 ready'),
    );
    expect(find.bySemanticsLabel('3 of 5 ready'), findsOneWidget);
    semantics.dispose();
  });

  group('WorldTimer', () {
    testWidgets('with no deadline known it is the candle alone, no number', (
      tester,
    ) async {
      await pumpSkinned(tester, const WorldTimer.candle(secondsLeft: null));
      expect(find.byType(Text), findsNothing);
      expect(tester.takeException(), isNull);
    });

    test('writes seconds as the mocks do and stops at nothing', () {
      expect(WorldTimer.format(19), '19');
      expect(WorldTimer.format(60), '1:00');
      expect(WorldTimer.format(252), '4:12');
      expect(WorldTimer.format(0), '0');
      expect(WorldTimer.format(-3), '0');
    });

    testWidgets('reads out its number, or what the screen says instead', (
      tester,
    ) async {
      final semantics = tester.ensureSemantics();
      await pumpSkinned(tester, const WorldTimer.candle(secondsLeft: 19));
      expect(find.bySemanticsLabel('19'), findsOneWidget);
      await pumpSkinned(
        tester,
        const WorldTimer.candle(secondsLeft: 19, semanticLabel: '19 left'),
      );
      expect(find.bySemanticsLabel('19 left'), findsOneWidget);
      semantics.dispose();
    });
  });

  group('ScreenFrame', () {
    Future<void> pumpFrame(WidgetTester tester, Size size, {double text = 1}) {
      tester.view.physicalSize = size;
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      return tester.pumpWidget(
        MaterialApp(
          theme: skinTheme(skinsUnderTest.values.first),
          home: MediaQuery.withClampedTextScaling(
            minScaleFactor: text,
            maxScaleFactor: text,
            child: ScreenFrame(
              ground: GroundKind.night,
              body: Column(
                children: [
                  for (var i = 0; i < 20; i++)
                    PlayerRow(token: TokenId.crow, name: 'Player $i'),
                ],
              ),
              actions: [PrimaryButton(label: 'Deal', onPressed: () {})],
            ),
          ),
        ),
      );
    }

    testWidgets('on a wide screen the phone layout is centred', (tester) async {
      await pumpFrame(tester, const Size(1200, 900));
      final button = tester.getRect(find.byType(PrimaryButton));
      expect(button.width, lessThanOrEqualTo(ScreenFrame.maxWidth));
      expect(button.center.dx, closeTo(600, 1));
    });

    testWidgets('the actions stay at the bottom and the body scrolls', (
      tester,
    ) async {
      await pumpFrame(tester, const Size(390, 844), text: 2);
      expect(tester.takeException(), isNull);
      expect(tester.getRect(find.byType(PrimaryButton)).bottom, lessThan(844));
      final actions = tester.getRect(find.byType(PrimaryButton));
      expect(
        tester.getRect(find.text('Player 19')).top,
        greaterThan(actions.top),
        reason: 'below the fold, reached by scrolling',
      );
      await tester.drag(
        find.byType(SingleChildScrollView),
        const Offset(0, -2000),
      );
      await tester.pumpAndSettle();
      expect(
        tester.getRect(find.text('Player 19')).bottom,
        lessThan(actions.top),
      );
    });
  });

  testWidgets('a sheet opens on paper, over the screen it covers', (
    tester,
  ) async {
    late GroundKind inside;
    await pumpSkinned(
      tester,
      Builder(
        builder: (context) => TextButton(
          onPressed: () => showSkinSheet<void>(
            context,
            builder: (_) => SheetScaffold(
              child: Builder(
                builder: (context) {
                  inside = GroundScope.of(context);
                  return const Text('Troublemaker');
                },
              ),
            ),
          ),
          child: const Text('Open'),
        ),
      ),
    );
    await tester.tap(find.text('Open'));
    await tester.pumpAndSettle();
    expect(find.text('Troublemaker'), findsOneWidget);
    expect(inside, GroundKind.paper);
  });
}
