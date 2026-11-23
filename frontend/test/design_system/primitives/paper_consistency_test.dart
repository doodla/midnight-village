import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/copy/copy.dart';
import 'package:midnight_village/design_system/models/role.dart';
import 'package:midnight_village/design_system/night/night_board.dart';
import 'package:midnight_village/design_system/primitives/chips.dart';
import 'package:midnight_village/design_system/primitives/deckle.dart';
import 'package:midnight_village/design_system/primitives/face_down_card.dart';
import 'package:midnight_village/design_system/primitives/paper_piece.dart';
import 'package:midnight_village/design_system/primitives/primary_button.dart';
import 'package:midnight_village/design_system/primitives/progress_pips.dart';
import 'package:midnight_village/design_system/primitives/secondary_button.dart';
import 'package:midnight_village/design_system/primitives/tag_chip.dart';
import 'package:midnight_village/design_system/primitives/text_backing.dart';
import 'package:midnight_village/design_system/primitives/tilted_paper.dart';
import 'package:midnight_village/design_system/skin/dress.dart';
import 'package:midnight_village/design_system/skin/dress_style.dart';
import 'package:midnight_village/design_system/skin/ground.dart';
import 'package:midnight_village/design_system/skin/skin.dart';
import 'package:midnight_village/design_system/teach/hold_cue.dart';

import '../../helpers/pump_skinned.dart';
import 'paper_components_test.dart' show paintCallsOf, paintCallsWithOwner;
import 'paper_rules_test.dart' show contrast, paperScreens, piecesOf;

// The art director's round-4 findings, each held at the component so it cannot
// return (23 November 2026): a locked main button is unmistakable and says why;
// the centre cards lie on deckled paper with no rule beside "or"; red is the
// Werewolf team's alone; a picked chip is no button; a role's name sits under
// its portrait; names on the board are quiet tags with a gap between them;
// progress dots are punched paper that shows.

double _saturation(Color c) => HSLColor.fromColor(c).saturation;

Future<void> _paper(WidgetTester tester, Widget child, {Size? size}) async {
  tester.view.physicalSize = size ?? const Size(800, 1400);
  tester.view.devicePixelRatio = 1;
  addTearDown(tester.view.reset);
  await pumpSkinned(
    tester,
    DressScope(
      dress: Dress.paper,
      child: Material(type: MaterialType.transparency, child: child),
    ),
  );
  await tester.pump(const Duration(milliseconds: 300));
}

/// The paper of the first [TiltedPaper] under [of]: its fill and the shadows it
/// casts, each as (dy, alpha), and whether it has a backing layer (an edge).
({Color fill, List<(double, double)> shadows}) _paperOf(
  WidgetTester tester,
  Finder of,
) {
  final paper = find.descendant(of: of, matching: find.byType(TiltedPaper));
  final d =
      tester.widget<TiltedPaper>(paper.first).decoration as ShapeDecoration;
  return (
    fill: d.color!,
    shadows: [
      for (final s in d.shadows ?? <BoxShadow>[]) (s.offset.dy, s.color.a),
    ],
  );
}

double _reach(List<(double, double)> shadows) =>
    shadows.fold(0.0, (m, s) => math.max(m, s.$1));

double _ink(List<(double, double)> shadows) =>
    shadows.fold(0.0, (sum, s) => sum + s.$2);

void main() {
  group('1. a locked main button is unmistakable, and says why', () {
    testWidgets('paler, flatter, greyer than the live piece, its words 4.5:1', (
      tester,
    ) async {
      await _paper(
        tester,
        Column(
          children: [
            PrimaryButton(
              key: const Key('live'),
              label: 'Ready',
              onPressed: () {},
            ),
            PrimaryButton.locked(
              key: const Key('locked'),
              label: CardCopy.readyLocked,
              onLockedTap: () {},
            ),
            PrimaryButton.locked(
              key: const Key('slot'),
              label: NightCopy.chooseNone,
              onLockedTap: () {},
              slot: true,
            ),
          ],
        ),
      );
      final live = _paperOf(tester, find.byKey(const Key('live')));
      for (final key in ['locked', 'slot']) {
        final locked = _paperOf(tester, find.byKey(Key(key)));
        final lum =
            locked.fill.computeLuminance() - live.fill.computeLuminance();
        expect(
          lum,
          greaterThanOrEqualTo(0.1),
          reason: '$key: paler by luminance',
        );
        expect(
          _saturation(locked.fill),
          lessThanOrEqualTo(_saturation(live.fill) * 0.5),
          reason: '$key: lower saturation',
        );
        expect(
          _reach(locked.shadows),
          lessThanOrEqualTo(_reach(live.shadows) * 0.5),
          reason: '$key: no lift (the shadow falls a short way)',
        );
        expect(
          _ink(locked.shadows),
          lessThanOrEqualTo(_ink(live.shadows) * 0.6),
          reason: '$key: a lighter shadow',
        );
        expect(locked.shadows, isNotEmpty, reason: '$key: still casts one');
        final ground = tester.element(find.byKey(Key(key))).ground;
        expect(
          contrast(ground.onAccent, locked.fill),
          greaterThanOrEqualTo(4.5),
          reason: '$key: its label',
        );
      }
    });

    // Every place a main button is locked, and what its label says. A new one
    // must be listed here (the scan below fails until it is), with the words
    // it says and what they are compared with.
    final locked = <String, ({String says, String? unlocked, String why})>{
      'features/game/presentation/shell/your_card_screen.dart': (
        says: CardCopy.readyLocked,
        unlocked: CardCopy.ready,
        why: 'names what unlocks it',
      ),
      'design_system/night/night_board.dart': (
        says: NightCopy.chooseNone,
        unlocked: null,
        why: 'the pick it waits for ("Choose a card", "Choose 1 more")',
      ),
      'features/lobby/presentation/at_table_screen.dart': (
        says: TableCopy.needPlayers,
        unlocked: null,
        why: 'what the table needs ("Need 3 players", "Add 1 card")',
      ),
      'features/lobby/presentation/join_screen.dart': (
        says: JoinCopy.join,
        unlocked: JoinCopy.join,
        why:
            'a plain screen (01 is not dressed up): a tap takes the cursor to '
            'the field that lacks its word',
      ),
    };

    test('every locked main button in lib/ is listed and says something', () {
      final found = <String>{};
      for (final f in Directory('lib').listSync(recursive: true)) {
        if (f is! File || !f.path.endsWith('.dart')) continue;
        if (f.path.endsWith('primary_button.dart') ||
            f.path.endsWith('secondary_button.dart')) {
          continue;
        }
        if (RegExp(
          r'(Primary|Secondary)Button\.locked\(',
        ).hasMatch(f.readAsStringSync())) {
          found.add(f.path.replaceFirst('lib/', ''));
        }
      }
      expect(
        found,
        locked.keys.toSet(),
        reason: 'classify a new locked button',
      );
      for (final e in locked.entries) {
        final plain = e.key.contains('join_screen');
        if (plain) continue; // a plain screen: its look is today's, unchanged
        final unlocked = e.value.unlocked;
        expect(
          unlocked == null || e.value.says != unlocked,
          isTrue,
          reason: '${e.key}: a locked label says the same as the live one',
        );
        expect(e.value.says.trim(), isNotEmpty);
      }
    });

    test('the table\'s and the board\'s locked words name the need', () {
      expect(NightCopy.chooseNone, contains('Choose'));
      expect(NightCopy.chooseMore, contains('Choose'));
      expect(TableCopy.needPlayers, contains('Need'));
      expect(CardCopy.readyLocked, isNot(CardCopy.ready));
    });
  });

  group('2. the centre cards lie on deckled paper; "or" stands alone', () {
    for (final entry in {
      'night board, 5': paperScreens['night board, 5']!,
      'night board, 10': paperScreens['night board, 10']!,
    }.entries) {
      testWidgets(entry.key, (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await entry.value(tester);
        final strip = find.ancestor(
          of: find.text(NightCopy.centerLabel).evaluate().isEmpty
              ? find.text('2 center cards')
              : find.text(NightCopy.centerLabel),
          matching: find.byType(PaperPiece),
        );
        expect(strip, findsWidgets, reason: 'the strip is a paper piece');
        final panel = strip
            .evaluate()
            .map((e) => e.widget as PaperPiece)
            .firstWhere((p) => p.part == PaperPart.panel);
        expect(panel.part, PaperPart.panel);
        final d = _decorationOf(tester, find.byWidget(panel));
        expect(d.shape, isA<DeckleBorder>(), reason: 'torn, not a rounded box');
        expect((d.shadows ?? const []), isNotEmpty);
        // No hairline anywhere on the screen (a rule is a filled box a pixel or
        // two thick and long).
        expect(_hairlines(tester), isEmpty);
      });
    }

    for (final entry in paperScreens.entries) {
      testWidgets('no hairline on ${entry.key}', (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await entry.value(tester);
        expect(_hairlines(tester), isEmpty);
      });
    }
  });

  group('3. red is the Werewolf team\'s alone', () {
    Set<int> reds(BuildContext context) {
      final skin = context.skin;
      final parts = skin.parts;
      int rgb(Color c) => c.toARGB32() & 0xFFFFFF;
      final dressed = skin.dressedUp ?? skin;
      return {
        rgb(parts.werewolfTag),
        for (final g in [dressed.night, dressed.day, dressed.paper])
          for (final c in [g.danger, g.dangerLine, g.dangerText]) rgb(c),
      };
    }

    // Who may paint the Werewolf red: the team's tag (a `TagChip`, or the plate
    // of a role's name on a card, a `TextBacking`). A row or marker of the
    // Werewolf team is a plain screen's (the count, the results) and is
    // listed when a paper screen has one.
    bool teamTag(RenderObject owner) {
      final creator = owner.debugCreator;
      if (creator is! DebugCreator) return false;
      var found = false;
      creator.element.visitAncestorElements((e) {
        if (e.widget is TagChip || e.widget is TextBacking) found = true;
        return !found;
      });
      return found;
    }

    List<String> redPaint(WidgetTester tester) {
      final element = tester.element(find.byType(Material).first);
      final red = reds(element);
      final found = <String>[];
      for (final (call, owner) in paintCallsWithOwner(
        tester.binding.renderViews.first.child!,
      )) {
        final paint = call.invocation.positionalArguments
            .whereType<Paint>()
            .firstOrNull;
        if (paint == null || !red.contains(paint.color.toARGB32() & 0xFFFFFF)) {
          continue;
        }
        if (teamTag(owner)) continue;
        found.add('${call.invocation.memberName} red in ${owner.runtimeType}');
      }
      return found;
    }

    for (final entry in paperScreens.entries) {
      testWidgets('${entry.key}: only a Werewolf tag paints it', (
        tester,
      ) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await entry.value(tester);
        expect(redPaint(tester), isEmpty);
      });
    }

    testWidgets('the check sees a red card frame', (tester) async {
      await _paper(
        tester,
        Container(width: 40, height: 40, color: const Color(0xFF6E1D18)),
      );
      expect(redPaint(tester), isNotEmpty);
    });

    testWidgets('a face-down card\'s rim is indigo, never red', (tester) async {
      await _paper(
        tester,
        const SizedBox(
          width: 120,
          height: 160,
          child: FaceDownCard(size: FaceDownSize.board, cardWidth: 100),
        ),
      );
      expect(redPaint(tester), isEmpty);
    });
  });

  group('4. a picked chip is no button', () {
    test('no picked-chip style equals any button style', () {
      final picked = DressStyle.paper(PaperPart.chipPicked);
      expect(picked.seal, isTrue);
      for (final button in [PaperPart.primary, PaperPart.scrap]) {
        final b = DressStyle.paper(button);
        expect(
          (picked.fill, picked.raise, picked.edge, picked.seal),
          isNot((b.fill, b.raise, b.edge, b.seal)),
          reason: 'a picked chip looks like $button',
        );
        expect(b.seal, isFalse, reason: 'only a pick wears a seal');
        expect(picked.raise, isNot(b.raise), reason: 'a pick lifts higher');
      }
      final unpicked = DressStyle.paper(PaperPart.chip);
      expect(unpicked.fill, isNot(picked.fill), reason: 'unpicked is dimmer');
    });

    testWidgets('on the page: lifted higher than a button, a seal on it, the '
        'others flat and dim', (tester) async {
      await _paper(
        tester,
        Column(
          children: [
            Row(
              children: [
                PresetChip(
                  key: const Key('picked'),
                  label: 'Classic',
                  selected: true,
                  onTap: () {},
                ),
                PresetChip(
                  key: const Key('other'),
                  label: 'Simple',
                  selected: false,
                  onTap: () {},
                ),
                SecondaryButton(
                  key: const Key('button'),
                  label: 'Edit',
                  onPressed: () {},
                ),
              ],
            ),
          ],
        ),
      );
      final picked = _paperOf(tester, find.byKey(const Key('picked')));
      final other = _paperOf(tester, find.byKey(const Key('other')));
      final button = _paperOf(tester, find.byKey(const Key('button')));
      expect(_reach(picked.shadows), greaterThan(_reach(button.shadows)));
      expect(_reach(other.shadows), lessThan(_reach(picked.shadows)));
      expect(
        other.fill.computeLuminance(),
        lessThan(picked.fill.computeLuminance() - 0.1),
        reason: 'the unpicked chip is dimmer',
      );
      // The seal: one mark, hung over the picked chip's corner only.
      expect(
        find.descendant(
          of: find.byKey(const Key('picked')),
          matching: find.byType(CustomPaint),
        ),
        findsWidgets,
      );
    });
  });

  group('5. a role\'s name sits under its portrait', () {
    testWidgets('the own card on the board: the tag clears the portrait', (
      tester,
    ) async {
      tester.view.physicalSize = const Size(390, 844);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await paperScreens['night board, 5']!(tester);
      final portrait = find.descendant(
        of: find.byWidgetPredicate(
          (w) => w is FaceDownCard && w.face == RoleId.seer,
        ),
        matching: find.byType(CardBackPaper),
      );
      expect(portrait, findsOneWidget);
      final art = tester.getRect(portrait);
      final tag = tester.getRect(find.text(RoleId.seer.displayName));
      expect(
        tag.top,
        greaterThanOrEqualTo(art.bottom - 0.5),
        reason: 'the role tag $tag lies over the portrait $art',
      );
    });
  });

  group('6. the Hold disc has no ring', () {
    testWidgets('at rest the arc paints nothing', (tester) async {
      final fill = AnimationController(
        vsync: const TestVSync(),
        duration: const Duration(seconds: 1),
      );
      addTearDown(fill.dispose);
      await tester.pumpWidget(
        CustomPaint(
          size: const Size(100, 100),
          painter: HoldArcPainter(
            fill: fill,
            amber: Colors.amber,
            shadow: Colors.black,
            lean: 0,
            band: 7,
          ),
        ),
      );
      int draws() => paintCallsOf(
        tester.binding.renderViews.first.child!,
      ).where((c) => '${c.invocation.memberName}'.contains('draw')).length;
      expect(draws(), 0, reason: 'a track or ring drawn at rest');
      fill.value = 0.5;
      await tester.pump();
      expect(draws(), greaterThan(0));
    });
  });

  group('8. names on the board are quiet tags that keep apart', () {
    for (final width in [360.0, 390.0]) {
      testWidgets('ten, long names, at $width wide', (tester) async {
        tester.view.physicalSize = Size(width, 780);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await paperScreens['night board, 10']!(tester);
        final tags = piecesOf(
          tester,
        ).where((p) => p.part == PaperPart.nameTag).toList();
        expect(tags.length, greaterThanOrEqualTo(9));
        final ground = tester.element(find.byType(NightBoard)).ground;
        for (final t in tags) {
          expect(
            t.fill.computeLuminance(),
            lessThan(ground.paper.computeLuminance() * 0.5),
            reason: '$t is brighter than a name should be',
          );
          for (final w in t.words) {
            expect(contrast(w, t.fill), greaterThanOrEqualTo(4.5));
          }
        }
        for (final a in tags) {
          for (final b in tags) {
            if (identical(a, b)) continue;
            final sameRow = (a.rect.center.dy - b.rect.center.dy).abs() < 8;
            if (sameRow && a.rect.right <= b.rect.left + 0.5) {
              expect(
                b.rect.left - a.rect.right,
                greaterThanOrEqualTo(2),
                reason: '$a and $b nearly touch',
              );
            }
          }
        }
      });
    }
  });

  group('7. progress dots are punched paper that shows', () {
    test('an unlit dot keeps 3:1 against every ground', () {
      for (final kind in GroundKind.values) {
        final skin = skinsUnderTest.values.first;
        final dressed = skin.dressedUp ?? skin;
        final ground = dressed.ground(kind);
        expect(
          contrast(dressed.parts.pipUnlit(ground), ground.ground),
          greaterThanOrEqualTo(3),
          reason: kind.name,
        );
      }
    });

    testWidgets('they are paper pieces with a shadow', (tester) async {
      await _paper(
        tester,
        const ProgressPips(done: 2, total: 5, label: '2 of 5 ready'),
      );
      final pips = piecesOf(tester).where((p) => p.part == PaperPart.pip);
      expect(pips, hasLength(5));
      for (final p in pips) {
        expect(p.shadowed, isTrue);
      }
    });
  });
}

ShapeDecoration _decorationOf(WidgetTester tester, Finder piece) {
  final paper = find.descendant(of: piece, matching: find.byType(TiltedPaper));
  return tester.widget<TiltedPaper>(paper.first).decoration as ShapeDecoration;
}

/// Filled boxes a pixel or two thick and a good length: a rule, whatever
/// widget draws it.
List<String> _hairlines(WidgetTester tester) {
  final out = <String>[];
  for (final e in tester.allElements) {
    final w = e.widget;
    if (w is! DecoratedBox && w is! ColoredBox) continue;
    final render = e.renderObject;
    if (render is! RenderBox || !render.hasSize || !render.attached) continue;
    final s = render.size;
    final thin = math.min(s.width, s.height);
    final long = math.max(s.width, s.height);
    if (thin <= 2 && long >= 24) out.add('${w.runtimeType} $s');
  }
  return out;
}
