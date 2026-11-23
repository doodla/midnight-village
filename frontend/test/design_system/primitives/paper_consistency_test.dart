// Guard file: a change here needs its line in the pull request (tool/guard_edits.py).
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart' show RenderCustomPaint;
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/primitives/deck_pile.dart';
import 'package:midnight_village/design_system/primitives/story_card.dart';
import 'package:midnight_village/design_system/primitives/twine.dart';
import 'package:midnight_village/design_system/copy/copy.dart';
import 'package:midnight_village/design_system/models/role.dart';
import 'package:midnight_village/design_system/night/night_board.dart';
import 'package:midnight_village/design_system/primitives/chips.dart';
import 'package:midnight_village/design_system/primitives/deckle.dart';
import 'package:midnight_village/design_system/primitives/face_down_card.dart';
import 'package:midnight_village/design_system/primitives/paper_piece.dart';
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
import 'paper_rules_test.dart'
    show contrast, paperScreens, paperSheets, piecesOf;

// The art director's round-4 findings, each held at the component so it cannot
// return (23 November 2026): a locked main button is unmistakable and says why;
// the centre cards lie on deckled paper with no rule beside "or"; red is the
// Werewolf team's alone; a picked chip is no button; a role's name sits under
// its portrait; names on the board are quiet tags with a gap between them;
// progress dots are punched paper that shows.

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

void main() {
  group('1. a locked main button is unmistakable, and says why', () {
    // The look of the one locked form (the quietest button there is, lower than
    // every live button form in luminance and in shadow, its words 4.5:1)
    // is held in `paper_rules_test.dart`, "locked".

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
      'features/lobby/presentation/at_table_view.dart': (
        says: TableCopy.needPlayers,
        unlocked: null,
        why: 'what the table needs ("Need 3 players", "Add 1 card")',
      ),
      'features/lobby/presentation/join_view.dart': (
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
        final plain = e.key.contains('join_view');
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
    // A hue, not a list of colours: any warm red (a team tag, a danger ink, a
    // red a component cut for itself) is the Werewolf team's, and only on its
    // team tag (`TagChip`). A name plate, a card, a rim and a button are never
    // red, whatever they are made of.
    bool isRed(Color c) {
      if (c.a < 0.5) return false;
      final hsl = HSLColor.fromColor(c);
      final hue = hsl.hue;
      return (hue >= 345 || hue <= 18) &&
          hsl.saturation >= 0.3 &&
          hsl.lightness >= 0.12 &&
          hsl.lightness <= 0.8;
    }

    // A team tag is the one place. (The test app's debug banner, Flutter's own
    // red ribbon, is skipped by its colour below.)
    bool underTeamTag(Element e) {
      var found = false;
      e.visitAncestorElements((a) {
        final w = a.widget;
        // A card of the Werewolf team in the deck in play (08) is cut from
        // the team's red, as its tag is.
        // So is a face-up Werewolf-team card of a night's story (08, held).
        if (w is TagChip ||
            (w is DeckPile && w.role.team == TeamId.werewolf) ||
            (w is StoryCardFace && w.role?.team == TeamId.werewolf)) {
          found = true;
        }
        return !found;
      });
      return found;
    }

    List<String> redPaint(WidgetTester tester) {
      final found = <String>[];
      for (final (call, owner) in paintCallsWithOwner(
        tester.binding.renderViews.first.child!,
      )) {
        final paint = call.invocation.positionalArguments
            .whereType<Paint>()
            .firstOrNull;
        if (paint == null || !isRed(paint.color)) continue;
        if (paint.color.toARGB32() == 0xA0B71C1C) continue; // the banner
        // The one other red there is: the thread of a `Twine(werewolf: true)`,
        // and nothing wider (a painter of another kind, or a thread of another
        // red, is still found).
        if (_isWerewolfTwine(owner)) continue;
        final creator = owner.debugCreator;
        final teamTag =
            creator is DebugCreator && underTeamTag(creator.element);
        if (!teamTag) {
          found.add(
            '${call.invocation.memberName} ${paint.color} in ${owner.runtimeType}',
          );
        }
      }
      // And words: a red text is no team tag's.
      for (final e in tester.allElements) {
        final w = e.widget;
        final colour = switch (w) {
          RichText() => w.text.style?.color,
          _ => null,
        };
        if (colour != null && isRed(colour) && !underTeamTag(e)) {
          found.add('words in $colour');
        }
      }
      return found;
    }

    for (final entry in paperScreens.entries) {
      testWidgets('${entry.key}: only a team tag is red', (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await entry.value(tester);
        expect(redPaint(tester), isEmpty);
      });
    }

    for (final entry in paperSheets.entries) {
      testWidgets('${entry.key}: only a team tag is red', (tester) async {
        tester.view.physicalSize = const Size(390, 844);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.reset);
        await entry.value.open(tester);
        expect(redPaint(tester), isEmpty);
      });
    }

    testWidgets('the check sees a red card frame, a red plate and red words', (
      tester,
    ) async {
      await _paper(
        tester,
        Container(width: 40, height: 40, color: const Color(0xFF6E1D18)),
      );
      expect(redPaint(tester), isNotEmpty);
      await _paper(
        tester,
        // Any red, not only the one the skin names; under a name plate.
        const TextBacking(
          fill: Color(0xFFB02A22),
          child: Text('Minion', style: TextStyle(color: Color(0xFFFFFFFF))),
        ),
      );
      expect(redPaint(tester), isNotEmpty);
      await _paper(
        tester,
        const Text('Wolf', style: TextStyle(color: Color(0xFFD64540))),
      );
      expect(redPaint(tester), isNotEmpty);
    });

    testWidgets('a Werewolf team tag is the one red there is', (tester) async {
      await _paper(
        tester,
        const TagChip.team('Werewolf team', team: TeamId.werewolf),
      );
      expect(redPaint(tester), isEmpty);
      final tag = tester.widget<TiltedPaper>(find.byType(TiltedPaper).first);
      expect(isRed((tag.decoration as ShapeDecoration).color!), isTrue);
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

    testWidgets('a Minion\'s card reads as no Werewolf\'s: its name is on '
        'neutral paper', (tester) async {
      await _paper(
        tester,
        const SizedBox(
          width: 120,
          height: 180,
          child: FaceDownCard(
            size: FaceDownSize.board,
            cardWidth: 100,
            face: RoleId.minion,
          ),
        ),
      );
      expect(redPaint(tester), isEmpty);
    });
  });

  group('4. a picked chip is no button', () {
    test('no picked-chip style equals any button style', () {
      final picked = DressStyle.paper(PaperPart.chipPicked);
      for (final button in [PaperPart.primary, PaperPart.scrap]) {
        final b = DressStyle.paper(button);
        expect(
          (picked.fill, picked.raise, picked.edge),
          isNot((b.fill, b.raise, b.edge)),
          reason: 'a picked chip looks like $button',
        );
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
            drop: 2,
            castAlpha: 0.5,
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

/// A paint owned by a `TwinePainter` whose thread is the Werewolf team's red.
bool _isWerewolfTwine(RenderObject owner) {
  if (owner is! RenderCustomPaint) return false;
  final painter = owner.painter;
  return painter is TwinePainter &&
      painter.color == skinsUnderTest.values.first.parts.werewolfTag;
}
