import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/copy/copy.dart';
import 'package:midnight_village/design_system/night/board_layout.dart';
import 'package:midnight_village/design_system/night/night_board.dart';
import 'package:midnight_village/design_system/night/night_pick.dart';
import 'package:midnight_village/design_system/primitives/candle_gauge.dart';
import 'package:midnight_village/design_system/primitives/face_down_card.dart';
import 'package:midnight_village/design_system/primitives/paper_card.dart';
import 'package:midnight_village/design_system/primitives/primary_button.dart';
import 'package:midnight_village/design_system/primitives/screen_frame.dart';
import 'package:midnight_village/design_system/primitives/world_timer.dart';
import 'package:midnight_village/design_system/primitives/layered_art.dart';
import 'package:midnight_village/design_system/skin/art_set.dart';
import 'package:midnight_village/design_system/skin/ground.dart';
import 'package:midnight_village/design_system/skin/ground_scope.dart';
import 'package:midnight_village/design_system/skin/skin_theme.dart';

import '../../helpers/component_sheet.dart';
import '../../helpers/frame_pixels.dart';
import '../../helpers/pump_skinned.dart';
import '../../helpers/sheet/night_pages.dart';
import '../../helpers/sheet/sheet_data.dart';

// The night board's composition (polish pass 2): the cards use the height the
// phone gives them, so there is no dead band at any table from 3 to 10 on any
// phone, the same for every role; and the quiet village behind the title
// keeps the title readable.

/// What a gap on the board may hold beyond what the design puts in it (the
/// Seer's label room above the seats, the rule above the band, a row gap
/// between the rows), in logical pixels. More is a dead band. At three
/// seats there are only two cards to a row, as wide as the phone allows, so
/// a tall phone keeps some air.
double _tolerance(int seats) => seats == 3 ? 72 : 40;

/// What the design itself puts in the gap under the title and in the one
/// above the band (a label line and its gap, the rule's room), at the
/// board's largest text.
const _designed = 40.0;

const _phones = [
  Size(320, 568),
  Size(320, 692),
  Size(360, 640),
  Size(360, 779),
  Size(390, 844),
  Size(393, 852),
];

Map<String, dynamic> _table(int seats) {
  final me = Viewer.drunk.nightMe;
  final others = [
    for (final seat in NightSeat.seatsOf(me))
      if (seat.id != selfIn(me)) seat.name,
  ];
  return tableOf(
    me,
    leave: {...others.take(9 - seats.clamp(1, 9))},
    add: seats > 9 ? seats - 9 : 0,
  );
}

Future<void> _pump(WidgetTester tester, Widget page) async {
  await tester.pumpWidget(
    ProviderScope(
      overrides: learnedOverrides(ComponentPage.action.learned),
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: skinTheme(skinsUnderTest.values.first),
        builder: (context, child) =>
            GroundScope(ground: GroundKind.night, child: child!),
        home: page,
      ),
    ),
  );
  await tester.pump();
}

/// The seats' cards as rows: each row's top and bottom, top to bottom.
List<(double, double)> _rows(WidgetTester tester) {
  final rows = <double, double>{};
  for (final element in find.byType(FaceDownCard).evaluate()) {
    final card = element.widget as FaceDownCard;
    if (card.ownerName == null || card.ownerName == NightCopy.you) continue;
    final rect = tester.getRect(find.byWidget(card));
    final top = rect.top.roundToDouble();
    rows[top] = math.max(rows[top] ?? 0, rect.bottom);
  }
  return [for (final top in rows.keys.toList()..sort()) (top, rows[top]!)];
}

double _luminance(int pixel) {
  double lin(int c) {
    final v = c / 255;
    return v <= 0.03928 ? v / 12.92 : math.pow((v + 0.055) / 1.055, 2.4) * 1.0;
  }

  return 0.2126 * lin(FramePixels.red(pixel)) +
      0.7152 * lin(FramePixels.green(pixel)) +
      0.0722 * lin(FramePixels.blue(pixel));
}

void main() {
  for (final phone in _phones) {
    for (final scale in const [1.0, 2.0]) {
      testWidgets('no dead band on a ${phone.width.round()} x '
          '${phone.height.round()} phone, text x$scale: every gap holds what '
          'the design puts in it and at most 40 px more (72 at three seats), 3 to 10 '
          'seats', (tester) async {
        tester.view.physicalSize = phone;
        tester.view.devicePixelRatio = 1;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        addTearDown(tester.view.reset);
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);

        final findings = <String>[];
        for (var seats = 3; seats <= 10; seats++) {
          await tester.pumpWidget(const SizedBox());
          await _pump(
            tester,
            BoardPage(
              viewer: Viewer.drunk,
              table: (_) => _table(seats),
              textScale: scale,
            ),
          );
          final where =
              '$seats seats on ${phone.width.round()} x ${phone.height.round()} x$scale';
          final header = tester.getRect(
            find
                .ancestor(
                  of: find.byType(WorldTimer),
                  matching: find.byType(Row),
                )
                .first,
          );
          final band = tester.getRect(find.byType(PaperCard));
          final rows = _rows(tester);
          // The gaps of the board, top to bottom: the header to the first
          // row, row to row, the last row to the band of cards.
          final gaps = [
            rows.first.$1 - header.bottom,
            for (var i = 1; i < rows.length; i++) rows[i].$1 - rows[i - 1].$2,
            band.top - rows.last.$2,
          ];
          // Cards already at the smallest the board draws (ten seats, or
          // large text on a small phone) cannot grow into what is left: no
          // split of that table fills it.
          final smallest =
              (tester.widget(
                        find
                            .byWidgetPredicate(
                              (w) =>
                                  w is FaceDownCard &&
                                  w.ownerName != null &&
                                  w.ownerName != NightCopy.you,
                            )
                            .first,
                      )
                      as FaceDownCard)
                  .cardWidth!;
          if (smallest <= BoardLayout.smallest + 4) continue;
          for (final (i, gap) in gaps.indexed) {
            final room = i == 0 || i == gaps.length - 1
                ? _designed
                : BoardLayout.rowGap;
            if (gap > room + _tolerance(seats)) {
              findings.add(
                '$where: a ${gap.toStringAsFixed(0)} px band in gap $i of '
                '${gaps.length}',
              );
            }
          }
          final error = tester.takeException();
          if (error != null) findings.add('$where: $error');
        }
        expect(findings, isEmpty);
      });
    }
  }

  testWidgets('the cards grow to the height a small table is given, up to '
      'the largest, and a full table keeps its size', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);

    Future<double> seatCard(int seats) async {
      await tester.pumpWidget(const SizedBox());
      await _pump(
        tester,
        BoardPage(viewer: Viewer.drunk, table: (_) => _table(seats)),
      );
      final seat = find
          .byWidgetPredicate(
            (w) =>
                w is FaceDownCard &&
                w.ownerName != null &&
                w.ownerName != NightCopy.you,
          )
          .first;
      return (tester.widget(seat) as FaceDownCard).cardWidth!;
    }

    final three = await seatCard(3);
    final five = await seatCard(5);
    final ten = await seatCard(10);
    expect(three, BoardLayout.largest);
    expect(
      three,
      greaterThan(FaceDownSize.board.mock.width),
      reason: 'a small table is no longer drawn at the full table’s size',
    );
    expect(five, greaterThanOrEqualTo(FaceDownSize.board.mock.width));
    expect(ten, lessThanOrEqualTo(FaceDownSize.board.mock.width));
    expect(three, greaterThan(five));
    expect(five, greaterThan(ten));
  });

  testWidgets('a role changes nothing about the composition: a Seer, a '
      'sleeper and a Robber at three seats have the same cards in the same '
      'places', (tester) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    final layouts = <List<Rect>>[];
    for (final viewer in [Viewer.seer, Viewer.villager, Viewer.robber]) {
      await tester.pumpWidget(const SizedBox());
      await _pump(
        tester,
        BoardPage(
          viewer: viewer,
          table: (me) => tableOf(
            me,
            leave: {
              ...[
                for (final seat in NightSeat.seatsOf(me))
                  if (seat.id != selfIn(me)) seat.name,
              ].skip(2),
            },
          ),
        ),
      );
      layouts.add([
        for (final element in find.byType(FaceDownCard).evaluate())
          tester.getRect(find.byWidget(element.widget)),
        tester.getRect(find.byType(PaperCard)),
        tester.getRect(find.byType(PrimaryButton)),
      ]);
    }
    expect(layouts[1], layouts[0]);
    expect(layouts[2], layouts[0]);
  });

  testWidgets('the tap targets stay 48 or more in every state on the '
      'smallest phone with ten seats: the button waiting, ready and done', (
    tester,
  ) async {
    tester.view.physicalSize = const Size(320, 568);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await _pump(
      tester,
      BoardPage(viewer: Viewer.drunk, table: (_) => _table(10)),
    );
    double height() => tester.getSize(find.byType(PrimaryButton)).height;
    double narrowest() => [
      for (final element in find.byType(FaceDownCard).evaluate())
        tester.getSize(find.byWidget(element.widget)).width,
    ].reduce(math.min);
    expect(height(), greaterThanOrEqualTo(48), reason: 'waiting');
    expect(narrowest(), greaterThanOrEqualTo(BoardLayout.minTap - 0.5));
    await tester.tap(find.text('Left'));
    await tester.pump();
    expect(height(), greaterThanOrEqualTo(48), reason: 'ready');
    await tester.tap(find.byType(PrimaryButton));
    await tester.pump();
    expect(height(), greaterThanOrEqualTo(48), reason: 'done');
  });

  group('the village behind the title', () {
    testWidgets('is the night village, cropped to a strip, on every board', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      for (final viewer in [Viewer.seer, Viewer.villager]) {
        await tester.pumpWidget(const SizedBox());
        await _pump(tester, BoardPage(viewer: viewer));
        final frame = tester.widget<ScreenFrame>(find.byType(ScreenFrame));
        expect(frame.topScene, LayeredSceneId.nightVillage);
        expect(frame.topSceneFrom, NightBoard.villageFrom);
        expect(frame.topArtLayout, TopArtLayout.strip, reason: viewer.name);
      }
    });

    testWidgets('at a table of three on a tall phone the strip takes some of '
        'the air; at any other table or a short phone it does not, and the '
        'cards stay where they are', (tester) async {
      Future<(double, Rect)> board(Size phone, int seats) async {
        tester.view.physicalSize = phone;
        tester.view.devicePixelRatio = 1;
        await tester.pumpWidget(const SizedBox());
        await _pump(
          tester,
          BoardPage(viewer: Viewer.drunk, table: (_) => _table(seats)),
        );
        final frame = tester.widget<ScreenFrame>(find.byType(ScreenFrame));
        return (frame.topArtExtra, tester.getRect(find.byType(PaperCard)));
      }

      addTearDown(tester.view.reset);
      final (tall, _) = await board(const Size(390, 844), 3);
      expect(tall, greaterThan(40));
      expect(tall, lessThanOrEqualTo(NightBoard.stripMost));
      expect((await board(const Size(390, 844), 4)).$1, 0);
      expect((await board(const Size(390, 844), 10)).$1, 0);
      expect((await board(const Size(320, 568), 3)).$1, 0);
    });

    testWidgets('the candle and the number are one unit inside the page '
        'margin: the candle’s right edge is on the button’s, whole at every '
        'state', (tester) async {
      for (final phone in const [Size(390, 844), Size(320, 568)]) {
        tester.view.physicalSize = phone;
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        for (final (seconds, share) in const [
          (30, 1.0),
          (188, 1.0),
          (0, 0.0),
        ]) {
          await tester.pumpWidget(const SizedBox());
          await _pump(
            tester,
            BoardPage(viewer: Viewer.drunk, secondsLeft: seconds, share: share),
          );
          final candle = tester.getRect(find.byType(CandleGauge));
          final button = tester.getRect(find.byType(PrimaryButton));
          expect(candle.right, closeTo(button.right, 0.5), reason: '$phone');
          // The handle, the ledge and the dish's shadow are all inside the
          // page: nothing runs on to the phone's edge.
          final holder = tester.getRect(
            find.byKey(const ValueKey(CandlePart.holder)),
          );
          expect(holder.right, lessThanOrEqualTo(button.right + 0.5));
          expect(
            tester.getRect(find.byKey(const ValueKey(CandlePart.ledge))).right,
            lessThanOrEqualTo(button.right + 0.5),
          );
        }
      }
    });

    testWidgets('the candle takes no room of the board’s: the header is the '
        'title’s two lines whatever the candle’s height', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await _pump(tester, BoardPage(viewer: Viewer.seer));
      final header = tester.getRect(
        find
            .ancestor(of: find.byType(WorldTimer), matching: find.byType(Row))
            .first,
      );
      // Two lines of the title at its size (34 x 1.05) and the hair.
      expect(header.height, closeTo(34 * 1.05 * 2 + 1, 0.6));
      final candle = tester.getRect(find.byType(CandleGauge));
      expect(
        candle.height,
        greaterThan(header.height),
        reason: 'it stands above and below the title’s room',
      );
    });

    test('starts below the moon whatever the status bar adds', () {
      final scene = skinsUnderTest.values.first.art.layeredScene(
        LayeredSceneId.nightVillage,
      );
      for (final safeTop in [0.0, 24.0, 47.0, 59.0]) {
        final box = Size(390, TopArtLayout.strip.height + safeTop);
        final focus = LayeredArt.focusFrom(scene, box, NightBoard.villageFrom);
        final geometry = SceneGeometry.cover(
          LayeredScene(
            folder: scene.folder,
            canvas: scene.canvas,
            focus: focus,
            layers: scene.layers,
          ),
          box,
        );
        // Canvas row [villageFrom] is the top of the box.
        expect(
          geometry.point(Offset(0, NightBoard.villageFrom)).dy,
          closeTo(0, 1),
          reason: '$safeTop',
        );
      }
    });

    testWidgets('keeps the title at 7:1 or more over the picture', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await _pump(tester, BoardPage(viewer: Viewer.seer));
      await tester.runAsync(
        () => Future.wait([
          for (final element in find.byType(Image).evaluate())
            precacheImage((element.widget as Image).image, element),
        ]),
      );
      await tester.pump();
      final title = tester.getRect(find.text('Look at cards'));
      final frame = await FramePixels.of(tester);
      // The brightest of the picture in the rows just above and below the
      // words, as far across as the title is wide: what the words sit on.
      var worst = 0.0;
      for (var x = 4.0; x < title.right + 20; x += 3) {
        for (final y in [title.top - 8, title.bottom + 8]) {
          worst = math.max(worst, _luminance(frame.at(x, y)));
        }
      }
      final bone = _luminance(0xFFE9E2D0);
      expect(
        (bone + 0.05) / (worst + 0.05),
        greaterThanOrEqualTo(7),
        reason: 'the brightest of the picture behind the title',
      );
    });
  });
}
