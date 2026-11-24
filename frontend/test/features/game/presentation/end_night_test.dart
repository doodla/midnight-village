import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/copy/copy.dart';
import 'package:midnight_village/design_system/layout/space.dart';
import 'package:midnight_village/design_system/models/role.dart';
import 'package:midnight_village/design_system/primitives/board_pieces.dart';
import 'package:midnight_village/design_system/primitives/death_mark.dart';
import 'package:midnight_village/design_system/primitives/layered_art.dart';
import 'package:midnight_village/design_system/primitives/paper_scrap.dart';
import 'package:midnight_village/design_system/primitives/primary_button.dart';
import 'package:midnight_village/design_system/primitives/sliced_art.dart';
import 'package:midnight_village/design_system/primitives/vote_tag.dart';
import 'package:midnight_village/features/game/domain/end_story.dart';
import 'package:midnight_village/features/game/presentation/end/end_board_view.dart';
import 'package:midnight_village/features/game/presentation/end/end_night.dart';

import '../../../helpers/end_board_pump.dart';
import '../../../helpers/outcome_samples.dart';
import '../../../helpers/finger.dart';

// What happened, on the board (docs/specs/frontend/end-board.md, section 8):
// the scrap starts the night and becomes the way back; every card turns to
// the deal where it lies; a tap plays the next step (or finishes the one
// playing), a swipe left too and a swipe right goes back; the line of each
// step is in the banner and read out; the settled board comes back pixel for
// pixel; nothing vibrates; the paper that holds still is not painted again;
// the same results fetched again change nothing; the foot's controls work
// at night; the first time, a cue that the board goes on. Every card of
// every step in view: end_night_sweep_test.dart.

late List<String> _buzzes;

Future<EndNight> _open(
  WidgetTester tester,
  Map<String, dynamic> results, {
  Size screen = const Size(390, 844),
  double scale = 1,
  bool reduceMotion = false,
}) async {
  _buzzes = [];
  tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
    SystemChannels.platform,
    (call) async {
      if (call.method == 'HapticFeedback.vibrate') {
        _buzzes.add(call.arguments as String);
      }
      return null;
    },
  );
  addTearDown(
    () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      null,
    ),
  );
  tester.view.physicalSize = screen;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await pumpEndBoardOn(
    tester,
    results,
    scale: scale,
    reduceMotion: reduceMotion,
  );
  return _night(tester);
}

EndNight _night(WidgetTester tester) =>
    tester.widget<EndNightScope>(find.byType(EndNightScope)).notifier!;

Future<void> _tapScrap(WidgetTester tester, String label) async {
  // On one line, or on two where one leaves the middle cards no room.
  await pressLikeAFinger(
    tester,
    find
        .byWidgetPredicate(
          (w) => w is PaperScrap && w.label.replaceAll('\n', ' ') == label,
        )
        .first,
  );
  await tester.pump();
}

/// The step's motion played out, and the sky's.
Future<void> _done(WidgetTester tester) async {
  await tester.pump(Motion.scene + Motion.settle);
  await tester.pump(Motion.scene);
}

/// The banner's words, as one line.
String _banner(WidgetTester tester) => tester
    .widgetList<Text>(
      find.descendant(
        of: find.byType(BannerSlice),
        matching: find.byType(Text),
      ),
    )
    .map((t) => t.data)
    .join(' ');

/// A tap on the board, clear of the foot.
Future<void> _tapBoard(WidgetTester tester) async {
  await pressAtLikeAFinger(tester, const Offset(180, 300));
  await tester.pump();
}

/// The night's cards (the settled ones are hidden under them).
Finder get _nightCards => find.descendant(
  of: find.byType(NightBoard),
  matching: find.byType(BoardCard),
);

/// The night's card of [name] (turning, its two faces).
Finder _nightCard(String? name) => find.descendant(
  of: find.byType(NightBoard),
  matching: find.byWidgetPredicate((w) => w is BoardCard && w.name == name),
);

Future<List<int>> _picture(WidgetTester tester) async {
  final bytes = await tester.runAsync(() async {
    final image = await captureImage(tester.binding.rootElement!);
    final data = await image.toByteData();
    image.dispose();
    return data!.buffer.asUint8List().toList();
  });
  return bytes!;
}

/// The pixels (x, y on a phone 390 wide) where [a] and [b] differ.
List<(int, int)> _off(List<int> a, List<int> b) => {
  for (var i = 0; i < a.length; i++)
    if (a[i] != b[i]) (i ~/ 4 % 390, i ~/ 4 ~/ 390),
}.toList();

Future<void> _loadPictures(WidgetTester tester) async {
  final images = [
    for (final e in find.byType(Image).evaluate())
      ((e.widget as Image).image, e),
  ];
  await tester.runAsync(
    () => Future.wait([for (final (p, e) in images) precacheImage(p, e)]),
  );
  await tester.pump();
}

void main() {
  testWidgets('the scrap starts the night: the cards turn to the deal where '
      'they lie, the banner says so, the scrap leads back', (tester) async {
    final night = await _open(tester, recordedResults('results'));
    final story = night.story!;
    // Where each card lies on the board (the board may scroll).
    Offset board() => tester.getTopLeft(find.byType(BoardFrame));
    final settled = {
      for (final e in find.byType(BoardCard).evaluate())
        if ((e.widget as BoardCard).name case final name?)
          name: tester.getRect(find.byWidget(e.widget)).shift(-board()),
    };
    final day = _banner(tester);
    await _tapScrap(tester, EndCopy.whatHappened);
    await _done(tester);
    expect(night.step, 0);
    expect(_banner(tester), StoryCopy.dealt);
    expect(find.text(EndCopy.backToResult), findsOneWidget);
    expect(find.text(EndCopy.whatHappened), findsNothing);
    // Every card where it lay, showing the card dealt to that player.
    final outcome = outcomeOf(recordedResults('results'));
    for (final s in outcome.seats) {
      final card = _nightCard(s.name);
      final shown = tester
          .widgetList<BoardCard>(card)
          .where((c) => c.role == story.dealt.players[s.id]!.face);
      expect(shown, isNotEmpty, reason: s.name);
      final at = tester.getRect(card.first).shift(-board());
      final was = settled[s.name]!;
      expect((at.topLeft - was.topLeft).distance, lessThan(0.01));
      expect((at.size - was.size as Offset).distance, lessThan(0.01));
    }
    // The marks of the result are hidden: ribbons, tags.
    expect(find.byType(DeathRibbon).hitTestable(), findsNothing);
    expect(find.byType(VoteTag).hitTestable(), findsNothing);
    // Each step's line in its turn, then the result's again.
    for (final step in story.steps) {
      await _tapBoard(tester);
      await _done(tester);
      expect(_banner(tester), step.line);
    }
    await _tapBoard(tester);
    await _done(tester);
    expect(_banner(tester), day);
  });

  testWidgets('a tap plays the next step; a tap while one plays finishes it; '
      'a swipe left is the next and right the one before', (tester) async {
    final night = await _open(tester, recordedResults('results'));
    await _tapScrap(tester, EndCopy.whatHappened);
    await _done(tester);
    await _tapBoard(tester);
    expect(night.step, 1);
    expect(night.clock.isAnimating, isTrue);
    await tester.pump(const Duration(milliseconds: 50));
    await _tapBoard(tester);
    expect(night.step, 1, reason: 'the tap finished the step, no more');
    expect(night.clock.value, 1);
    await tester.fling(find.byType(EndBoardWindow), const Offset(-200, 0), 800);
    await _done(tester);
    expect(night.step, 2);
    await tester.fling(find.byType(EndBoardWindow), const Offset(200, 0), 800);
    await tester.pump();
    expect(night.step, 1);
    expect(night.clock.value, 1, reason: 'the step before, shown done');
    // Nothing advances by itself.
    await tester.pump(const Duration(seconds: 30));
    expect(night.step, 1);
  });

  testWidgets('after the last step a tap is back at the result, pixel for '
      'pixel; the scrap too; nothing vibrated', (tester) async {
    final night = await _open(tester, recordedResults('results'));
    await _loadPictures(tester);
    await _done(tester);
    final before = await _picture(tester);
    await _tapScrap(tester, EndCopy.whatHappened);
    await _loadPictures(tester);
    for (var i = 0; i < night.story!.steps.length; i++) {
      await _done(tester);
      await _tapBoard(tester);
    }
    await _done(tester);
    expect(night.step, night.story!.steps.length);
    await _tapBoard(tester);
    expect(night.on, isFalse);
    await _done(tester);
    expect(_off(before, await _picture(tester)), isEmpty);
    // Left mid-step by the scrap.
    await _tapScrap(tester, EndCopy.whatHappened);
    await _done(tester);
    await _tapBoard(tester);
    await tester.pump(const Duration(milliseconds: 60));
    await _tapScrap(tester, EndCopy.backToResult);
    expect(night.on, isFalse);
    await _done(tester);
    expect(_off(before, await _picture(tester)), isEmpty);
    expect(_buzzes, isEmpty);
  });

  testWidgets('each step\'s line is read out as it comes, and is a screen '
      'reader\'s way on', (tester) async {
    final handle = tester.ensureSemantics();
    final night = await _open(tester, recordedResults('results_doppelganger'));
    await _tapScrap(tester, EndCopy.whatHappened);
    await _done(tester);
    final lines = [StoryCopy.dealt, ...night.story!.steps.map((s) => s.line)];
    for (final line in lines) {
      final node = tester.getSemantics(find.bySemanticsLabel(line).last);
      expect(node.flagsCollection.isLiveRegion, isTrue, reason: line);
      expect(node.getSemanticsData().hasAction(SemanticsAction.tap), isTrue);
      if (line != lines.last) {
        tester.semantics.tap(find.semantics.byLabel(line).first);
        await _done(tester);
      }
    }
    expect(find.bySemanticsLabel(EndCopy.backToResult), findsOneWidget);
    handle.dispose();
  });

  testWidgets('reduce motion: every change is a cut, a step a tap', (
    tester,
  ) async {
    final night = await _open(
      tester,
      recordedResults('results'),
      reduceMotion: true,
    );
    await _tapScrap(tester, EndCopy.whatHappened);
    expect(night.clock.value, 1);
    await _tapBoard(tester);
    expect(night.step, 1);
    expect(night.clock.value, 1);
  });

  testWidgets('during a step the paper that holds still is not painted '
      'again: the sky, the roof, the frame and the foot\'s plaque', (
    tester,
  ) async {
    final painted = <RenderObject, int>{};
    final night = await _open(tester, recordedResults('results'));
    await _tapScrap(tester, EndCopy.whatHappened);
    await _done(tester);
    debugOnProfilePaint = (o) =>
        painted.update(o, (n) => n + 1, ifAbsent: () => 1);
    List<RenderObject> under(Type type) => [
      for (final e in find.byType(type).evaluate())
        for (final d
            in find
                .descendant(
                  of: find.byWidget(e.widget),
                  matching: find.byWidgetPredicate((_) => true),
                )
                .evaluate())
          if (d.renderObject != null) d.renderObject!,
    ];
    final still = {
      for (final type in [LayeredArt, BoardRoof, BoardFrame, PrimaryButton])
        type: under(type),
    };
    for (final MapEntry(key: type, value: objects) in still.entries) {
      expect(objects, isNotEmpty, reason: '$type is on the board');
    }
    await _tapBoard(tester);
    await tester.pump(const Duration(milliseconds: 17));
    final before = {
      for (final o in still.values.expand((x) => x)) o: painted[o] ?? 0,
    };
    var frames = 0;
    while (night.clock.isAnimating) {
      await tester.pump(const Duration(milliseconds: 17));
      frames++;
    }
    final again = [
      for (final MapEntry(key: type, value: objects) in still.entries)
        for (final o in objects)
          if ((painted[o] ?? 0) != before[o]) '$type: $o',
    ];
    debugOnProfilePaint = null;
    expect(frames, greaterThan(10));
    expect(again, isEmpty, reason: 'repainted during a step');
  });

  testWidgets('the Doppelganger\'s card shows the deal, then the role it '
      'copied, saying Doppelganger', (tester) async {
    final night = await _open(tester, recordedResults('results_doppelganger'));
    await _tapScrap(tester, EndCopy.whatHappened);
    BoardCard ana() => tester
        .widgetList<BoardCard>(_nightCards)
        .lastWhere((c) => c.name == 'Ana');
    await _done(tester);
    expect(ana().role, RoleId.doppelganger);
    await _tapBoard(tester);
    await _done(tester);
    expect(night.current!.kind, StoryKind.copy);
    expect(ana().role, RoleId.seer);
    expect(ana().strip, RoleId.doppelganger.displayName);
  });

  testWidgets('the same results fetched again change nothing: the night '
      'stays at its step', (tester) async {
    final night = await _open(tester, recordedResults('results'));
    await _tapScrap(tester, EndCopy.whatHappened);
    await _done(tester);
    await _tapBoard(tester);
    await _done(tester);
    await _tapBoard(tester);
    await _done(tester);
    expect(night.step, 2);
    // A new object from the same body, as a refetch brings.
    await pumpEndBoardOn(tester, recordedResults('results'));
    await _done(tester);
    expect(night.on, isTrue);
    expect(night.step, 2);
  });

  testWidgets('at night "Play again" and "Edit deck" take a real touch', (
    tester,
  ) async {
    var played = 0, edited = 0;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpEndBoardOn(
      tester,
      recordedResults('results'),
      onPlayAgain: () => played++,
      onEditDeck: () => edited++,
    );
    await _tapScrap(tester, EndCopy.whatHappened);
    await _done(tester);
    await _tapBoard(tester);
    for (final label in [EndCopy.playAgain, EndCopy.editDeck]) {
      final at = tester.getCenter(find.text(label).first);
      final finger = await tester.startGesture(at);
      await tester.pump(const Duration(milliseconds: 80));
      await finger.up();
      await tester.pump();
    }
    expect(played, 1);
    expect(edited, 1);
  });

  testWidgets('the first time, "Go on" until the first tap, and never again '
      'once taught', (tester) async {
    var taught = 0;
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpEndBoardOn(
      tester,
      recordedResults('results'),
      onStepTaught: () => taught++,
    );
    expect(find.text(StoryCopy.goOn), findsNothing, reason: 'not by day');
    await _tapScrap(tester, EndCopy.whatHappened);
    await _done(tester);
    expect(find.text(StoryCopy.goOn), findsOneWidget);
    await _tapBoard(tester);
    expect(find.text(StoryCopy.goOn), findsNothing);
    await _tapBoard(tester);
    await _tapBoard(tester);
    expect(taught, 1);
    // Taught on this device: never shown.
    await tester.pumpWidget(const SizedBox());
    await pumpEndBoardOn(
      tester,
      recordedResults('results_five'),
      stepTaught: true,
    );
    await _tapScrap(tester, EndCopy.whatHappened);
    await _done(tester);
    expect(find.text(StoryCopy.goOn), findsNothing);
  });

  testWidgets('the moon rises between the sky plate and the roofs', (
    tester,
  ) async {
    await _open(tester, recordedResults('results'));
    await _tapScrap(tester, EndCopy.whatHappened);
    await _done(tester);
    expect(
      find.descendant(
        of: find.byType(LayeredArt),
        matching: find.byType(NightMoon),
      ),
      findsOneWidget,
    );
  });
}
