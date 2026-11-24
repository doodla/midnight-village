// Guard file: a change here needs its line in the pull request (tool/guard_edits.py).
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/core/router/back_policy.dart';
import 'package:midnight_village/design_system/copy/copy.dart';
import 'package:midnight_village/design_system/primitives/deckle.dart';
import 'package:midnight_village/design_system/primitives/primary_button.dart';
import 'package:midnight_village/design_system/primitives/secondary_button.dart';
import 'package:midnight_village/design_system/primitives/deck_pile.dart';
import 'package:midnight_village/design_system/primitives/sheet_scaffold.dart';
import 'package:midnight_village/design_system/primitives/screen_frame.dart';
import 'package:midnight_village/design_system/primitives/mood.dart';
import 'package:midnight_village/design_system/primitives/paper_light.dart';
import 'package:midnight_village/design_system/skin/mood_palette.dart';
import 'package:midnight_village/design_system/primitives/paper_piece.dart';
import 'package:midnight_village/design_system/primitives/role_card.dart';
import 'package:midnight_village/design_system/primitives/text_backing.dart';
import 'package:midnight_village/design_system/primitives/tilted_paper.dart';
import 'package:midnight_village/design_system/skin/dress.dart';
import 'package:midnight_village/design_system/skin/dress_style.dart';
import 'package:midnight_village/design_system/skin/ground.dart';
import 'package:midnight_village/design_system/skin/ground_scope.dart';
import 'package:midnight_village/design_system/skin/skin.dart';
import 'package:midnight_village/design_system/skin/skin_theme.dart';

import '../../../test_screens/shell_fixtures.dart';
import '../../../test_screens/table_fixtures.dart'
    show pumpJoinCode, pumpJoinCodeOpen, pumpJoinFresh;
import '../../helpers/component_sheet.dart';
import '../../helpers/parts_catalogue.dart';
import '../../helpers/pump_skinned.dart';
import '../../helpers/sheet/day_pages.dart';
import '../../helpers/sheet/night_pages.dart';
import '../../helpers/sheet/sheet_data.dart';
import '../../helpers/sheet/table_pages.dart';

// The rules that keep paper one material, each over every paper screen and
// every component in every state it has:
//  1. SHADOW: every piece's shadow falls away from the screen's one light
//     (down, and sideways the way `PaperLight` leans), and none is an all-round
//     halo (no spread).
//  2. SEPARATION: a piece stands off what it lies on (a ground, or the piece
//     under it) by 1.25:1 in luminance AND casts a shadow; words on a piece
//     meet 4.5:1.
//  3. MATERIAL: a component's pressed, picked, locked and focused states are
//     the same paper piece as its rest (same kind, tear and grain and a
//     shadow); only the colour may change.

const _phone = Size(390, 844);

Future<void> _screen(WidgetTester tester, Widget home) => tester.pumpWidget(
  ProviderScope(
    overrides: learnedOverrides(ComponentPage.action.learned),
    child: MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: skinTheme(skinsUnderTest.values.first),
      builder: (context, child) =>
          GroundScope(ground: GroundKind.night, child: child!),
      home: home,
    ),
  ),
);

void _size(WidgetTester tester, [Size size = _phone]) {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
}

Future<void> _settle(WidgetTester tester) async {
  await tester.pump(const Duration(milliseconds: 900));
  await tester.pump(const Duration(milliseconds: 900));
}

/// The paper screens (the owner's twelve findings were found on these), each
/// built as the live app has it.
final Map<String, Future<void> Function(WidgetTester)> paperScreens = {
  'table, host': (t) async {
    await _screen(t, const TablePage());
    await _settle(t);
  },
  'table, guest': (t) async {
    await _screen(t, const TablePage(guest: true));
    await _settle(t);
  },
  '01, a new phone (Start the plaque)': (t) async {
    _size(t);
    await pumpJoinFresh(t);
    // The keyboard down: no caret handle (the platform's) on screen.
    FocusManager.instance.primaryFocus?.unfocus();
    await _settle(t);
  },
  '01, the code open (Join locked)': (t) async {
    _size(t);
    await pumpJoinCodeOpen(t);
    // The keyboard down: no caret handle (the platform's) on screen.
    FocusManager.instance.primaryFocus?.unfocus();
    await _settle(t);
  },
  '01, a code typed (Join the plaque)': (t) async {
    _size(t);
    await pumpJoinCode(t);
    // The keyboard down: no caret handle (the platform's) on screen.
    FocusManager.instance.primaryFocus?.unfocus();
    await _settle(t);
  },
  'card back': (t) async {
    await pumpYourCard(t);
    await _settle(t);
  },
  'card face': (t) async {
    await pumpYourCardHeld(t);
    await _settle(t);
  },
  'night board, 5': (t) async {
    await _screen(
      t,
      BoardPage(
        viewer: Viewer.seer,
        table: (me) => tableOf(me, leave: {dev.name, esme.name}),
      ),
    );
    await _settle(t);
  },
  'night board, 10': (t) async {
    await _screen(
      t,
      BoardPage(
        viewer: Viewer.drunk,
        table: (me) => tableOf(me, add: 1, rename: longNames),
      ),
    );
    await _settle(t);
  },
  'vote': (t) async {
    await _screen(t, const VotePage());
    await _settle(t);
  },
  'vote, locked': (t) async {
    await _screen(t, VotePage(me: recordedMe('me_voting_locked')));
    await _settle(t);
  },
  'deck page': (t) async {
    await _screen(t, const DeckPage());
    await _settle(t);
  },
  'card-details sheet': (t) async {
    await _screen(t, const TablePage());
    await _settle(t);
    await t.tap(find.byType(RoleCard).first);
    await t.pump(const Duration(milliseconds: 600));
    await _settle(t);
  },
  'deck page, card sheet': (t) async {
    await _screen(t, const DeckPage());
    await _settle(t);
    await t.longPress(find.byType(RoleCard).first);
    await t.pump(const Duration(milliseconds: 600));
    await _settle(t);
  },
};

/// Every sheet and dialog a paper screen can open, opened the way a player
/// opens it (a tap, a hold, Back) on the real screen: each is listed with the
/// source file that opens it, and a new opener in `lib/` fails
/// `every opener in lib/ is walked` until it is added here.
final Map<
  String,
  ({String file, MoodKind light, Future<void> Function(WidgetTester) open})
>
paperSheets = {
  'table (host): a card\'s sheet': (
    file: 'features/lobby/presentation/at_table_parts.dart',
    light: MoodKind.lantern,
    open: (t) async {
      await _screen(t, const TablePage());
      await _settle(t);
      await t.tap(find.byType(RoleCard).first);
      await t.pump(const Duration(milliseconds: 600));
    },
  ),
  'table (host): Leave asks first': (
    file: 'features/lobby/presentation/at_table_view.dart',
    light: MoodKind.lantern,
    open: (t) async {
      await _screen(t, const TablePage());
      await _settle(t);
      await t.tap(find.text(CommonCopy.leave));
      await t.pump(const Duration(milliseconds: 600));
    },
  ),
  'table (guest): Back asks first': (
    file: 'features/lobby/presentation/at_table_view.dart',
    light: MoodKind.lantern,
    open: (t) async {
      await _screen(
        t,
        const BackPolicy(
          rule: BackRule.staysPut,
          child: TablePage(guest: true),
        ),
      );
      await _settle(t);
      await t.binding.handlePopRoute();
      await t.pump(const Duration(milliseconds: 600));
    },
  ),
  'talk: a pile\'s sheet': (
    file: 'features/game/presentation/shell/talk_square.dart',
    light: MoodKind.night,
    open: (t) async {
      await _screen(t, const TalkPage(viewer: Viewer.seer));
      await _settle(t);
      await t.longPress(find.byType(DeckPile).first);
      await t.pump(const Duration(milliseconds: 600));
    },
  ),
  'deck page: a card\'s sheet': (
    file: 'features/lobby/presentation/deck_parts.dart',
    light: MoodKind.night,
    open: (t) async {
      await _screen(t, const DeckPage());
      await _settle(t);
      await t.longPress(find.byType(RoleCard).first);
      await t.pump(const Duration(milliseconds: 600));
    },
  ),
};

/// The openers of sheets and dialogs on screens that are plain today (the
/// owner has not asked for those): they open as the screen is, plain.
const plainOpeners = <String>{};

/// Every shadow a decorated box on screen casts that is not a blurred glow,
/// with the screen's lean at that place.
List<String> shadowFaults(WidgetTester tester) {
  final faults = <String>[];
  for (final element in tester.allElements) {
    final widget = element.widget;
    if (widget is! DecoratedBox) continue;
    final decoration = widget.decoration;
    final shadows = switch (decoration) {
      BoxDecoration(:final boxShadow) => boxShadow,
      ShapeDecoration(:final shadows) => shadows,
      _ => null,
    };
    if (shadows == null || shadows.isEmpty) continue;
    final light = element.getElementForInheritedWidgetOfExactType<PaperLight>();
    final lean = (light?.widget as PaperLight?)?.lean ?? 0;
    for (final s in shadows) {
      if (s.blurRadius > 0 || s.color.a == 0) continue;
      final o = s.offset;
      final where =
          '${widget.runtimeType} ${s.offset} spread ${s.spreadRadius}';
      if (s.spreadRadius > 0.5) {
        faults.add('halo (spread): $where');
      } else if (o.dy <= 0) {
        faults.add('does not fall down: $where');
      } else if (lean == 0 ? o.dx.abs() > 0.01 : o.dx * lean <= 0) {
        faults.add('falls toward the light (lean $lean): $where');
      }
    }
  }
  return faults;
}

/// One paper piece on screen: its part, where it is, its paper, what it casts.
class PaperPieceFacts {
  PaperPieceFacts(
    this.part,
    this.rect,
    this.fill,
    this.shadowed,
    this.shape,
    this.words,
  );

  final PaperPart part;
  final Rect rect;
  final Color fill;
  final bool shadowed;
  final ShapeBorder? shape;
  final List<Color> words;

  @override
  String toString() => '$part at $rect';
}

/// Every opaque paper-coloured surface on screen (a piece, a row, a card): what
/// a piece may lie on.
List<PaperPieceFacts> surfacesOf(WidgetTester tester) {
  final out = <PaperPieceFacts>[];
  for (final e in tester.allElements.where(_shown)) {
    final w = e.widget;
    if (w is! DecoratedBox) continue;
    final d = w.decoration;
    final colour = switch (d) {
      ShapeDecoration(:final color) => color,
      BoxDecoration(:final color) => color,
      _ => null,
    };
    final render = e.renderObject;
    if (colour == null || colour.a < 0.95) continue;
    if (render is! RenderBox || !render.hasSize || !render.attached) continue;
    out.add(
      PaperPieceFacts(
        PaperPart.panel,
        render.localToGlobal(Offset.zero) & render.size,
        colour,
        false,
        null,
        const [],
      ),
    );
  }
  return out;
}

/// On the route that is on top: what a sheet covers (behind its scrim) lies on
/// nothing the sheet is.
bool _shown(Element e) => ModalRoute.of(e)?.isCurrent ?? true;

List<PaperPieceFacts> piecesOf(WidgetTester tester) {
  final pieces = <PaperPieceFacts>[];
  for (final element in tester.allElements.where(
    (e) => e.widget is PaperPiece && _shown(e),
  )) {
    final piece = element.widget as PaperPiece;
    final render = element.renderObject;
    if (render is! RenderBox || !render.hasSize || !render.attached) continue;
    final paper = find.descendant(
      of: find.byWidget(piece),
      matching: find.byType(TiltedPaper),
    );
    if (paper.evaluate().isEmpty) continue;
    final decoration = tester.widget<TiltedPaper>(paper.first).decoration;
    if (decoration is! ShapeDecoration || decoration.color == null) continue;
    final words = <Color>[];
    void visit(Element e) {
      final w = e.widget;
      // A piece laid on this one holds its own words.
      if (w is PaperPiece) return;
      // A name plate's words lie on its own plate (a sibling of the words),
      // not on the piece the plate is laid on.
      if (w is TextBacking) return;
      if (w is Text && w.data != null) {
        final style = DefaultTextStyle.of(e).style.merge(w.style);
        if (style.color != null) words.add(style.color!);
      } else if (w is RichText) {
        final c = w.text.style?.color;
        if (c != null) words.add(c);
      }
      e.visitChildren(visit);
    }

    element.visitChildren(visit);
    pieces.add(
      PaperPieceFacts(
        piece.part,
        render.localToGlobal(Offset.zero) & render.size,
        decoration.color!,
        (decoration.shadows ?? const []).isNotEmpty,
        decoration.shape,
        words,
      ),
    );
  }
  return pieces;
}

double contrast(Color a, Color b) {
  final la = a.computeLuminance();
  final lb = b.computeLuminance();
  return (la > lb ? la + 0.05 : lb + 0.05) / (la > lb ? lb + 0.05 : la + 0.05);
}

/// The faults of [pieces] lying on [ground]: a piece that does not stand off
/// what is under it, has no shadow, or whose words are under 4.5:1.
List<String> separationFaults(
  List<PaperPieceFacts> pieces,
  Color ground,
  List<PaperPieceFacts> surfaces,
) {
  final faults = <String>[];
  for (final p in pieces) {
    // The smallest other piece that holds this one is what it lies on.
    final under = surfaces
        .where(
          (o) =>
              o != p &&
              o.rect.inflate(1).contains(p.rect.center) &&
              // Larger than the piece (its own paper is the same size).
              (o.rect.width > p.rect.width + 2 ||
                  o.rect.height > p.rect.height + 2),
        )
        .fold<PaperPieceFacts?>(
          null,
          (best, o) =>
              best == null ||
                  o.rect.width * o.rect.height <
                      best.rect.width * best.rect.height
              ? o
              : best,
        );
    final on = under?.fill ?? ground;
    final ratio = contrast(p.fill, on);
    if (ratio < 1.25) {
      faults.add('$p is ${ratio.toStringAsFixed(2)}:1 on ${under ?? 'ground'}');
    }
    if (!p.shadowed) faults.add('$p casts no shadow');
    for (final w in p.words) {
      final r = contrast(w, p.fill);
      if (r < 4.5) faults.add('$p words ${r.toStringAsFixed(2)}:1');
    }
  }
  return faults;
}

String _signature(PaperPieceFacts piece) {
  final s = piece.shape;
  final shape = s is DeckleBorder
      ? 'deckle ${s.depth} ${s.step} ${s.round} ${s.blob}'
      : '$s';
  return '${piece.part.name} $shape';
}

/// A paper screen's own light (the lean its pieces cast by) and the sheet's.
double _lean(WidgetTester tester, Finder at) =>
    PaperLight.of(tester.element(at.first));

void main() {
  group('sheets and dialogs come up in paper, lit as their screen is', () {
    for (final entry in paperSheets.entries) {
      testWidgets(entry.key, (tester) async {
        _size(tester);
        await entry.value.open(tester);
        await tester.pump(const Duration(milliseconds: 600));
        final sheet = find.byType(SheetScaffold);
        expect(sheet, findsOneWidget, reason: 'the sheet did not open');
        final inside = tester.element(sheet);
        expect(inside.dress, Dress.paper, reason: 'the sheet is plain');
        // The screen's own light: a sheet is lit from where its screen is.
        final screen = _lean(tester, find.byType(PaperPiece));
        // And it is the light the screen stands in (the deck page's moon throws
        // left, the table's lantern straight down), not the default's.
        expect(
          screen,
          Mood.leanOf(entry.value.light, const MoodPalette()),
          reason: 'the screen\'s light',
        );
        expect(
          PaperLight.of(inside),
          screen,
          reason: 'the sheet is lit as plain',
        );
        expect(inside.ground.paper, isNotNull);
      });
    }

    test('every opener in lib/ is walked', () {
      final found = <String>{};
      final call = RegExp(
        r'\b(showSkinSheet|showSkinDialog|showRoleSheet)\s*[(<]',
      );
      for (final f in Directory('lib').listSync(recursive: true)) {
        if (f is! File || !f.path.endsWith('.dart')) continue;
        final path = f.path.replaceFirst('lib/', '');
        // The openers themselves.
        if (path == 'design_system/primitives/sheet_scaffold.dart') continue;
        for (final line in f.readAsLinesSync()) {
          final code = line.trimLeft();
          if (code.startsWith('//')) continue;
          // A definition is not an opener.
          if (code.startsWith('Future<') && !code.contains('=>')) continue;
          if (call.hasMatch(line) &&
              !code.startsWith('Future<void> showRoleSheet')) {
            found.add(path);
          }
        }
      }
      final walked = {for (final e in paperSheets.values) e.file}
        ..addAll(plainOpeners);
      expect(
        found.difference(walked),
        isEmpty,
        reason:
            'a screen opens a sheet or dialog that no test opens: add it to '
            '`paperSheets` (a paper screen) or `plainOpeners` (a plain one)',
      );
      expect(walked.difference(found), isEmpty, reason: 'listed, not opened');
    });

    testWidgets('a sheet opened from outside the frame is refused', (
      tester,
    ) async {
      await tester.pumpWidget(
        MaterialApp(
          home: Builder(
            builder: (context) => TextButton(
              onPressed: () => showSkinSheet<void>(
                context,
                builder: (_) => const SizedBox(),
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      expect(tester.takeException(), isA<AssertionError>());
      expect(FrameMark.under(tester.element(find.text('open'))), isFalse);
    });
  });

  group('one light: every shadow falls away from it', () {
    for (final entry in paperScreens.entries) {
      testWidgets(entry.key, (tester) async {
        _size(tester);
        await entry.value(tester);
        expect(shadowFaults(tester), isEmpty);
      });
    }

    testWidgets('the check sees a halo and a shadow cast toward the light', (
      tester,
    ) async {
      _size(tester);
      await tester.pumpWidget(
        PaperLight(
          lean: -0.5,
          child: Column(
            children: [
              DecoratedBox(
                decoration: BoxDecoration(
                  boxShadow: [
                    BoxShadow(offset: const Offset(0, 4), spreadRadius: 6),
                  ],
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  boxShadow: [BoxShadow(offset: const Offset(3, 4))],
                ),
              ),
              DecoratedBox(
                decoration: BoxDecoration(
                  boxShadow: [BoxShadow(offset: const Offset(-2, 4))],
                ),
              ),
            ],
          ),
        ),
      );
      expect(shadowFaults(tester), hasLength(2));
    });
  });

  group('separation: a piece stands off what it lies on, casts a shadow, '
      'and its words read', () {
    for (final entry in paperScreens.entries) {
      testWidgets(entry.key, (tester) async {
        _size(tester);
        await entry.value(tester);
        expect(
          separationFaults(
            piecesOf(tester),
            _groundOf(tester),
            surfacesOf(tester),
          ),
          isEmpty,
        );
      });
    }

    for (final ground in [GroundKind.night, GroundKind.day]) {
      for (final (i, sample) in partsCatalogue.indexed) {
        testWidgets(
          '${sample.entry} (${sample.state.name} #$i) on ${ground.name}',
          (tester) async {
            _size(tester, const Size(800, 1400));
            await pumpSkinned(
              tester,
              DressScope(
                dress: Dress.paper,
                child: Material(
                  type: MaterialType.transparency,
                  child: sampleOf(sample),
                ),
              ),
              ground: ground,
            );
            await tester.pump(const Duration(milliseconds: 300));
            expect(
              separationFaults(
                piecesOf(tester),
                _groundOf(tester),
                surfacesOf(tester),
              ),
              isEmpty,
            );
          },
        );
      }
    }
  });

  group('locked: the quietest button form, lower than every live one', () {
    for (final ground in [GroundKind.night, GroundKind.day]) {
      testWidgets('on ${ground.name}', (tester) async {
        _size(tester, const Size(800, 1400));
        await pumpSkinned(
          tester,
          DressScope(
            dress: Dress.paper,
            child: Material(
              type: MaterialType.transparency,
              child: Column(
                children: [
                  PrimaryButton(
                    key: const Key('primary'),
                    label: 'Ready',
                    onPressed: () {},
                  ),
                  SecondaryButton(
                    key: const Key('secondary'),
                    label: 'Back',
                    onPressed: () {},
                  ),
                  PrimaryButton.quiet(
                    key: const Key('quiet'),
                    label: 'Close',
                    onPressed: () {},
                  ),
                  PrimaryButton.locked(
                    key: const Key('look'),
                    label: CardCopy.readyLocked,
                    onLockedTap: () {},
                  ),
                  PrimaryButton.locked(
                    key: const Key('choose'),
                    label: NightCopy.chooseNone,
                    onLockedTap: () {},
                    slot: true,
                  ),
                  PrimaryButton.locked(
                    key: const Key('need'),
                    label: TableCopy.needPlayers,
                    onLockedTap: () {},
                  ),
                ],
              ),
            ),
          ),
          ground: ground,
        );
        await tester.pump(const Duration(milliseconds: 300));
        ({double lum, double reach, double ink, Color fill, Color words}) form(
          String key,
        ) {
          final at = find.byKey(Key(key));
          final paper = tester.widget<TiltedPaper>(
            find.descendant(of: at, matching: find.byType(TiltedPaper)).first,
          );
          final d = paper.decoration as ShapeDecoration;
          final shadows = d.shadows ?? const <BoxShadow>[];
          final text = tester.widget<Text>(
            find.descendant(of: at, matching: find.byType(Text)).first,
          );
          final words = DefaultTextStyle.of(
            tester.element(at),
          ).style.merge(text.style).color!;
          return (
            lum: d.color!.computeLuminance(),
            reach: shadows.fold(
              0.0,
              (m, s) => m > s.offset.dy ? m : s.offset.dy,
            ),
            ink: shadows.fold(0.0, (m, s) => m + s.color.a),
            fill: d.color!,
            words: words,
          );
        }

        final live = [form('primary'), form('secondary'), form('quiet')];
        final groundColor = tester
            .element(find.byKey(const Key('look')))
            .ground;
        for (final key in ['look', 'choose', 'need']) {
          final locked = form(key);
          for (final (i, other) in live.indexed) {
            final name = ['primary', 'secondary', 'quiet'][i];
            expect(
              locked.lum,
              lessThan(other.lum),
              reason: '$key is not darker than the live $name button',
            );
            expect(
              locked.reach,
              lessThan(other.reach),
              reason: '$key does not lie lower than the live $name button',
            );
            expect(
              locked.ink,
              lessThan(other.ink),
              reason: '$key casts as much as the live $name button',
            );
          }
          expect(locked.reach, greaterThan(0), reason: '$key casts a shadow');
          expect(
            contrast(locked.fill, groundColor.ground),
            greaterThanOrEqualTo(1.25),
            reason: '$key stands off the ground',
          );
          expect(
            contrast(locked.words, locked.fill),
            greaterThanOrEqualTo(4.5),
            reason: '$key words',
          );
        }
        // One form: the three locked buttons are the same paper.
        expect(form('look').fill, form('choose').fill);
        expect(form('look').fill, form('need').fill);
        expect(form('look').reach, form('need').reach);
      });
    }
  });

  group('material: a state is the same piece as rest', () {
    final byEntry = <String, List<PartSample>>{};
    for (final s in partsCatalogue) {
      byEntry.putIfAbsent(s.entry, () => []).add(s);
    }
    for (final entry in byEntry.entries) {
      testWidgets(entry.key, (tester) async {
        _size(tester, const Size(800, 1400));
        Future<List<PaperPieceFacts>> pieces(PartSample sample) async {
          await pumpSkinned(
            tester,
            DressScope(
              dress: Dress.paper,
              child: Material(
                type: MaterialType.transparency,
                child: sampleOf(sample),
              ),
            ),
          );
          await tester.pump(const Duration(milliseconds: 300));
          return piecesOf(tester);
        }

        final rest = entry.value.firstWhere(
          (s) => s.state == PartState.rest,
          orElse: () => entry.value.first,
        );
        final base = await pieces(rest);
        if (base.isEmpty) return;
        for (final sample in entry.value) {
          // The other kinds of a component (a quiet button is a scrap) are
          // not its states.
          if (sample.state == PartState.rest) continue;
          final now = await pieces(sample);
          // "Done" is the one state that is words and a mark, not paper.
          if (now.isEmpty) continue;
          // A picked chip is its own form on purpose (lifted, sealed:
          // `PaperPart.chipPicked`); `paper_consistency_test.dart` holds it
          // to be no button's.
          if (entry.key == 'PresetChip' && sample.state == PartState.picked) {
            continue;
          }
          expect(
            _signature(now.first),
            _signature(base.first),
            reason:
                '${entry.key} ${sample.state.name} changes the material '
                '(only the colour may change)',
          );
          expect(now.first.shadowed, base.first.shadowed);
        }
      });
    }
  });
}

/// The ground the pieces of the page lie on, in the dressed skin.
Color _groundOf(WidgetTester tester) {
  final any = find.byType(PaperPiece);
  return any.evaluate().isEmpty
      ? const Color(0xFF000000)
      : any.evaluate().first.ground.ground;
}
