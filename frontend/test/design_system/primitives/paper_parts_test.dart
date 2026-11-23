import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/primitives/deckle.dart';
import 'package:midnight_village/design_system/primitives/deckled_paper.dart';
import 'package:midnight_village/design_system/primitives/fanned.dart';
import 'package:midnight_village/design_system/primitives/mood.dart';
import 'package:midnight_village/design_system/primitives/paper_banner.dart';
import 'package:midnight_village/design_system/primitives/paper_light.dart';
import 'package:midnight_village/design_system/primitives/paper_mark.dart';
import 'package:midnight_village/design_system/primitives/paper_pin.dart';
import 'package:midnight_village/design_system/primitives/plaque.dart';
import 'package:midnight_village/design_system/primitives/primary_button.dart';
import 'package:midnight_village/design_system/primitives/role_card.dart';
import 'package:midnight_village/design_system/primitives/role_sheet_body.dart';
import 'package:midnight_village/design_system/primitives/screen_frame.dart';
import 'package:midnight_village/design_system/primitives/tilted_paper.dart';
import 'package:midnight_village/design_system/skin/dress.dart';
import 'package:midnight_village/design_system/skin/elevation.dart';
import 'package:midnight_village/design_system/skin/ground.dart';
import 'package:midnight_village/design_system/skin/ground_scope.dart';
import 'package:midnight_village/design_system/skin/skin.dart';
import 'package:midnight_village/design_system/skin/skin_theme.dart';
import 'package:midnight_village/design_system/skin/skin_tilt.dart';

import '../../helpers/pump_skinned.dart';
import '../../helpers/sheet/table_pages.dart';

// The dress switch and every paper part: a screen is plain (exactly today's
// look) unless it asks for `Dress.paper`; each part draws only there, and is
// paint-only (no layout box or hit target moves).

Future<void> _pump(WidgetTester tester, Widget child, {Dress? dress}) =>
    pumpSkinned(
      tester,
      dress == null ? child : DressScope(dress: dress, child: child),
    );

Skin get _skin => skinsUnderTest.values.first;

void main() {
  group('the switch', () {
    testWidgets('a screen is plain unless it asks, and says so to its parts', (
      tester,
    ) async {
      Dress? seen;
      await _pump(
        tester,
        ScreenFrame(
          ground: GroundKind.night,
          body: Builder(
            builder: (context) {
              seen = context.dress;
              return const SizedBox();
            },
          ),
        ),
      );
      expect(seen, Dress.plain);
      expect(find.byType(Mood), findsNothing);
      expect(find.byType(PaperLight), findsNothing);
    });

    testWidgets('ScreenFrame(dress: paper) dresses it: mood, one light, a '
        'dressed skin below', (tester) async {
      Skin? seen;
      await _pump(
        tester,
        ScreenFrame(
          ground: GroundKind.night,
          dress: Dress.paper,
          body: Builder(
            builder: (context) {
              seen = context.skin;
              return const SizedBox();
            },
          ),
        ),
      );
      expect(seen!.dress, Dress.paper);
      expect(seen, same(_skin.dressedUp));
      expect(find.byType(Mood), findsOneWidget);
      expect(find.byType(PaperLight), findsOneWidget);
    });

    testWidgets('a frame inherits the dress of a scope above it (a preview)', (
      tester,
    ) async {
      await _pump(
        tester,
        const ScreenFrame(ground: GroundKind.night, body: SizedBox()),
        dress: Dress.paper,
      );
      expect(find.byType(Mood), findsOneWidget);
    });

    test('the plain skin is the look today: hard shadows, no tilt, own '
        'corners; the dressed one tilts and casts paper shadows', () {
      final plain = _skin;
      final dressed = plain.dressedUp!;
      expect(plain.dress, Dress.plain);
      expect(plain.tilt.seededCard, 0);
      expect(plain.tilt.seededRow, 0);
      for (final g in [plain.night, plain.day, plain.paper]) {
        for (final layer in g.elevation.card.layers) {
          expect(layer.drop, isFalse);
        }
      }
      expect(dressed.tilt.seededCard, greaterThan(0));
      expect(dressed.night.elevation.card.layers.single.drop, isTrue);
      expect(dressed.shape.radius, isNot(plain.shape.radius));
    });
  });

  group('every part draws nothing on a plain screen', () {
    testWidgets('pin, banner, mark corner, fan, plaque-free primary button', (
      tester,
    ) async {
      await _pump(
        tester,
        Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const PaperPin(ink: Color(0xFF000000)),
            PaperBanner(child: (_) => const Text('Banner')),
            const PaperMarkCorner(shown: true, child: SizedBox(width: 20)),
            const Fanned(index: 0, count: 3, child: SizedBox(width: 20)),
            const PrimaryButton(label: 'Go', onPressed: _noop),
          ],
        ),
      );
      expect(tester.getSize(find.byType(PaperPin)), Size.zero);
      expect(find.byType(PaperMark), findsNothing);
      expect(find.byType(Plaque), findsNothing);
      expect(find.byType(DeckleBorder), findsNothing);
      // The banner is its words and nothing round them.
      expect(
        find.descendant(
          of: find.byType(PaperBanner),
          matching: find.byType(Stack),
        ),
        findsNothing,
      );
      expect(find.text('Banner'), findsOneWidget);
    });

    testWidgets('deckledPaper is the cut paper it always was', (tester) async {
      Decoration? made;
      await _pump(
        tester,
        Builder(
          builder: (context) {
            made = deckledPaper(context, fill: Colors.white, id: #x);
            return const SizedBox();
          },
        ),
      );
      expect(made, isA<BoxDecoration>());
    });
  });

  group('dressed up', () {
    testWidgets('deckledPaper is torn, seeded by its id, the same every time '
        'and different for another id', (tester) async {
      final made = <Decoration>[];
      await _pump(
        tester,
        Builder(
          builder: (context) {
            made
              ..add(deckledPaper(context, fill: Colors.white, id: #a))
              ..add(deckledPaper(context, fill: Colors.white, id: #a))
              ..add(deckledPaper(context, fill: Colors.white, id: #b));
            return const SizedBox();
          },
        ),
        dress: Dress.paper,
      );
      // The probe sits under no frame: the dress is the scope's.
      final shapes = [for (final d in made) (d as ShapeDecoration).shape];
      expect(shapes[0], shapes[1]);
      expect(shapes[0], isNot(shapes[2]));
    });

    test('a deckled edge is paint only: no layout inset, a closed path', () {
      const border = DeckleBorder(seed: 7);
      expect(border.dimensions, EdgeInsets.zero);
      final rect = const Rect.fromLTWH(0, 0, 120, 40);
      final path = border.getOuterPath(rect);
      expect(rect.inflate(1).contains(path.getBounds().topLeft), isTrue);
      expect(rect.inflate(1).contains(path.getBounds().bottomRight), isTrue);
    });

    testWidgets('a pin takes its size and its colour from the skin', (
      tester,
    ) async {
      await _pump(
        tester,
        const PaperPin(ink: Color(0xFF123456)),
        dress: Dress.paper,
      );
      expect(
        tester.getSize(find.byType(PaperPin)),
        Size.square(_skin.dressedUp!.parts.pinSize),
      );
    });

    testWidgets('a banner is torn paper with two pins, its words level and in '
        'the day ink', (tester) async {
      await _pump(
        tester,
        SizedBox(
          width: 300,
          child: PaperBanner(
            child: (context) =>
                Text('Who?', style: TextStyle(color: context.ground.text)),
          ),
        ),
        dress: Dress.paper,
      );
      expect(find.byType(PaperPin), findsNWidgets(2));
      final text = tester.widget<Text>(find.text('Who?'));
      expect(text.style!.color, _skin.dressedUp!.day.text);
      // The words are not under the tilt.
      expect(
        find.ancestor(of: find.text('Who?'), matching: find.byType(Transform)),
        findsNothing,
      );
    });

    testWidgets('tilted paper turns the paper, never what is on it: the child '
        'keeps its place and its hit target', (tester) async {
      var taps = 0;
      await _pump(
        tester,
        GestureDetector(
          onTap: () => taps++,
          child: const TiltedPaper(
            angle: 0.1,
            decoration: BoxDecoration(color: Colors.white),
            child: SizedBox(width: 100, height: 40, child: Text('Tap')),
          ),
        ),
      );
      expect(tester.getSize(find.byType(TiltedPaper)), const Size(100, 40));
      expect(
        tester.getTopLeft(find.text('Tap')),
        tester.getTopLeft(find.byType(TiltedPaper)),
      );
      await tester.tapAt(
        tester.getRect(find.byType(TiltedPaper)).topLeft + const Offset(2, 2),
      );
      expect(taps, 1);
    });

    test('a tilt is seeded by the id: the same on every build, within the '
        'skin\'s own angle, and not always the same', () {
      final tilt = _skin.dressedUp!.tilt;
      final angles = {
        for (final id in ['a', 'b', 'c', 'd', 'e', 'f'])
          tilt.angle(Tilt.seededCard(id)),
      };
      expect(angles.length, greaterThan(2));
      for (final a in angles) {
        expect(a.abs(), lessThanOrEqualTo(tilt.seededCard));
      }
      expect(tilt.angle(Tilt.seededRow('x')), tilt.angle(Tilt.seededRow('x')));
    });

    testWidgets('the primary button is a plaque, its words level, and still '
        'one amber fill', (tester) async {
      await _pump(
        tester,
        const PrimaryButton(label: 'Go', onPressed: _noop),
        dress: Dress.paper,
      );
      expect(find.byType(Plaque), findsOneWidget);
      expect(find.byType(DeckleBorder), findsNothing); // a shape, not a widget
    });

    testWidgets('the done mark is the paper\'s own, not a stock tick', (
      tester,
    ) async {
      await _pump(
        tester,
        const PrimaryButton.done(label: 'Ready'),
        dress: Dress.paper,
      );
      expect(find.byType(PaperMark), findsOneWidget);
      expect(find.byIcon(Icons.check), findsNothing);
    });
  });

  group('the paper shadow and the one light', () {
    test('a drop is a contact shadow and a cast, no blur, the cast leaning '
        'away from the light', () {
      final plain = PaperShadow.of(const Offset(0, 8), const Color(0xFF000000));
      expect(plain.last.offset.dy, lessThan(plain.first.offset.dy + 8));
      for (final s in plain) {
        expect(s.blurRadius, 0);
      }
      const drop = Elevation([
        HardShadow.drop(Offset(0, 8), Color(0xFF000000)),
      ]);
      final straight = drop.boxShadowsLeaning(0);
      final left = drop.boxShadowsLeaning(-0.5);
      expect(left.first.offset.dx, lessThan(straight.first.offset.dx));
      // An edge, the paper's thickness, never leans.
      const edge = Elevation([
        HardShadow.edge(Offset(0, 5), Color(0xFF000000)),
      ]);
      expect(edge.boxShadowsLeaning(-0.5).single.offset, const Offset(0, 5));
    });

    test('a plain layer is the hard copy of today', () {
      const hard = Elevation([HardShadow(Offset(3, 3), Color(0xFF000000))]);
      final shadows = hard.boxShadowsLeaning(-0.5);
      expect(shadows, hasLength(1));
      expect(shadows.single.offset, const Offset(3, 3));
    });
  });

  group('the fan', () {
    testWidgets('tilt and scale are paint only: tapping each card of an '
        'overlapping fan opens that card\'s role', (tester) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      Future<void> table() async {
        await tester.pumpWidget(const SizedBox());
        await tester.pumpWidget(
          ProviderScope(
            child: MaterialApp(
              theme: skinTheme(_skin),
              builder: (context, child) =>
                  GroundScope(ground: GroundKind.night, child: child!),
              home: const TablePage(dress: Dress.paper),
            ),
          ),
        );
        await tester.pump();
      }

      await table();
      final cards = find.byType(Fanned).evaluate().length;
      expect(cards, greaterThan(2));
      for (var i = 0; i < cards; i++) {
        await table();
        final fanned = find.byType(Fanned).at(i);
        final role = tester
            .widget<RoleCard>(
              find.descendant(of: fanned, matching: find.byType(RoleCard)),
            )
            .role;
        // The card's own untransformed slot is its hit area, however far its
        // neighbours' turned paper reaches into it.
        final slot = tester.getRect(
          find.ancestor(of: fanned, matching: find.byType(Flexible)).first,
        );
        // Its corners too, where the turned paper of a neighbour (or its own)
        // has moved away from the slot.
        for (final at in [
          slot.center,
          slot.topLeft + const Offset(3, 3),
          slot.topRight + const Offset(-3, 3),
        ]) {
          await table();
          await tester.tapAt(at);
          await tester.pumpAndSettle();
          final sheet = tester.widget<RoleSheetBody>(
            find.byType(RoleSheetBody),
          );
          expect(sheet.role, role, reason: 'card $i at $at');
        }
      }
    });

    testWidgets('a Fanned card moves only its paint: its box and its hits are '
        'its slot\'s', (tester) async {
      await _pump(
        tester,
        Row(
          children: [
            for (var i = 0; i < 3; i++)
              SizedBox(
                width: 60,
                height: 90,
                child: Fanned(
                  index: i,
                  count: 3,
                  child: GestureDetector(
                    key: ValueKey(i),
                    onTap: () => _taps.add(i),
                    child: const ColoredBox(color: Colors.white),
                  ),
                ),
              ),
          ],
        ),
        dress: Dress.paper,
      );
      _taps.clear();
      for (var i = 0; i < 3; i++) {
        final slot = tester.getRect(
          find
              .ancestor(
                of: find.byKey(ValueKey(i)),
                matching: find.byType(SizedBox),
              )
              .first,
        );
        // The slot's two top corners, where a neighbour's enlarged paper and
        // the turned card's own bared corner meet.
        for (final at in [
          slot.topLeft + const Offset(1.5, 3),
          slot.topRight + const Offset(-1.5, 3),
          slot.center,
        ]) {
          await tester.tapAt(at);
          expect(_taps.last, i, reason: 'slot $i at $at');
        }
      }
      expect(_taps.toSet(), {0, 1, 2});
    });
  });

  test('every dressed colour is the skin\'s: the part files hold no colour '
      'literal of their own beyond the shadow\'s ink', () {
    // Sizes, angles and colours come from `skin.parts` / `skin.mood`: this
    // names the one struct, so a part that grows a number of its own has a
    // place to put it.
    final parts = _skin.dressedUp!.parts;
    expect(parts.pinSize, greaterThan(0));
    expect(parts.bannerAngle.abs(), lessThan(math.pi / 8));
  });
}

final _taps = <int>[];

void _noop() {}
