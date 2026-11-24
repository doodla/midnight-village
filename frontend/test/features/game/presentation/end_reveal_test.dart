import 'package:flutter/rendering.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/copy/copy.dart';
import 'package:midnight_village/design_system/primitives/board_pieces.dart';
import 'package:midnight_village/design_system/primitives/death_mark.dart';
import 'package:midnight_village/design_system/primitives/end_lantern.dart';
import 'package:midnight_village/design_system/primitives/layered_art.dart';
import 'package:midnight_village/design_system/primitives/primary_button.dart';
import 'package:midnight_village/design_system/primitives/sliced_art.dart';
import 'package:midnight_village/features/game/domain/end_reveal.dart';
import 'package:midnight_village/features/game/domain/game_outcome.dart';
import 'package:midnight_village/features/game/presentation/end/end_board_view.dart';
import 'package:midnight_village/features/game/presentation/end/end_cards.dart';
import 'package:midnight_village/features/game/presentation/end/end_reveal.dart';

import '../../../../test_screens/end_board_pages.dart' show endTen;
import '../../../../test_screens/reading_floor.dart';
import '../../../helpers/end_board_pump.dart';
import '../../../helpers/outcome_samples.dart';
import '../../../helpers/finger.dart';

// The end board's reveal on a fake clock (docs/specs/frontend/end-board.md,
// section 8; the timeline itself is end_reveal_test.dart in domain/): each
// beat at its time, a real touch settles it and still reaches the control
// under it, reduce motion and a late open get the settled board, a knock per
// stamp (none for a card turning), nothing below the reading floor at any
// frame, every back one size on screen at frame one, and the paper that holds
// still is painted once while the reveal runs.

late List<String> _buzzes;

const _thud = 'HapticFeedbackType.mediumImpact';

Future<EndRevealDriver?> _pump(
  WidgetTester tester,
  String sample, {
  bool reveal = true,
  bool reduceMotion = false,
  VoidCallback? onPlayAgain,
  Size screen = const Size(390, 844),
  Map<String, dynamic>? results,
}) async {
  _listen(tester);
  tester.view.physicalSize = screen;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await pumpEndBoardOn(
    tester,
    results ?? recordedResults(sample),
    reveal: reveal,
    reduceMotion: reduceMotion,
    onPlayAgain: onPlayAgain,
  );
  return _driver(tester);
}

void _listen(WidgetTester tester) {
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

/// How large [e]'s render box is drawn on the screen, untilted: its size times
/// the scale of every transform on the way (the reveal's paint-time ones too).
Size _onScreen(Element e) {
  final box = e.renderObject! as RenderBox;
  final m = box.getTransformTo(null).storage;
  return Size(
    box.size.width * Offset(m[0], m[1]).distance,
    box.size.height * Offset(m[4], m[5]).distance,
  );
}

/// The twin of the dead card [id].
RevealHanged _twin(WidgetTester tester, int id) => tester
    .widgetList<RevealHanged>(find.byType(RevealHanged))
    .firstWhere((w) => w.card.id == id);

/// Where the twin of [id] is drawn: its turning card, under its own moving
/// paint.
Size _twinOnScreen(WidgetTester tester, int id) => _onScreen(
  find
      .descendant(
        of: find.byWidget(_twin(tester, id)),
        matching: find.byType(RevealTurn),
      )
      .evaluate()
      .first,
);

/// A real finger: down, a frame (the touch settles the board, which builds
/// again), then up.
Future<void> _press(WidgetTester tester, Finder target) async {
  final gesture = await tester.startGesture(tester.getCenter(target));
  await tester.pump();
  await tester.pump(const Duration(milliseconds: 50));
  await gesture.up();
  await tester.pump();
}

void main() {
  testWidgets('one hanged: face down, then up big, stamped with the knock, '
      'then every card turned and the board settled', (tester) async {
    final driver = (await _pump(tester, 'results_moved_dead_card'))!;
    final r = driver.reveal!;
    // Frame one: every card face down in place (and the three in the middle),
    // the banner still furled.
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

    // The stamp lands: the knock, a thud.
    await _to(tester, r.knocks.single);
    expect(_seen(_stamp), 1);
    expect(_buzzes, [_thud]);

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

  testWidgets('the Hunter: two deaths, two beats, a knock as each stamp '
      'lands, and the second is smaller on screen', (tester) async {
    final r = (await _pump(tester, 'results'))!.reveal!;
    expect(r.knocks, hasLength(2));
    final sizes = <double>[];
    for (final (i, k) in r.knocks.indexed) {
      await _to(tester, k);
      expect(_buzzes, List.filled(i + 1, _thud));
      // Only this death is up, its stamp the one painted.
      expect(_seen(_stamp), 1);
      expect(_driver(tester)!.isUp(r.dead[i]), isTrue);
      expect(_driver(tester)!.isUp(r.dead[1 - i]), isFalse);
      sizes.add(_twinOnScreen(tester, r.dead[i]).width);
    }
    expect(sizes.last, lessThan(sizes.first));
    await _to(tester, r.total);
    expect(_buzzes, hasLength(2));
  });

  testWidgets('a touch anywhere settles the board in one frame, with the one '
      'knock if it had not come', (tester) async {
    await _pump(tester, 'results_moved_dead_card');
    await tester.pump(const Duration(milliseconds: 300));
    expect(_seen(_backs), greaterThan(0));
    await pressAtLikeAFinger(tester, const Offset(195, 400));
    await tester.pump();
    expect(_driver(tester), isNull);
    expect(_backs, findsNothing);
    expect(_buzzes, [_thud]);
    await tester.pump(const Duration(seconds: 3));
    expect(_buzzes, hasLength(1));
  });

  // A real finger: down, frames, up. The touch-down settles the board and it
  // builds again before the finger lifts; the control under it must still be
  // the one that was touched (`tester.tap` pumps no frame between down and
  // up, so it could not see a control rebuilt under the finger).
  for (final at in const [Duration.zero, Duration(milliseconds: 900)]) {
    testWidgets('Play again works with a real finger at '
        '${at.inMilliseconds} ms of the reveal', (tester) async {
      var played = 0;
      await _pump(
        tester,
        'results_moved_dead_card',
        onPlayAgain: () => played++,
      );
      if (at > Duration.zero) await tester.pump(at);
      expect(_driver(tester), isNotNull);
      await _press(tester, find.text(EndCopy.playAgain));
      expect(played, 1);
      expect(_driver(tester), isNull, reason: 'the touch settled it too');
    });
  }

  testWidgets('nothing on the board is drawn below the reading floor at any '
      'frame of any reveal: names stay at their size', (tester) async {
    for (final (name, results) in [
      ('one hanged', recordedResults('results_moved_dead_card')),
      ('the Hunter', recordedResults('results')),
      ('nobody', recordedResults('results_nobody_dies')),
      ('a tie', recordedResults('results_tie')),
      ('ten', endTen()),
    ]) {
      await _pump(tester, '', results: results);
      final r = _driver(tester)!.reveal!;
      for (
        var t = Duration.zero;
        t < r.total;
        t += const Duration(milliseconds: 17)
      ) {
        await _to(tester, t);
        expect(
          readingFloorBreaches(tester),
          isEmpty,
          reason: '$name at ${t.inMilliseconds} ms',
        );
      }
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('the guard sees the reveal\'s paint-time transforms', (
    tester,
  ) async {
    final r = (await _pump(tester, 'results_moved_dead_card'))!.reveal!;
    await _to(tester, r.knocks.single);
    final id = r.dead.single;
    final drawn = _twinOnScreen(tester, id);
    // The twin is laid out at its slot and drawn big: what the screen shows.
    expect(drawn.width, closeTo(r.big[id]!.width, 1));
  });

  testWidgets('frame one: every back has one portrait size on the screen, the '
      'hanged one too', (tester) async {
    for (final sample in [
      'results_moved_dead_card',
      'results',
      'results_tie',
    ]) {
      await _pump(tester, sample);
      final portraits = [
        for (final e in _backs.evaluate().where(_painted))
          for (final p
              in find
                  .descendant(
                    of: find.byWidget(e.widget),
                    matching: find.byType(ClipRRect),
                  )
                  .evaluate())
            _onScreen(p),
      ];
      final board = portraits.where((p) => p.width > 50).toList();
      expect(board, isNotEmpty);
      for (final p in board) {
        expect(p.width, closeTo(board.first.width, 0.5), reason: sample);
        expect(p.height, closeTo(board.first.height, 0.5), reason: sample);
      }
      await tester.pumpWidget(const SizedBox());
    }
  });

  testWidgets('the stamp lands under the face and over no word, on every '
      'death of every sample, at 360 and 390', (tester) async {
    for (final screen in const [Size(360, 780), Size(390, 844)]) {
      for (final sample in [
        'results_moved_dead_card',
        'results',
        'results_tie',
        'results_tanner_alone',
      ]) {
        final r = (await _pump(tester, sample, screen: screen))!.reveal!;
        for (final id in r.dead) {
          await _to(tester, r.of(RevealBeat.stamp, card: id)!.end);
          final stamp = _stamp.evaluate().where(_painted).single;
          final plate = tester.getSize(
            find
                .descendant(
                  of: find.byElementPredicate((e) => e == stamp),
                  matching: find.byType(DecoratedBox),
                )
                .first,
          );
          final big = r.big[id]!, up = r.up[id]!;
          final s = big.width / up.width;
          final card = _twin(tester, id).card;
          final portrait = Rect.fromLTWH(
            big.left + BoardCard.inset * s,
            big.top + card.header * s,
            big.width - 2 * BoardCard.inset * s,
            (big.width - 2 * BoardCard.inset * s) * 3 / 4,
          );
          final tabBottom = big.bottom - BoardCard.stripUp * s;
          expect(
            DeathMark.stampFits(big, portrait, plate, tabBottom: tabBottom),
            isTrue,
            reason:
                '$sample at $screen: a plate of $plate on $big, face line '
                '${portrait.top + DeathMark.faceShare * portrait.height}, tab foot $tabBottom',
          );
        }
        await tester.pumpWidget(const SizedBox());
      }
    }
  });

  testWidgets('reduce motion: the settled board at frame one, faded in, and '
      'the one knock', (tester) async {
    await _pump(tester, 'results_moved_dead_card', reduceMotion: true);
    expect(_driver(tester), isNull);
    expect(_backs, findsNothing);
    await tester.pump();
    expect(_buzzes, [_thud]);
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
      if (t < r.knocks.single) expect(_buzzes, isEmpty);
    }
    await _to(tester, r.total);
    await tester.pump(const Duration(milliseconds: 17));
    expect(_buzzes, ['HapticFeedbackType.lightImpact']);
  });

  testWidgets('the banner is furled at the start and unrolls once: nothing of '
      'it at the start, all of it once its beat is over', (tester) async {
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
    expect(clip().clipper!.getClip(size).bottom, 0);
    await _to(tester, r.of(RevealBeat.banner)!.end);
    expect(clip().clipper!.getClip(size).bottom, closeTo(size.height, 0.5));
  });

  testWidgets('ten players on a short phone: the board stands where it opens '
      'from frame one, and settles there', (tester) async {
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
    expect(r.scroll, greaterThan(0));
    expect(offset(), closeTo(r.scroll, 0.5));
    await _to(tester, r.of(RevealBeat.lift)!.start);
    expect(offset(), closeTo(r.scroll, 0.5));
    await pressAtLikeAFinger(tester, const Offset(180, 300));
    await tester.pump();
    expect(offset(), closeTo(r.scroll, 0.5), reason: 'settled where it opens');
  });

  testWidgets('a new payload on the same phone is planned again: the board '
      'shows the new players, not a stale plan', (tester) async {
    int you() => tester
        .widgetList<EndCardView>(find.byType(EndCardView))
        .singleWhere((v) => v.card.you)
        .card
        .id;
    await _pump(tester, 'results_moved_dead_card', reveal: false);
    final first = GameOutcome.fromJson(
      recordedResults('results_moved_dead_card'),
    );
    expect(you(), first.seats.first.id);
    // The same board seen by another player: the seal moves.
    await pumpEndBoardOn(
      tester,
      recordedResults('results_moved_dead_card'),
      viewer: 1,
      host: false,
    );
    expect(find.byType(EndBoardView), findsOneWidget);
    expect(you(), first.seats[1].id);
    // Another game's results: its own players.
    final next = recordedResults('results_nobody_dies');
    await pumpEndBoardOn(tester, next, viewer: 2);
    final names = {
      for (final v in tester.widgetList<EndCardView>(find.byType(EndCardView)))
        v.card.name,
    };
    expect(names, {for (final s in GameOutcome.fromJson(next).seats) s.name});
    expect(you(), GameOutcome.fromJson(next).seats[2].id);
  });

  testWidgets('a board planned again mid-reveal and then removed in the same '
      'frame settles nothing after it is gone', (tester) async {
    await _pump(tester, 'results_moved_dead_card');
    await tester.pump(const Duration(milliseconds: 200));
    // A turned phone plans the board again: it settles after the frame ...
    tester.view.physicalSize = const Size(360, 780);
    await tester.pump();
    // ... but the board is already gone by then.
    await tester.pumpWidget(const SizedBox());
    await tester.pump();
    expect(tester.takeException(), isNull);
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
