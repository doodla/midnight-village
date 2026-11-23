import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/faces/face_content.dart'
    show serverRole;
import 'package:midnight_village/design_system/models/role.dart';
import 'package:midnight_village/features/game/domain/end_story.dart';
import 'package:midnight_village/features/game/domain/night_timeline.dart';
import 'package:midnight_village/features/game/domain/outcome_view.dart';

import '../../../helpers/contract/contract_samples.dart';
import '../../../helpers/end_board_plans.dart';
import '../../../helpers/outcome_samples.dart';

// What happened, as the board replays it (`endStoryOf`): on every recorded
// results body, and step by step on the games that each show a case: the
// Werewolves and the Seer and the Robber then the Troublemaker on the same
// card (`results`), the Doppelganger's copy and its copied look, the lone
// Werewolf's middle look, the Minion, the Masons, the Drunk and the Insomniac
// (`results_doppelganger`), a Doppelganger who copied a Werewolf and a Drunk
// the server moved (`results_tanner`), a dead card that moved
// (`results_moved_dead_card`), and steps that did nothing (`results_tie`).

EndStory storyOf(String sample) =>
    endStoryOf(outcomeOf(recordedResults(sample)))!;

/// Player ids by name, in [sample].
Map<String, int> idsOf(String sample) => {
  for (final s in outcomeOf(recordedResults(sample)).seats) s.name: s.id,
};

StoryThread thread(CardPlace from, CardPlace to) => (from: from, to: to);

/// A line leads with the role that acted (or the team).
final _leadsWithRole = RegExp(
  '^(Werewolves|Masons|Lone Werewolf|Werewolf|Mason|Minion|Seer|Robber|'
  'Troublemaker|Drunk|Insomniac|Doppelganger) ',
);

/// "Left", "Right" or "Middle" alone: a middle card named by its side.
final _bareSide = RegExp(r'\b(Left|Right|Middle)\b');

void main() {
  final samples = [
    for (final info in ContractSamples.index)
      if (info.name.startsWith('http/game/results') &&
          info.status == 200 &&
          ContractSamples.map(info.name)['night_timeline'] != null)
        info.name.substring('http/game/'.length),
  ];

  test('every recorded game with a night is read', () {
    expect(samples, containsAll(['results', 'results_doppelganger']));
  });

  group('on every recorded game', () {
    for (final name in samples) {
      test(name, () {
        final outcome = outcomeOf(recordedResults(name));
        final story = endStoryOf(outcome)!;
        final seats = endSeatsOf(outcome);
        // The deal: what each player was dealt; the end: the settled board's
        // faces exactly (a Doppelganger shows what it copied).
        for (final s in seats) {
          expect(story.dealt.players[s.seat.id]!.face, s.dealt, reason: name);
          expect(story.last.players[s.seat.id], (
            face: s.plays,
            strip: s.copied != null ? RoleId.doppelganger : s.now,
          ), reason: s.seat.name);
        }
        expect([
          for (final f in story.last.centre) f.face,
        ], outcome.result.centerCards);
        // At the deal and after every step, every seat and every middle card
        // shows the card the server recorded there, read from the recording
        // itself: its role on the strip, and as its portrait, but for the
        // Doppelganger card in a player's hand once it has copied, which
        // shows what it copied. A card that moves keeps its own face.
        final raw =
            ContractSamples.map('http/game/$name')['night_timeline'] as Map;
        final roleOf = {
          for (final c in (raw['cards'] as List).cast<Map>())
            c['card_id'] as String: serverRole(c['role']),
        };
        final rawSteps = [
          for (final s in (raw['steps'] as List).cast<Map>())
            if (s['action'] != 'skip') s,
        ];
        RoleId? copied;
        void matchesRecording(StoryFaces faces, Map at, String when) {
          void check(StoryFace f, String card, {required bool held}) {
            final role = roleOf[card]!;
            final copy = held && role == RoleId.doppelganger ? copied : null;
            expect(f, (face: copy ?? role, strip: role), reason: '$name $when');
          }

          final players = (at['players'] as Map).cast<String, String>();
          expect(faces.players.keys.toSet(), players.keys.map(int.parse));
          for (final MapEntry(:key, :value) in players.entries) {
            check(faces.players[int.parse(key)]!, value, held: true);
          }
          final centre = (at['center'] as List).cast<String>();
          expect(faces.centre, hasLength(centre.length));
          for (final (i, card) in centre.indexed) {
            check(faces.centre[i], card, held: false);
          }
        }

        matchesRecording(story.dealt, raw['dealt'] as Map, 'dealt');
        for (final (i, step) in story.steps.indexed) {
          if (rawSteps[i]['copied_role'] case final String role) {
            copied = serverRole(role);
          }
          matchesRecording(
            step.after,
            rawSteps[i]['positions_after'] as Map,
            step.line,
          );
        }
        // Numbered in order; a step that did nothing is not one.
        final did = outcome.timeline!.steps.where(
          (s) => s.action != TimelineAction.skip,
        );
        expect(story.steps, hasLength(did.length));
        for (final (i, step) in story.steps.indexed) {
          expect(step.number, i + 1);
          // The line leads with the role that acted, and never names a
          // middle card by a bare side.
          expect(step.line, matches(_leadsWithRole), reason: step.line);
          expect(step.line, isNot(matches(_bareSide)), reason: step.line);
          // Red only for the Werewolf team's own acts: read from the
          // recording's own words, not the app's team table.
          final timeline =
              ContractSamples.map('http/game/$name')['night_timeline'] as Map;
          final acted = [
            for (final raw in (timeline['steps'] as List).cast<Map>())
              if (raw['action'] != 'skip') raw['role'] as String,
          ];
          expect(
            step.werewolf,
            const {'Werewolf', 'Minion'}.contains(acted[i]),
            reason: '$name ${step.line}',
          );
          // A step only moves what its threads join.
          final before = story.before(i);
          for (final MapEntry(:key, :value) in step.after.players.entries) {
            if (before.players[key]!.face != value.face &&
                step.kind != StoryKind.copy) {
              expect(step.kind.moves, isTrue, reason: '$name ${step.line}');
              expect(step.places, contains(PlayerPlace(key)));
            }
          }
        }
      });
    }
  });

  test('a six-player game: the Robber then the Troublemaker on one card', () {
    final story = storyOf('results');
    final id = idsOf('results');
    PlayerPlace p(String name) => PlayerPlace(id[name]!);
    expect(
      [for (final s in story.steps) s.line],
      [
        'Werewolves Cleo and Esme meet.',
        'Seer Ana sees Cleo: Werewolf.',
        "Robber Ben takes Dev's card.",
        'Troublemaker Dev swaps Ana and Ben.',
      ],
    );
    expect(story.steps.map((s) => s.kind), [
      StoryKind.team,
      StoryKind.look,
      StoryKind.take,
      StoryKind.swap,
    ]);
    expect(story.steps.map((s) => s.werewolf), [true, false, false, false]);
    expect(story.steps[0].threads, [thread(p('Cleo'), p('Esme'))]);
    expect(story.steps[1].threads, [thread(p('Ana'), p('Cleo'))]);
    expect(story.steps[2].threads, [thread(p('Ben'), p('Dev'))]);
    expect(story.steps[3].threads, [thread(p('Ana'), p('Ben'))]);
    // Faces: Ben takes the Troublemaker; Dev swaps it on to Ana.
    RoleId face(int step, String name) =>
        story.steps[step].after.players[id[name]]!.face;
    expect(story.dealt.players[id['Ben']]!.face, RoleId.robber);
    expect(face(1, 'Ben'), RoleId.robber);
    expect(face(2, 'Ben'), RoleId.troublemaker);
    expect(face(2, 'Dev'), RoleId.robber);
    expect(face(3, 'Ana'), RoleId.troublemaker);
    expect(face(3, 'Ben'), RoleId.seer);
  });

  test('the Doppelganger, the lone Werewolf, the Minion, the Drunk and the '
      'Insomniac', () {
    final story = storyOf('results_doppelganger');
    final id = idsOf('results_doppelganger');
    PlayerPlace p(String name) => PlayerPlace(id[name]!);
    expect(
      [for (final s in story.steps) s.line],
      [
        'Doppelganger Ana copies Ben: now a Seer.',
        'Doppelganger Ana peeks at two middle cards.',
        'Lone Werewolf Cleo peeks at a middle card.',
        'Minion Dev sees the Werewolves.',
        'Masons Esme and Fin meet.',
        'Drunk Gus swaps with a middle card.',
        'Insomniac Hana wakes: still Insomniac.',
      ],
      reason: "Ben's Seer did nothing: no step",
    );
    final [copy, copiedLook, lone, minion, masons, drunk, insomniac] =
        story.steps;
    // The copy: a look at Ben's card, and from then on Ana's card shows the
    // Seer and says "Doppelganger".
    expect(copy.kind, StoryKind.copy);
    expect(copy.threads, [thread(p('Ana'), p('Ben'))]);
    expect(story.dealt.players[id['Ana']], (
      face: RoleId.doppelganger,
      strip: RoleId.doppelganger,
    ));
    expect(copy.after.players[id['Ana']], (
      face: RoleId.seer,
      strip: RoleId.doppelganger,
    ));
    // The copied Seer's look at two middle cards.
    expect(copiedLook.kind, StoryKind.look);
    expect(copiedLook.threads, [
      thread(p('Ana'), const CenterPlace(0)),
      thread(p('Ana'), const CenterPlace(2)),
    ]);
    expect(copiedLook.werewolf, isFalse);
    // The lone Werewolf's look at the middle: red.
    expect(lone.threads, [thread(p('Cleo'), const CenterPlace(1))]);
    expect(lone.werewolf, isTrue);
    // The Minion sees the Werewolf: red, from the Minion.
    expect(minion.threads, [thread(p('Dev'), p('Cleo'))]);
    expect(minion.werewolf, isTrue);
    expect(masons.threads, [thread(p('Esme'), p('Fin'))]);
    expect(masons.werewolf, isFalse);
    // The Drunk takes the left middle card: the cards trade faces.
    expect(drunk.kind, StoryKind.take);
    expect(drunk.threads, [thread(p('Gus'), const CenterPlace(0))]);
    expect(drunk.after.players[id['Gus']]!.face, RoleId.werewolf);
    expect(drunk.after.centre[0].face, RoleId.drunk);
    expect(story.before(5).centre[0].face, RoleId.werewolf);
    // The Insomniac looks at her own card: no thread, her card is the place.
    expect(insomniac.threads, isEmpty);
    expect(insomniac.places, [p('Hana')]);
  });

  test('a Doppelganger who copied a Werewolf wakes with the Werewolves', () {
    final story = storyOf('results_tanner');
    final id = idsOf('results_tanner');
    final [copy, wolves, ..._] = story.steps;
    expect(copy.after.players[id['Ana']]!.face, RoleId.werewolf);
    expect(copy.werewolf, isFalse, reason: 'the copy is the Doppelganger’s');
    expect(wolves.line, 'Werewolves Ana and Cleo meet.');
    expect(wolves.werewolf, isTrue);
    // The Drunk the server moved (he chose nothing): still his step.
    final drunk = story.steps.firstWhere((s) => s.kind == StoryKind.take);
    expect(drunk.line, 'Drunk Gus swaps with a middle card.');
  });

  test('a dead card that moved: Ben robs the Werewolf he hangs with', () {
    final story = storyOf('results_moved_dead_card');
    final id = idsOf('results_moved_dead_card');
    final robbery = story.steps.last;
    expect(robbery.line, "Robber Ben takes Cleo's card.");
    expect(robbery.after.players[id['Ben']]!.face, RoleId.werewolf);
    expect(robbery.after.players[id['Cleo']]!.face, RoleId.robber);
  });

  test('steps that did nothing are left out', () {
    final story = storyOf('results_tie');
    expect(
      [for (final s in story.steps) s.line],
      ['Werewolves Cleo and Esme meet.'],
    );
  });

  test('a lone Werewolf who woke alone: no thread, her own card', () {
    final story = storyOf('results_three_players');
    expect(story.steps.first.line, 'Werewolf Ana is alone.');
    expect(story.steps.first.threads, isEmpty);
    expect(story.steps.first.places, hasLength(1));
  });

  test('ten players: the steps are the recording’s', () {
    final outcome = outcomeOf(endSamples['doppelganger_10']!);
    final story = endStoryOf(outcome)!;
    expect(story.steps, hasLength(7));
    expect(story.dealt.players, hasLength(10));
  });
}
