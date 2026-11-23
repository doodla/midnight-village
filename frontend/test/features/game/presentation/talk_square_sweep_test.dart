// The guard on the square (08): three to ten players, each a recorded `/me/`
// of the talk (seven: a recorded nine with two gone), on three phones at
// text 1, 1.3 and 1.6, drawn on the real fonts and measured from the real
// render boxes as painted (a turned card by its turned corners). Nothing is
// cut; no pile of the deck lies on another or on a tag; no tag on another;
// the deck and the tags lie inside the board, above the note; the note, the
// button and the clock lie on the screen and apart; the note and the button
// are each at least 48 to touch; portraits are never below what reads as a
// face (the skin's least): the cards become name-only first, before the board
// ever scrolls; where the board holds too much (a short
// phone, large text) it scrolls and its end comes into view whole; every player has a tag, and only this phone's
// carries the seal. And My night held, every night's picture story
// (story_samples.dart) on the same phones and text sizes: nothing cut, no
// card on another or on the slip, the story inside its room (scrolling where
// it must, its end coming into view whole), never on the note.

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/night/night_story_view.dart';
import 'package:midnight_village/design_system/primitives/deck_pile.dart';
import 'package:midnight_village/design_system/primitives/name_tag.dart';
import 'package:midnight_village/design_system/primitives/primary_button.dart';
import 'package:midnight_village/design_system/primitives/paper_piece.dart';
import 'package:midnight_village/design_system/primitives/sealed_note.dart';
import 'package:midnight_village/design_system/primitives/story_card.dart';
import 'package:midnight_village/design_system/skin/skin.dart';
import 'package:midnight_village/design_system/primitives/square_sky.dart';
import 'package:midnight_village/design_system/teach/learned_store.dart';
import 'package:midnight_village/features/game/domain/game_me.dart';
import 'package:midnight_village/features/game/presentation/shell/talk_screen.dart';
import 'package:midnight_village/features/game/presentation/shell/talk_square.dart';

import '../../../helpers/component_sheet.dart' show learnedOverrides;
import '../../../helpers/fit_checks.dart';
import '../../../helpers/pump_skinned.dart';
import '../../../helpers/sheet/sheet_data.dart' as sheet;
import '../../../helpers/sheet/story_samples.dart';
import '../../../helpers/truncated_text.dart';

const _sizes = [Size(360, 640), Size(360, 780), Size(390, 844)];
const _scales = [1.0, 1.3, 1.6];

final _tables = <int, Map<String, dynamic> Function()>{
  3: () => sheet.recordedMe('me_talk_untimed'),
  4: () => sheet.recordedMe('me_talk_practice'),
  5: () => sheet.recordedMe('me_discussion_choose_seer'),
  6: () => sheet.recordedMe('me_talk_results_seen'),
  7: () => sheet.tableOf(
    sheet.recordedMe('me_discussion_choose_drunk'),
    leave: _gone(sheet.recordedMe('me_discussion_choose_drunk'), 2),
  ),
  8: () => sheet.recordedMe('me_discussion_acting_host'),
  9: () => sheet.recordedMe('me_discussion_choose_drunk'),
  10: () => sheet.recordedMe('me_talk_ten'),
};

/// The names of the last [n] players of [me] who are not this phone's.
Set<String> _gone(Map<String, dynamic> me, int n) {
  final mine = me['player_id'];
  final others = [
    for (final p in (me['players'] as List).cast<Map<String, dynamic>>())
      if (p['player_id'] != mine) p['display_name'] as String,
  ];
  return others.reversed.take(n).toSet();
}

/// The box [element] paints into on the screen: every box under it, its
/// corners carried through every turn and move to the screen.
Rect _painted(Element element) {
  Rect? all;
  void add(RenderObject o) {
    if (o is RenderBox && o.hasSize && !o.size.isEmpty) {
      final m = o.getTransformTo(null);
      final r = Offset.zero & o.size;
      for (final p in [r.topLeft, r.topRight, r.bottomLeft, r.bottomRight]) {
        final q = MatrixUtils.transformPoint(m, p);
        all = all == null
            ? Rect.fromPoints(q, q)
            : all!.expandToInclude(Rect.fromPoints(q, q));
      }
    }
    o.visitChildren(add);
  }

  add(element.renderObject!);
  return all ?? Rect.zero;
}

List<Rect> _all(Finder finder) => finder.evaluate().map(_painted).toList();

bool _over(Rect a, Rect b) {
  final i = a.intersect(b);
  return i.width > 1 && i.height > 1;
}

void _apart(List<Rect> a, List<Rect> b, String what, {bool same = false}) {
  for (var i = 0; i < a.length; i++) {
    for (var j = same ? i + 1 : 0; j < b.length; j++) {
      expect(_over(a[i], b[j]), isFalse, reason: '$what: ${a[i]} on ${b[j]}');
    }
  }
}

void _inside(List<Rect> pieces, Rect room, String what) {
  for (final r in pieces) {
    expect(
      room.inflate(1).contains(r.topLeft) &&
          room.inflate(1).contains(r.bottomRight),
      isTrue,
      reason: '$what $r outside $room',
    );
  }
}

/// My night held, a story on a phone of [size] at text [scale]: nothing cut,
/// no card on another or on the slip, the story inside its room (scrolling
/// where it must, its end coming into view whole), never on the note.
Future<void> _heldStory(
  WidgetTester tester,
  Map<String, dynamic> body,
  Size size,
  double scale,
) async {
  tester.view.physicalSize = size;
  tester.view.devicePixelRatio = 1;
  tester.platformDispatcher.textScaleFactorTestValue = scale;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  await pumpSkinned(
    tester,
    ProviderScope(
      overrides: learnedOverrides({...Cue.values}),
      child: TalkView(
        me: GameMe.fromJson(body),
        secondsLeft: 192,
        onReady: () {},
        openNight: true,
      ),
    ),
  );
  await tester.pump();
  expect(truncatedText(tester), isEmpty);
  expect(brokenWords(tester), isEmpty);
  final story = find.byType(NightStoryView);
  final room = tester.getRect(story);
  final note = tester.getRect(find.byType(SealedNote));
  Finder inStory(Type type) =>
      find.descendant(of: story, matching: find.byType(type));
  final cards = _all(inStory(StoryCardFace));
  final slip = _all(inStory(PaperPiece));
  expect(slip, hasLength(1));
  _apart(cards, cards, 'card on card', same: true);
  _apart(cards, slip, 'card on the slip');
  expect(_over(room, note), isFalse, reason: 'the story on the note');
  final scrolls = inStory(Scrollable).evaluate().isNotEmpty;
  if (!scrolls) {
    _inside([...cards, ...slip], room, 'in its room');
  } else {
    final wide = Rect.fromLTRB(room.left, -1e6, room.right, 1e6);
    _inside([...cards, ...slip], wide, 'across its room');
    // To its end without a touch: the first touch anywhere puts a night that
    // opened by itself away (a drag would leave nothing to measure).
    final position = tester
        .state<ScrollableState>(inStory(Scrollable))
        .position;
    expect(position.maxScrollExtent, greaterThan(0));
    position.jumpTo(position.maxScrollExtent);
    await tester.pump();
    expect(inStory(PaperPiece), findsOneWidget);
    _inside(_all(inStory(PaperPiece)), room, 'scrolled');
  }
}

void main() {
  for (final MapEntry(key: players, value: body) in _tables.entries) {
    for (final size in _sizes) {
      for (final scale in _scales) {
        final name =
            '$players players, ${size.width.toInt()} x '
            '${size.height.toInt()}, text $scale';
        testWidgets(name, (tester) async {
          tester.view.physicalSize = size;
          tester.view.devicePixelRatio = 1;
          tester.platformDispatcher.textScaleFactorTestValue = scale;
          addTearDown(tester.view.reset);
          addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
          final me = GameMe.fromJson(body());
          await pumpSkinned(
            tester,
            ProviderScope(
              overrides: learnedOverrides({...Cue.values}),
              child: TalkView(me: me, secondsLeft: 192, onReady: () {}),
            ),
          );
          await tester.pump();
          expect(truncatedText(tester), isEmpty);

          final tags = tester.widgetList<NameTag>(find.byType(NameTag));
          expect(tags.length, players);
          expect(tags.where((t) => t.you).length, 1);
          expect(find.byType(DeckPile), findsNWidgets(me.deck.length));

          final screen = Offset.zero & size;
          final board = tester.getRect(find.byType(SquareBoard));
          final piles = _all(find.byType(DeckPile));
          final names = _all(find.byType(NameTag));
          _apart(piles, piles, 'pile on pile', same: true);
          _apart(names, names, 'tag on tag', same: true);
          _apart(piles, names, 'pile on tag');
          final scrollable = find.descendant(
            of: find.byType(SquareBoard),
            matching: find.byType(Scrollable),
          );
          // A board that can move (the plan may call a hair's breadth too
          // much; then it holds still, and everything lies on it).
          final scrolls =
              scrollable.evaluate().isNotEmpty &&
              tester
                      .state<ScrollableState>(scrollable)
                      .position
                      .maxScrollExtent >
                  0;
          // The rule: portraits below what reads as a face are not drawn at
          // all, the cards become name-only; and they do before the board
          // ever scrolls.
          final least = tester
              .element(find.byType(SquareBoard))
              .skin
              .parts
              .squarePortraitLeast;
          for (final pile in tester.widgetList<DeckPile>(
            find.byType(DeckPile),
          )) {
            expect(
              pile.nameOnly || pile.portraitWidth >= least,
              isTrue,
              reason: 'a sliver of a portrait: ${pile.portraitWidth}',
            );
          }
          if (scrolls) {
            expect(
              tester
                  .widgetList<DeckPile>(find.byType(DeckPile))
                  .every((p) => p.nameOnly),
              isTrue,
              reason: 'the board scrolls while the cards still have portraits',
            );
          }
          if (!scrolls) {
            _inside([...piles, ...names], board, 'on the board');
          } else {
            // Too much for the board (many players, large text, a short
            // phone): it scrolls (it has something to scroll to, so its fade
            // is drawn: no name sits under a fade on a board that does not
            // move), and its end comes into view whole.
            final wide = Rect.fromLTRB(board.left, -1e6, board.right, 1e6);
            _inside([...piles, ...names], wide, 'across the board');
            await tester.drag(find.byType(SquareBoard), const Offset(0, -3000));
            await tester.pumpAndSettle();
            _inside(_all(find.byType(NameTag).last), board, 'scrolled');
          }

          final note = tester.getRect(find.byType(SealedNote));
          final button = tester.getRect(find.byType(PrimaryButton));
          final sky = tester.getRect(find.byType(SquareSky));
          _inside([note, button, sky], screen, 'on the screen');
          // Scrolled pieces past the board's window are clipped by it, not on
          // the note.
          _apart(
            [note],
            [
              button,
              if (!scrolls) ...[...piles, ...names],
            ],
            'the note',
          );
          _apart([button], [sky], 'the button');
          expect(note.height, greaterThanOrEqualTo(48), reason: 'touch');
          expect(button.height, greaterThanOrEqualTo(48), reason: 'touch');
        });
      }
    }
  }

  for (final MapEntry(key: night, value: body) in allNights.entries) {
    for (final size in _sizes) {
      for (final scale in _scales) {
        final name =
            'My night held, $night, ${size.width.toInt()} x '
            '${size.height.toInt()}, text $scale';
        testWidgets(name, (tester) => _heldStory(tester, body(), size, scale));
      }
    }
  }

  // Long names, as a table has them (the server's names run to 20
  // characters): one that wraps between words, one a single long word, on
  // the narrow short phone at the largest text.
  for (final MapEntry(key: night, value: names) in _longNamed.entries) {
    testWidgets('My night held, $night, long names ${names.values}', (
      tester,
    ) async {
      final me = allNights[night]!();
      _rename(me, names);
      await _heldStory(tester, me, const Size(360, 640), 1.6);
      final story = find.byType(NightStoryView);
      final written = [
        for (final text in tester.widgetList<RichText>(
          find.descendant(of: story, matching: find.byType(RichText)),
        ))
          text.text.toPlainText(),
      ];
      // Every name whole where it is written: on the cards' tabs (words may
      // wrap between words, never be cut) and in the one sentence.
      for (final name in names.values) {
        expect(
          written.any((t) => t.contains(name)),
          isTrue,
          reason: '$name in $written',
        );
      }
    });
  }
}

/// Each night's players (their names in the server's `/me/`) renamed.
const _longNamed = {
  'troublemaker': {'Ana': 'Maximilian', 'Ben': 'Annabelle Whitlock'},
  'werewolf-pair': {'Ida': 'Annabelle Whitlock'},
  'mason': {'Fin': 'Rosa Maria'},
  'doppelganger-troublemaker': {
    'Gus': 'Maximilian',
    'Ben': 'Rosa Maria',
    'Cleo': 'Annabelle Whitlock',
  },
};

/// [me] with [names] renamed everywhere the server writes them: the seats
/// and the night record.
void _rename(Map<String, dynamic> me, Map<String, String> names) {
  dynamic renamed(dynamic value) => switch (value) {
    String() => names[value] ?? value,
    List() => [for (final v in value) renamed(v)],
    Map() => <String, dynamic>{
      for (final e in value.entries) '${e.key}': renamed(e.value),
    },
    _ => value,
  };
  for (final key in ['players', 'night_results']) {
    me[key] = renamed(me[key]);
  }
}
