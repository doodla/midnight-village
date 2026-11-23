import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/layout/space.dart';
import 'package:midnight_village/design_system/primitives/death_mark.dart';
import 'package:midnight_village/design_system/primitives/paper_scrap.dart';
import 'package:midnight_village/design_system/primitives/primary_button.dart';
import 'package:midnight_village/design_system/primitives/sliced_art.dart';
import 'package:midnight_village/design_system/primitives/vote_tag.dart';
import 'package:midnight_village/design_system/primitives/you_seal.dart';
import 'package:midnight_village/design_system/skin/end_art.dart';
import 'package:midnight_village/design_system/skin/skin_id.dart';
import 'package:midnight_village/features/game/domain/end_banner.dart';
import 'package:midnight_village/features/game/domain/end_board_metrics.dart';
import 'package:midnight_village/features/game/domain/game_outcome.dart';

import '../../../helpers/outcome_samples.dart';
import '../../../helpers/truncated_text.dart';
import '../../../helpers/end_board_pump.dart';

// The static end board on the real fonts: every recorded results body on three
// phones and at normal and 1.6 text, nothing cut and nothing off the screen;
// the banner in at most three lines, even for three long names hanged and the
// Werewolves winning; the two feet; the one seal; the red banner only when the
// Werewolf team or the Tanner wins; the numbers that are also a part's own.

const _samples = [
  'results',
  'results_tie',
  'results_nobody_dies',
  'results_werewolves_win',
  'results_tanner_alone',
  'results_three_players',
  'results_doppelganger',
  'results_five',
];

Future<void> _pump(
  WidgetTester tester,
  Map<String, dynamic> results, {
  Size size = const Size(360, 780),
  double scale = 1,
  int viewer = 0,
  bool host = true,
}) async {
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = size;
  addTearDown(tester.view.reset);
  await pumpEndBoardOn(
    tester,
    results,
    viewer: viewer,
    host: host,
    scale: scale,
  );
}

/// Three players hanged with long names and the Werewolves win: the longest
/// banner there is (a recording's players renamed and killed by the vote).
Map<String, dynamic> _threeLongNamesHanged() {
  final results = recordedResults('results_werewolves_win');
  final players = (results['players'] as List).cast<Map<String, dynamic>>();
  const names = ['Bartholomew', 'Maximiliano', 'Wolfgangamadeus'];
  for (var i = 0; i < 3; i++) {
    players[i]['display_name'] = names[i];
    players[i]['is_eliminated'] = true;
    players[i]['elimination_reason'] = 'vote';
  }
  return results;
}

void main() {
  group('nothing is cut and nothing leaves the screen', () {
    for (final sample in _samples) {
      for (final size in [
        const Size(360, 780),
        const Size(390, 844),
        const Size(360, 640),
      ]) {
        for (final scale in [1.0, 1.6]) {
          testWidgets('$sample at ${size.width.toInt()}x${size.height.toInt()}'
              ' text x$scale', (tester) async {
            await _pump(
              tester,
              recordedResults(sample),
              size: size,
              scale: scale,
            );
            expect(tester.takeException(), isNull);
            expect(truncatedText(tester), isEmpty);
            // The banner's words are on the screen, whatever the ends do.
            for (final line
                in find
                    .descendant(
                      of: find.byType(BannerSlice),
                      matching: find.byType(Text),
                    )
                    .evaluate()) {
              final rect = tester.getRect(find.byWidget(line.widget));
              expect(rect.left, greaterThanOrEqualTo(-1));
              expect(rect.right, lessThanOrEqualTo(size.width + 1));
            }
          });
        }
      }
    }
  });

  group('the banner takes any sentence', () {
    for (final width in [360.0, 390.0]) {
      for (final scale in [1.0, 1.3, 1.6]) {
        testWidgets('three long names hanged, the Werewolves win, at '
            '${width.toInt()} wide, text x$scale', (tester) async {
          final results = _threeLongNamesHanged();
          await _pump(
            tester,
            results,
            size: Size(width, 780),
            scale: scale,
            viewer: 3,
          );
          expect(tester.takeException(), isNull);
          final outcome = GameOutcome.fromJson(results);
          final banner = endBannerOf(outcome, outcome.seats[3].id);
          expect(banner.red, isTrue);
          final words = find.descendant(
            of: find.byType(BannerSlice),
            matching: find.byType(Text),
          );
          final lines = [
            for (final e in words.evaluate()) (e.widget as Text).data!,
          ];
          expect(lines.length, inInclusiveRange(2, 3));
          for (final e in words.evaluate()) {
            final rect = tester.getRect(find.byWidget(e.widget));
            expect(rect.left, greaterThanOrEqualTo(-1));
            expect(rect.right, lessThanOrEqualTo(width + 1));
          }
          // A name is whole or not in the sentence at all.
          final said = lines.join(' ');
          for (final name in [
            'Bartholomew',
            'Maximiliano',
            'Wolfgangamadeus',
          ]) {
            final cut = RegExp(
              '${name.substring(0, 4)}\\w*',
            ).allMatches(said).map((m) => m[0]!).where((w) => w != name);
            expect(cut, isEmpty, reason: '$name cut in "$said"');
          }
          // And the board under it is still whole.
          expect(truncatedText(tester), isEmpty);
        });
      }
    }

    testWidgets('a sentence of two parts is two lines, never one', (
      tester,
    ) async {
      await _pump(tester, recordedResults('results_doppelganger'));
      final lines = find.descendant(
        of: find.byType(BannerSlice),
        matching: find.byType(Text),
      );
      expect(lines.evaluate().length, 2);
    });

    testWidgets('a word wider than the room keeps 24 and stops growing', (
      tester,
    ) async {
      final results = recordedResults('results_tie');
      final players = (results['players'] as List).cast<Map<String, dynamic>>();
      players[2]['display_name'] = 'Wolfgangamadeusmozart';
      await _pump(tester, results, scale: 1.6);
      expect(tester.takeException(), isNull);
      for (final e
          in find
              .descendant(
                of: find.byType(BannerSlice),
                matching: find.byType(Text),
              )
              .evaluate()) {
        final rect = tester.getRect(find.byWidget(e.widget));
        expect(rect.right, lessThanOrEqualTo(360 + 1));
      }
    });
  });

  group('the foot', () {
    testWidgets('the host: What happened, Edit deck, Play again; no Leave', (
      tester,
    ) async {
      await _pump(tester, recordedResults('results'));
      for (final word in ['What happened', 'Edit deck', 'Play again']) {
        expect(find.text(word), findsOneWidget, reason: word);
      }
      expect(find.text('Leave'), findsNothing);
      expect(find.byType(PrimaryButton), findsOneWidget);
    });

    testWidgets('a guest: Leave and who deals next, no amber control', (
      tester,
    ) async {
      await _pump(tester, recordedResults('results'), viewer: 1, host: false);
      expect(find.text('Leave'), findsOneWidget);
      expect(find.text('Ana deals next.'), findsOneWidget);
      expect(find.text('Play again'), findsNothing);
      expect(find.text('Edit deck'), findsNothing);
      expect(find.byType(PrimaryButton), findsNothing);
    });

    testWidgets('every touch target is 48 tall, scraps included', (
      tester,
    ) async {
      await _pump(tester, recordedResults('results'));
      for (final scrap in find.byType(PaperScrap).evaluate()) {
        expect(
          tester.getSize(find.byWidget(scrap.widget)).height,
          greaterThanOrEqualTo(48),
        );
      }
      expect(
        tester.getSize(find.byType(PrimaryButton)).height,
        greaterThanOrEqualTo(48),
      );
    });

    testWidgets('no timeline, no "What happened"', (tester) async {
      final results = recordedResults('results');
      results['night_timeline'] = null;
      await _pump(tester, results);
      expect(find.text('What happened'), findsNothing);
      expect(find.text('Play again'), findsOneWidget);
    });
  });

  group('the board', () {
    testWidgets('the seal is on the viewer\'s card alone', (tester) async {
      await _pump(tester, recordedResults('results'), viewer: 2);
      expect(find.byType(YouSeal), findsOneWidget);
    });

    testWidgets('a ribbon on each hanged card, and a tag for each vote on '
        'the hanged', (tester) async {
      await _pump(tester, recordedResults('results'));
      // Fin hanged and Esme, the Hunter's pick: two ribbons; four votes on Fin.
      expect(find.byType(DeathRibbon), findsNWidgets(2));
      expect(find.byType(VoteTag), findsNWidgets(4));
    });

    testWidgets('red banner only when the Werewolf team or the Tanner wins', (
      tester,
    ) async {
      final wins = {
        'results': false,
        'results_tie': false,
        'results_three_players': false,
        'results_doppelganger': false,
        'results_werewolves_win': true,
        'results_nobody_dies': true,
        'results_tanner_alone': true,
      };
      for (final MapEntry(key: sample, value: red) in wins.entries) {
        final n = (recordedResults(sample)['players'] as List).length;
        for (var viewer = 0; viewer < n; viewer++) {
          await _pump(tester, recordedResults(sample), viewer: viewer);
          final arts = tester
              .widgetList<SlicedArt>(find.byType(SlicedArt))
              .map((a) => a.art.piece);
          expect(
            arts.contains(EndPiece.bannerRed),
            red,
            reason: '$sample for seat $viewer',
          );
          expect(arts.contains(EndPiece.banner), !red);
        }
      }
    });

    testWidgets('ten players scroll between the fixed banner and the fixed '
        'foot; the end of the board is reachable', (tester) async {
      final ten = widened(
        recordedResults('results_doppelganger'),
        add: 2,
        rename: longEndNames,
      );
      await _pump(tester, ten);
      final scroll = find.byType(SingleChildScrollView);
      expect(scroll, findsOneWidget);
      final top = tester.getTopLeft(find.text('Play again'));
      final banner = tester.getTopLeft(find.byType(BannerSlice));
      await tester.drag(scroll, const Offset(0, -2000));
      await tester.pump();
      expect(tester.getTopLeft(find.text('Play again')), top);
      expect(tester.getTopLeft(find.byType(BannerSlice)), banner);
      final view = tester.state<ScrollableState>(find.byType(Scrollable));
      expect(view.position.pixels, view.position.maxScrollExtent);
      expect(view.position.maxScrollExtent, greaterThan(0));
    });

    testWidgets('six players fit one screen: nothing scrolls', (tester) async {
      for (final sample in ['results_nobody_dies', 'results_tie']) {
        await _pump(tester, recordedResults(sample));
        expect(
          find.byType(SingleChildScrollView),
          findsNothing,
          reason: sample,
        );
      }
    });
  });

  group('the numbers that are also a part\'s own', () {
    test('the tag, the ribbon, the slip and the lantern', () {
      expect(EndMetrics.tagApron, VoteTag.apron);
      expect(EndMetrics.tagHeight, VoteTag.height);
      expect(EndMetrics.ribbonInside, DeathMark.ribbonInside);
      for (final w in [20.0, 64.0, 90.0, 117.0]) {
        expect(EndMetrics.ribbonWidth(w), DeathMark.ribbonWidth(w));
        expect(
          EndMetrics.ribbonHeight(EndMetrics.ribbonWidth(w)),
          closeTo(DeathMark.ribbonHeight(DeathMark.ribbonWidth(w)), 1e-9),
        );
      }
      expect(EndMetrics.lanternSize, EndArt.lanternSize);
      expect(EndMetrics.slipHeight, PaperScrap.paperHeight);
      final skin = SkinId.fallback.skin;
      expect(EndMetrics.slipRoom, 2 * Space.md + skin.parts.pinSize);
    });
  });
}
