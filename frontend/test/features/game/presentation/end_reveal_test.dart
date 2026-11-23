import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/copy/copy.dart';
import 'package:midnight_village/design_system/primitives/death_mark.dart';
import 'package:midnight_village/design_system/primitives/end_lantern.dart';
import 'package:midnight_village/design_system/primitives/layered_art.dart';
import 'package:midnight_village/design_system/primitives/primary_button.dart';
import 'package:midnight_village/design_system/primitives/sliced_art.dart';
import 'package:midnight_village/features/game/domain/end_reveal.dart';
import 'package:midnight_village/design_system/primitives/board_pieces.dart';
import 'package:midnight_village/features/game/presentation/end/end_reveal.dart';

import '../../../helpers/end_board_pump.dart';
import '../../../helpers/outcome_samples.dart';

// The end board's reveal on a fake clock (docs/specs/frontend/end-board.md,
// section 8; the timeline itself is end_reveal_test.dart in domain/): each
// beat at its time, a touch settles it in one frame, the controls work from
// the first, reduce motion and a late open get the settled board, exactly one
// vibration (none for a card turning), and the paper that holds still is
// painted once while the reveal runs.

late List<String> _buzzes;

Future<EndRevealDriver?> _pump(
  WidgetTester tester,
  String sample, {
  bool reveal = true,
  bool reduceMotion = false,
  VoidCallback? onPlayAgain,
  Size screen = const Size(390, 844),
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
    recordedResults(sample),
    reveal: reveal,
    reduceMotion: reduceMotion,
    onPlayAgain: onPlayAgain,
  );
  return _driver(tester);
}

EndRevealDriver? _driver(WidgetTester tester) =>
    tester.widget<EndRevealScope>(find.byType(EndRevealScope)).driver;

Finder get _backs => find.byType(BoardCardBack);
Finder get _stamp => find.byType(InkStamp);

/// Whether [e] is painted now: no reveal piece above it is at opacity 0 (the
/// reveal keeps both sides of a card built, and paints one).
bool _painted(Element e) {
  var painted = true;
  e.visitAncestorElements((a) {
    final w = a.widget;
    if (w is RevealPaint && (w.opacity?.call() ?? 1) <= 0) painted = false;
    return painted;
  });
  return painted;
}

/// How many of [f] are painted now.
int _seen(Finder f) => f.evaluate().where(_painted).length;

/// Plays the clock on to [t] from where it stands.
Future<void> _to(WidgetTester tester, Duration t) async {
  final now = _driver(tester)!.now;
  if (t > now) await tester.pump(t - now);
}

void main() {
  testWidgets('one hanged: face down, then up big, stamped with the knock, '
      'then every card turned and the board settled', (tester) async {
    final driver = (await _pump(tester, 'results_moved_dead_card'))!;
    final r = driver.reveal!;
    // Frame one: every card face down in place (and the three in the middle),
    // the banner not yet out.
    final cards =
        (recordedResults('results_moved_dead_card')['players'] as List).length;
    expect(_seen(_backs), cards + 3);
    expect(_seen(_stamp), 0);
    expect(_buzzes, isEmpty);

    // The hanged card up, big and face up; nothing stamped yet.
    await _to(tester, r.of(RevealBeat.lift)!.end);
    expect(find.byType(RevealHanged), findsOneWidget);
    expect(_seen(_backs), cards + 3 - 1, reason: 'the hanged is face up');
    expect(_seen(_stamp), 0);

    // The stamp lands: the one knock, a thud.
    await _to(tester, r.knockAt);
    expect(_seen(_stamp), 1);
    expect(_buzzes, ['HapticFeedbackType.mediumImpact']);

    // The rows turn while the hanged goes back; then all settles.
    await _to(tester, r.of(RevealBeat.drop)!.end);
    expect(_seen(_backs), lessThan(cards + 2));
    await _to(tester, r.total);
    await tester.pump(const Duration(milliseconds: 17));
    expect(_driver(tester), isNull, reason: 'settled');
    expect(_backs, findsNothing);
    expect(_stamp, findsNothing);
    expect(_buzzes, hasLength(1), reason: 'no vibration on a card turning');
  });

  testWidgets('a touch anywhere settles the board in one frame, with the one '
      'knock if it had not come', (tester) async {
    await _pump(tester, 'results_moved_dead_card');
    await tester.pump(const Duration(milliseconds: 500));
    expect(_seen(_backs), greaterThan(0));
    await tester.tapAt(const Offset(195, 400));
    await tester.pump();
    expect(_driver(tester), isNull);
    expect(_backs, findsNothing);
    expect(_buzzes, ['HapticFeedbackType.mediumImpact']);
    await tester.pump(const Duration(seconds: 3));
    expect(_buzzes, hasLength(1));
  });

  testWidgets('Play again works at frame one', (tester) async {
    var played = 0;
    await _pump(tester, 'results_moved_dead_card', onPlayAgain: () => played++);
    expect(find.byType(PrimaryButton), findsOneWidget);
    await tester.tap(find.text(EndCopy.playAgain));
    await tester.pump();
    expect(played, 1);
    expect(_driver(tester), isNull, reason: 'the touch settled it too');
  });

  testWidgets('reduce motion: the settled board at frame one, faded in, and '
      'the one knock', (tester) async {
    await _pump(tester, 'results_moved_dead_card', reduceMotion: true);
    expect(_driver(tester), isNull);
    expect(_backs, findsNothing);
    await tester.pump();
    expect(_buzzes, ['HapticFeedbackType.mediumImpact']);
    await tester.pumpAndSettle();
    expect(_buzzes, hasLength(1));
  });

  testWidgets('opened late (no reveal): settled, nothing moves or vibrates', (
    tester,
  ) async {
    await _pump(tester, 'results_moved_dead_card', reveal: false);
    expect(_driver(tester), isNull);
    expect(_backs, findsNothing);
    await tester.pumpAndSettle();
    expect(_buzzes, isEmpty);
  });

  testWidgets('nobody hanged: nothing lifts or is stamped; the light knock as '
      'the banner unrolls', (tester) async {
    final r = (await _pump(tester, 'results_nobody_dies'))!.reveal!;
    expect(find.byType(RevealHanged), findsNothing);
    for (
      var t = Duration.zero;
      t < r.total;
      t += const Duration(milliseconds: 50)
    ) {
      await _to(tester, t);
      expect(_seen(_stamp), 0);
      if (t < r.knockAt) expect(_buzzes, isEmpty);
    }
    await _to(tester, r.total);
    await tester.pump(const Duration(milliseconds: 17));
    expect(_buzzes, ['HapticFeedbackType.lightImpact']);
  });

  testWidgets('the banner unrolls from its middle: nothing of it at the start, '
      'all of it once the beat is over', (tester) async {
    final r = (await _pump(tester, 'results_moved_dead_card'))!.reveal!;
    ClipRect clip() => tester.widget<ClipRect>(
      find
          .ancestor(
            of: find.byType(BannerSlice),
            matching: find.byType(ClipRect),
          )
          .first,
    );
    final size = tester.getSize(find.byType(BannerSlice));
    expect(clip().clipper!.getClip(size).width, 0);
    await _to(tester, r.of(RevealBeat.banner)!.end);
    expect(clip().clipper!.getClip(size).width, closeTo(size.width, 0.5));
  });

  testWidgets('ten players on a short phone: the board stands at the top, then '
      'scrolls to the hanged before they lift', (tester) async {
    _buzzes = [];
    tester.view.physicalSize = const Size(360, 640);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await pumpEndBoardOn(
      tester,
      widened(
        recordedResults('results_doppelganger'),
        add: 2,
        rename: longEndNames,
      ),
      reveal: true,
    );
    final r = _driver(tester)!.reveal!;
    final scrollable = find.byType(Scrollable);
    double offset() =>
        tester.state<ScrollableState>(scrollable).position.pixels;
    expect(offset(), 0);
    expect(r.scrollTo, greaterThan(0));
    await _to(tester, r.of(RevealBeat.lift)!.start);
    expect(offset(), closeTo(r.scrollTo, 0.5));
    await tester.tapAt(const Offset(180, 300));
    await tester.pump();
    expect(
      offset(),
      closeTo(r.scrollTo, 0.5),
      reason: 'settled where it opens',
    );
  });

  testWidgets('while the reveal runs, the paper that holds still is painted '
      'once: the sky, the roof, the frame, the lantern and the foot', (
    tester,
  ) async {
    final painted = <RenderObject, int>{};
    debugOnProfilePaint = (o) =>
        painted.update(o, (n) => n + 1, ifAbsent: () => 1);
    final r = (await _pump(tester, 'results_moved_dead_card'))!.reveal!;
    await tester.pump(const Duration(milliseconds: 17));
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
      for (final type in [
        LayeredArt,
        BoardRoof,
        BoardFrame,
        EndLantern,
        PrimaryButton,
      ])
        type: under(type),
    };
    for (final MapEntry(key: type, value: objects) in still.entries) {
      expect(objects, isNotEmpty, reason: '$type is on the board');
    }
    final before = {
      for (final o in still.values.expand((x) => x)) o: painted[o] ?? 0,
    };
    var frames = 0;
    // Every beat: the lift, the stamp, the banner, the drop, the rows, the
    // tags, a frame each 17 ms.
    for (
      var t = const Duration(milliseconds: 34);
      t < r.total;
      t += const Duration(milliseconds: 17)
    ) {
      await _to(tester, t);
      frames++;
    }
    final again = [
      for (final MapEntry(key: type, value: objects) in still.entries)
        for (final o in objects)
          if ((painted[o] ?? 0) != before[o]) '$type: $o',
    ];
    debugOnProfilePaint = null;
    expect(frames, greaterThan(80));
    expect(again, isEmpty, reason: 'repainted during the reveal');
  });

  testWidgets('settled, the reveal is the static board, pixel for pixel', (
    tester,
  ) async {
    Future<List<int>> picture({required bool reveal}) async {
      await _pump(tester, 'results_moved_dead_card', reveal: reveal);
      final images = [
        for (final e in find.byType(Image).evaluate())
          ((e.widget as Image).image, e),
      ];
      await tester.runAsync(
        () => Future.wait([for (final (p, e) in images) precacheImage(p, e)]),
      );
      if (reveal) await tester.pump(const Duration(seconds: 3));
      await tester.pump();
      expect(_driver(tester), isNull);
      final bytes = await tester.runAsync(() async {
        final image = await captureImage(tester.binding.rootElement!);
        final data = await image.toByteData();
        image.dispose();
        return data!.buffer.asUint8List().toList();
      });
      await tester.pumpWidget(const SizedBox());
      return bytes!;
    }

    final settled = await picture(reveal: true);
    final still = await picture(reveal: false);
    expect(settled.length, still.length);
    expect(settled, still);
  });
}
