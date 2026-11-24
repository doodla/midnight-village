import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/copy/copy.dart';
import 'package:midnight_village/features/game/domain/game_me.dart';
import 'package:midnight_village/features/game/presentation/shell/vote_screen.dart';

import '../helpers/sheet/pack_journeys.dart';

// The cold-read pack's journeys hang together (test/helpers/sheet/
// pack_journeys.dart): the first rerun on the real screens showed five
// players in the lobby and six at the end, tokens moving between names, the
// viewer's own name in the vote, a frozen clock and a deck strip of another
// game, all from screens stitched out of different recordings. Each journey
// is one phone of one game; these checks read the payloads its screens are
// drawn from.

Map<String, int> _count(Iterable<String> roles) {
  final counts = <String, int>{};
  for (final role in roles) {
    counts[role] = (counts[role] ?? 0) + 1;
  }
  return counts;
}

void main() {
  for (final MapEntry(key: name, value: journey) in packJourneys.entries) {
    group('the $name journey', () {
      final drawn = [
        for (final step in journey.steps)
          if (step.body != null) step,
      ];
      final dealt = [
        for (final step in drawn)
          if (step.isMe || step.screen == PackScreen.end) step,
      ];

      test('is one viewer on every screen', () {
        final ids = {for (final s in drawn) viewerIn(s.body!, journey.viewer)};
        expect(ids, hasLength(1));
        for (final step in drawn.where((s) => s.isMe)) {
          expect(step.body!['player_id'], ids.single, reason: step.sample);
        }
      });

      test('is one game: one table, the same players, names and tokens', () {
        // A set-up journey (before the deal): the first table it shows.
        final table = playersOf((dealt.firstOrNull ?? drawn.last).body!);
        for (final step in dealt) {
          expect(playersOf(step.body!), table, reason: step.sample);
        }
        // Before the deal the table fills up: never anyone else, never a
        // token that moves.
        for (final step in drawn.where((s) => !dealt.contains(s))) {
          expect(
            table.containsAll(playersOf(step.body!)),
            isTrue,
            reason: step.sample,
          );
        }
        final games = {
          for (final step in drawn.where((s) => s.isMe)) step.body!['game_id'],
        };
        // One game; a set-up journey ends before the deal: none.
        expect(games, hasLength(dealt.isEmpty ? 0 : 1));
        final codes = {
          for (final step in drawn)
            step.body!['lobby_code'] ?? step.body!['code'],
        }..remove(null);
        expect(codes, hasLength(lessThanOrEqualTo(1)));
      });

      final game = dealt.isNotEmpty;
      test("the deck the talk shows is the game's deck", skip: !game, () {
        // Every card of the game: in a hand or in the center at the end.
        final body = dealt.firstWhere((s) => s.screen == PackScreen.end).body!;
        final all = _count([
          for (final p in (body['players'] as List).cast<Map>())
            p['final_role'] as String,
          ...(body['center_cards'] as List).cast<String>(),
        ]);
        for (final step in drawn.where((s) => s.isMe)) {
          final strip = {
            for (final e in (step.body!['roles_in_game'] as List).cast<Map>())
              e['role'] as String: e['count'] as int,
          };
          expect(strip, all, reason: step.sample);
        }
      });

      test(
        "the vote offers everyone but the viewer, and the viewer's taps "
        'and vote are at the table',
        skip: !game,
        () {
          final table = playersOf(dealt.first.body!);
          final me = viewerIn(dealt.first.body!, journey.viewer);
          for (final step in drawn.where(
            (s) =>
                s.screen == PackScreen.vote ||
                s.screen == PackScreen.votePicked ||
                s.screen == PackScreen.voteLocked,
          )) {
            final offered = VoteView.votable(GameMe.fromJson(step.body!));
            expect(
              offered.map((p) => p.id).toSet(),
              {for (final p in table) p.id}..remove(me),
              reason: step.sample,
            );
          }
          final names = {for (final p in table) p.name};
          expect(names.containsAll(journey.taps), isTrue);
          expect(names, contains(journey.vote));
          expect(journey.vote, isNot(journey.viewer));
        },
      );

      test(
        "the journey is its game's: the viewer's taps are their night "
        "as the results log it, and the vote is the viewer's in the results",
        skip: !game,
        () {
          final results = dealt
              .firstWhere((s) => s.screen == PackScreen.end)
              .body!;
          final table = playersOf(results);
          final me = viewerIn(results, journey.viewer);
          String nameOf(int id) => table.firstWhere((p) => p.id == id).name;
          final seat = (results['players'] as List).cast<Map>().firstWhere(
            (p) => p['player_id'] == me,
          );
          expect(nameOf(seat['vote_target_id'] as int), journey.vote);
          // What the viewer's night acted on, in order: players by name, the
          // center by its caption (playtest: a journey that tapped one card
          // and showed another's result).
          final log = (results['night_actions_log'] as List).cast<Map>().where(
            (entry) => entry['player_id'] == me,
          );
          final tapped = [
            for (final entry in log)
              for (final MapEntry(:key, :value)
                  in (entry['targets'] as Map).entries)
                if (key == 'player_id')
                  nameOf(value as int)
                else if (key == 'player_ids')
                  for (final id in (value as List).cast<int>()) nameOf(id)
                else if (key == 'center_index')
                  NightCopy.center[value as int],
          ];
          expect(tapped, journey.taps);
        },
      );

      test(
        'the clock moves on and never runs backwards within a stage',
        skip: !game,
        () {
          final last = <String, int>{};
          var timed = 0;
          for (final step in drawn.where((s) => s.isMe && s.at != null)) {
            final stage = step.body!['stage'] as String;
            final seconds = step.secondsLeft!;
            expect(seconds, greaterThan(0), reason: step.sample);
            if (last[stage] case final before?) {
              expect(seconds, lessThanOrEqualTo(before), reason: step.sample);
            }
            last[stage] = seconds;
            timed++;
          }
          expect(timed, greaterThan(0));
          // Time passes between a stage's screens: not one frozen number.
          final byStage = <String, Set<int>>{};
          for (final step in drawn.where((s) => s.isMe && s.at != null)) {
            (byStage[step.body!['stage'] as String] ??= {}).add(
              step.secondsLeft!,
            );
          }
          for (final MapEntry(:key, :value) in byStage.entries) {
            final screens = drawn
                .where((s) => s.isMe && s.at != null && s.body!['stage'] == key)
                .length;
            if (screens > 1) expect(value.length, greaterThan(1), reason: key);
          }
        },
      );
    });
  }
}
