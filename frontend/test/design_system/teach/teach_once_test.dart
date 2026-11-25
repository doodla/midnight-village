import '../../helpers/finger.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/copy/copy.dart';
import 'package:midnight_village/design_system/faces/face_content.dart';
import 'package:midnight_village/design_system/layout/space.dart';
import 'package:midnight_village/design_system/models/role.dart';
import 'package:midnight_village/design_system/primitives/face_down_card.dart';
import 'package:midnight_village/design_system/primitives/hold_to_reveal.dart';
import 'package:midnight_village/design_system/primitives/primary_button.dart';
import 'package:midnight_village/design_system/skin/ground.dart';
import 'package:midnight_village/design_system/skin/ground_scope.dart';
import 'package:midnight_village/design_system/skin/skin_theme.dart';
import 'package:midnight_village/design_system/teach/cue_wave.dart';
import 'package:midnight_village/design_system/teach/hold_cue.dart';
import 'package:midnight_village/design_system/teach/learned_store.dart';
import 'package:midnight_village/design_system/teach/teach_once.dart';
import 'package:midnight_village/design_system/teach/teaching_hold.dart';

import '../../helpers/component_sheet.dart';
import '../../helpers/pump_skinned.dart';

/// A face-down card that teaches the hold, with its locked gate, on a
/// device that has learned [learned].
class _Gate extends StatefulWidget {
  const _Gate();

  @override
  State<_Gate> createState() => _GateState();
}

class _GateState extends State<_Gate> {
  final _replay = CueReplay();
  var _open = false;

  @override
  void dispose() {
    _replay.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Column(
    mainAxisAlignment: MainAxisAlignment.end,
    children: [
      SizedBox(
        width: 200,
        child: TeachingHold(
          target: CardCopy.headline,
          face: FaceContent.roleText(RoleId.seer),
          replay: _replay,
          onRevealed: () => setState(() => _open = true),
          cover: (teaching) =>
              FaceDownCard(size: FaceDownSize.hero, hold: teaching),
        ),
      ),
      if (_open)
        PrimaryButton(label: CardCopy.ready, onPressed: () {})
      else
        PrimaryButton.locked(
          label: CardCopy.ready,
          onLockedTap: _replay.replay,
        ),
    ],
  );
}

Future<ProviderContainer> _pump(
  WidgetTester tester, {
  Set<Cue> learned = const {},
  bool reduceMotion = false,
  Widget child = const _Gate(),
}) async {
  final container = ProviderContainer(overrides: learnedOverrides(learned));
  addTearDown(container.dispose);
  await tester.pumpWidget(
    UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        theme: skinTheme(skinsUnderTest.values.first),
        builder: (context, app) => GroundScope(
          ground: GroundKind.night,
          child: MediaQuery(
            data: MediaQuery.of(
              context,
            ).copyWith(disableAnimations: reduceMotion),
            child: app!,
          ),
        ),
        home: Scaffold(body: Center(child: child)),
      ),
    ),
  );
  return container;
}

Finder get _cue => find.text(CommonCopy.hold);

/// The cue's ring.
Finder get _ring => find.descendant(
  of: find.byType(HoldCue),
  matching: find.byType(CustomPaint),
);

/// How much of the ring has filled.
double _filled(WidgetTester tester) =>
    (tester.widget<CustomPaint>(_ring).painter! as HoldRingPainter).fill.value;

void main() {
  testWidgets('the cue shows on a device that has not learned it, and the '
      'first reveal that counts learns it', (tester) async {
    final app = await _pump(tester);
    expect(_cue, findsOneWidget);
    expect(_filled(tester), 0);

    final hold = await tester.startGesture(
      tester.getCenter(find.byType(FaceDownCard)),
    );
    await tester.pump(HoldToReveal.holdDelay);
    await tester.pump(HoldToReveal.revealedAfter ~/ 2);
    expect(_cue, findsOneWidget, reason: 'the ring fills while held');
    expect(_filled(tester), closeTo(0.5, 0.1));
    await tester.pump(HoldToReveal.revealedAfter ~/ 2);
    await tester.pump();
    expect(app.read(learnedCuesProvider), contains(Cue.hold));
    expect(_ring, findsNothing, reason: 'learned: the card is a card');
    await hold.up();
    await tester.pump();
    expect(_cue, findsNothing);
    expect(find.text(CardCopy.ready), findsOneWidget);
  });

  testWidgets('a glance under 0.8 s teaches nothing and opens nothing', (
    tester,
  ) async {
    final app = await _pump(tester);
    final glance = await tester.startGesture(
      tester.getCenter(find.byType(FaceDownCard)),
    );
    await tester.pump(HoldToReveal.holdDelay);
    await tester.pump(const Duration(milliseconds: 500));
    await glance.up();
    await tester.pump();
    expect(app.read(learnedCuesProvider), isEmpty);
    expect(_cue, findsOneWidget);
    expect(
      tester.widget<PrimaryButton>(find.byType(PrimaryButton)).phase,
      ButtonPhase.locked,
    );
  });

  testWidgets('a device that has learned it shows nothing on the card; a '
      'tap on the locked gate replays the cue for 3 s', (tester) async {
    await _pump(tester, learned: {Cue.hold});
    expect(_cue, findsNothing);
    expect(_ring, findsNothing);

    await pressLikeAFinger(tester, find.byType(PrimaryButton));
    await tester.pump();
    expect(_cue, findsOneWidget);
    await tester.pump(TeachOnce.replayFor - const Duration(milliseconds: 1));
    expect(_cue, findsOneWidget);
    await tester.pump(const Duration(milliseconds: 1));
    expect(_cue, findsNothing);
  });

  testWidgets('the ring breathes, and stands still with reduced motion', (
    tester,
  ) async {
    double scale() => tester
        .widget<ScaleTransition>(
          find.descendant(
            of: find.byType(HoldCue),
            matching: find.byType(ScaleTransition),
          ),
        )
        .scale
        .value;

    await _pump(tester);
    await tester.pump(const Duration(milliseconds: 350));
    expect(scale(), greaterThan(1));

    await _pump(tester, reduceMotion: true);
    await tester.pump(const Duration(milliseconds: 350));
    expect(scale(), 1);
    expect(_cue, findsOneWidget, reason: 'the word stays');
  });

  testWidgets('the ring breathes three times and rests, still and asking no '
      'frame; a tap on the locked gate before a hold breathes it once more', (
    tester,
  ) async {
    double scale() => tester
        .widget<ScaleTransition>(
          find.descendant(
            of: find.byType(HoldCue),
            matching: find.byType(ScaleTransition),
          ),
        )
        .scale
        .value;
    const step = Duration(milliseconds: 50);
    Future<void> run(Duration length) async {
      for (var t = Duration.zero; t < length; t += step) {
        await tester.pump(step);
      }
    }

    Future<void> resting(String when) async {
      expect(scale(), 1, reason: when);
      expect(_cue, findsOneWidget, reason: 'still, it is still the sign');
      expect(tester.binding.transientCallbackCount, 0);
      expect(tester.binding.hasScheduledFrame, isFalse);
    }

    await _pump(tester);
    await run(HoldCue.breath * (HoldCue.breaths - 1));
    expect(tester.binding.transientCallbackCount, greaterThan(0));
    // (The card's first frames come before the ring's: a little to spare.)
    await run(HoldCue.breath * 1.5);
    await resting('three breaths');
    await tester.pump(Motion.restMost * 2);
    await resting('a long rest');

    await pressLikeAFinger(tester, find.byType(FaceDownCard));
    await run(HoldCue.breath ~/ 4);
    await resting('a tap on the card asks nothing of it');

    await pressLikeAFinger(tester, find.byType(PrimaryButton));
    await run(HoldCue.breath ~/ 4);
    expect(scale(), greaterThan(1), reason: 'a tap on the gate: once more');
    // It began a settle after the lift (FingerDown), not in the tap's frame.
    await run(HoldCue.breath + Motion.settle);
    await resting('after the gate');
  });

  group('the wave', () {
    Widget row(bool play) => Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        for (var i = 0; i < 3; i++)
          CueWave(
            play: play,
            index: i,
            distance: CueWave.boardLift,
            child: SizedBox.square(dimension: 20, key: ValueKey(i)),
          ),
      ],
    );

    double lift(WidgetTester tester, int i) =>
        tester.getTopLeft(find.byKey(ValueKey(i))).dy;

    testWidgets('lifts each in turn, once, left to right', (tester) async {
      await _pump(tester, child: row(true));
      final rest = lift(tester, 0);
      await tester.pump(); // the post-frame start
      await tester.pump(CueWave.each ~/ 2);
      expect(lift(tester, 0), lessThan(rest));
      expect(lift(tester, 2), rest, reason: 'not yet');
      await tester.pump(CueWave.stagger * 2);
      expect(lift(tester, 2), lessThan(rest));
      await tester.pump(const Duration(seconds: 1));
      expect([for (var i = 0; i < 3; i++) lift(tester, i)], [rest, rest, rest]);
    });

    testWidgets('does not run once learned, or with reduced motion', (
      tester,
    ) async {
      for (final (play, reduce) in [(false, false), (true, true)]) {
        await _pump(tester, child: row(play), reduceMotion: reduce);
        final rest = lift(tester, 0);
        await tester.pump();
        await tester.pump(CueWave.each ~/ 2);
        expect(lift(tester, 0), rest);
      }
    });
  });
}
