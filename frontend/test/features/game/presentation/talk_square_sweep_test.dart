// The guard on the square (08): three to ten players, each a recorded `/me/`
// of the talk (seven: a recorded nine with two gone), on three phones at
// text 1, 1.3 and 1.6, drawn on the real fonts and measured from the real
// render boxes as painted (a turned card by its turned corners). Nothing is
// cut; no pile of the deck lies on another or on a tag; no tag on another;
// the deck and the tags lie inside the board, above the note; the note, the
// button and the clock lie on the screen and apart; the note and the button
// are each at least 48 to touch; where the board holds too much (a short
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
import 'package:midnight_village/design_system/primitives/square_sky.dart';
import 'package:midnight_village/design_system/teach/learned_store.dart';
import 'package:midnight_village/features/game/domain/game_me.dart';
import 'package:midnight_village/features/game/presentation/shell/talk_screen.dart';
import 'package:midnight_village/features/game/presentation/shell/talk_square.dart';

import '../../../helpers/component_sheet.dart' show learnedOverrides;
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
          final scrolls = find
              .descendant(
                of: find.byType(SquareBoard),
                matching: find.byType(Scrollable),
              )
              .evaluate()
              .isNotEmpty;
          if (!scrolls) {
            _inside([...piles, ...names], board, 'on the board');
          } else {
            // Too much for the board (many players, large text, a short
            // phone): it scrolls, and its end comes into view whole.
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
        testWidgets(name, (tester) async {
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
                me: GameMe.fromJson(body()),
                secondsLeft: 192,
                onReady: () {},
                openNight: true,
              ),
            ),
          );
          await tester.pump();
          expect(truncatedText(tester), isEmpty);
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
            await tester.drag(story, const Offset(0, -3000));
            await tester.pumpAndSettle();
            _inside(_all(inStory(PaperPiece)), room, 'scrolled');
          }
        });
      }
    }
  }
}
