import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/copy/copy.dart';
import 'package:midnight_village/design_system/primitives/board_pieces.dart';
import 'package:midnight_village/design_system/primitives/death_mark.dart';
import 'package:midnight_village/design_system/primitives/paper_scrap.dart';
import 'package:midnight_village/design_system/primitives/primary_button.dart';
import 'package:midnight_village/design_system/primitives/sliced_art.dart';
import 'package:midnight_village/design_system/primitives/vote_tag.dart';
import 'package:midnight_village/design_system/primitives/you_seal.dart';
import 'package:midnight_village/features/game/domain/end_board_metrics.dart';
import 'package:midnight_village/features/game/presentation/end/end_board_view.dart';
import 'package:midnight_village/features/game/presentation/end/end_foot.dart';

import '../../../helpers/end_board_pump.dart';
import '../../../helpers/outcome_samples.dart';
import '../../../helpers/truncated_text.dart';

// The guard that keeps a clipped word or a piece lying on another from coming
// back: every results body (and ten players with long names) on three phones
// at text sizes 1, 1.3 and 1.6, drawn on the real fonts, then measured from
// the real render boxes as they are painted (a tilted card by its turned
// corners). Nothing is cut; no card lies on another; no tag lies on a card or
// another tag; the Hunter's slip covers no tag, seal or ribbon; the foot's
// pieces lie apart and on the screen, each touch target 48 tall; the banner's
// words lie inside the banner and on the screen; and the hanged are in the
// board's window when it opens.

const _sizes = [Size(360, 640), Size(360, 780), Size(390, 844)];
const _scales = [1.0, 1.3, 1.6];

final _samples = <String, Map<String, dynamic> Function()>{
  for (final name in [
    'results',
    'results_tie',
    'results_nobody_dies',
    'results_werewolves_win',
    'results_tanner_alone',
    'results_three_players',
    'results_doppelganger',
    'results_five',
    'results_moved_dead_card',
    'results_hunter_chain',
  ])
    name: () => recordedResults(name),
  'ten_long_names': () => widened(
    recordedResults('results_doppelganger'),
    add: 2,
    rename: longEndNames,
  ),
};

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
        final dot = Rect.fromPoints(q, q);
        all = all == null ? dot : all!.expandToInclude(dot);
      }
    }
    o.visitChildren(add);
  }

  add(element.renderObject!);
  return all ?? Rect.zero;
}

List<Rect> _all(Finder finder) => finder.evaluate().map(_painted).toList();

/// Two boxes lie on each other by more than a hair.
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

void main() {
  for (final entry in _samples.entries) {
    for (final size in _sizes) {
      for (final scale in _scales) {
        final guest = entry.key == 'results_five';
        testWidgets('${entry.key} at ${size.width.toInt()}x'
            '${size.height.toInt()} text x$scale', (tester) async {
          tester.view.devicePixelRatio = 1;
          tester.view.physicalSize = size;
          addTearDown(tester.view.reset);
          await pumpEndBoardOn(
            tester,
            entry.value(),
            viewer: guest ? 2 : 0,
            host: !guest,
            scale: scale,
          );
          await tester.pump();
          expect(tester.takeException(), isNull);
          expect(truncatedText(tester), isEmpty);

          final screen = Offset.zero & size;
          final foot = find.byType(EndFootBand);
          final onBoard = find.descendant(
            of: find.byType(EndBoardWindow),
            matching: find.byType(BoardCard),
          );
          final cards = _all(onBoard);
          final tags = _all(find.byType(VoteTag));
          final seals = _all(find.byType(YouSeal));
          final ribbons = _all(find.byType(DeathRibbon));
          final slips = _all(
            find.descendant(
              of: find.byType(EndBoardWindow),
              matching: find.byType(PaperSlip),
            ),
          );
          _apart(cards, cards, 'cards', same: true);
          _apart(tags, tags, 'tags', same: true);
          _apart(tags, cards, 'a tag on a card');
          _apart(slips, [...tags, ...seals, ...ribbons], 'the slip');
          for (final r in [...cards, ...tags, ...seals, ...ribbons]) {
            expect(
              r.left >= -0.5 && r.right <= size.width + 0.5,
              isTrue,
              reason: 'off the screen: $r',
            );
          }

          // The foot: its pieces apart, on the screen, 48 to touch.
          final footPieces = [
            ..._all(
              find.descendant(of: foot, matching: find.byType(BoardCard)),
            ),
            ..._all(find.byType(PaperScrap)),
            ..._all(find.byType(PrimaryButton)),
            ..._all(
              find.descendant(
                of: foot,
                matching: find.textContaining(
                  EndCopy.hostDealsNext.fill({'host': ''}).trim(),
                ),
              ),
            ),
          ];
          _apart(footPieces, footPieces, 'the foot', same: true);
          for (final r in footPieces) {
            expect(
              screen.inflate(0.5).contains(r.topLeft) &&
                  screen.inflate(0.5).contains(r.bottomRight),
              isTrue,
              reason: 'a piece of the foot off the screen: $r',
            );
          }
          for (final e in [
            ...find.byType(PaperScrap).evaluate(),
            ...find.byType(PrimaryButton).evaluate(),
          ]) {
            expect(
              (e.renderObject! as RenderBox).size.height,
              greaterThanOrEqualTo(48),
            );
          }

          // The banner's words: inside the banner, on the screen.
          final banner = tester.getRect(find.byType(BannerSlice));
          for (final line
              in find
                  .descendant(
                    of: find.byType(BannerSlice),
                    matching: find.byType(Text),
                  )
                  .evaluate()) {
            final r = _painted(line);
            expect(r.left >= -1 && r.right <= size.width + 1, isTrue);
            expect(
              r.top >= banner.top - 1 && r.bottom <= banner.bottom + 1,
              isTrue,
              reason: 'the banner\'s words leave it: $r in $banner',
            );
          }

          // The hanged are in the window when it opens, clear of the eave
          // and the foot's lip.
          final window = tester.getRect(find.byType(EndBoardWindow));
          final seen = Rect.fromLTRB(
            window.left,
            window.top + EndMetrics.roof,
            window.right,
            window.bottom - EndMetrics.lip,
          );
          for (final e in onBoard.evaluate()) {
            final card = e.widget as BoardCard;
            if (!(card.semantics ?? '').contains(EndCopy.hangedWord)) continue;
            final r = _painted(e);
            expect(
              seen.inflate(1).contains(r.topLeft) &&
                  seen.inflate(1).contains(r.bottomRight),
              isTrue,
              reason: '${card.name} (hanged) is not in view: $r in $seen',
            );
          }
        });
      }
    }
  }
}
