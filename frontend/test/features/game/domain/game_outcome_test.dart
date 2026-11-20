import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/models/role.dart';
import 'package:midnight_village/features/game/domain/game_outcome.dart';
import 'package:midnight_village/features/game/domain/night_timeline.dart';

import '../../../helpers/contract/contract_samples.dart';
import '../../../helpers/contract/contract_shape.dart';

void main() {
  GameOutcome outcome(String name) {
    final body = ContractSamples.map('http/game/$name');
    checkHttpBody('GET', '/onuw/games/g/results/', 200, body);
    return GameOutcome.fromJson(body);
  }

  test('every recorded results body parses, with its timeline', () {
    for (final name in ['results', 'results_doppelganger', 'results_tanner']) {
      final json = ContractSamples.map('http/game/$name');
      final parsed = outcome(name);
      final players = json['players'] as List;
      expect(parsed.result.players, hasLength(players.length), reason: name);
      expect(parsed.seats.map((s) => s.seat), [
        for (var i = 0; i < players.length; i++) i,
      ]);
      final timeline = parsed.timeline!;
      expect(timeline.seats, hasLength(players.length), reason: name);
      expect(timeline.cards, hasLength(players.length + 3), reason: name);
      expect(timeline.centerMoved, hasLength(3));
      // Every step's positions name every card exactly once.
      for (final step in timeline.steps) {
        final placed = [
          ...step.positionsAfter.players.values,
          ...step.positionsAfter.center,
        ];
        expect(placed.toSet(), timeline.cards.keys.toSet(), reason: name);
      }
    }
  });

  test("the Doppelganger's copy and follow-up are read as the server says", () {
    final timeline = outcome('results_doppelganger').timeline!;
    final copy = timeline.steps.first;
    expect(copy.action, TimelineAction.copy);
    expect(copy.copiedRole, RoleId.seer);
    expect(copy.doppelgangerActors, copy.actors);
    expect(copy.lookedAt.single.place, const PlayerPlace(8));
    final followUp = timeline.steps[1];
    expect(followUp.action, TimelineAction.peekCenter);
    expect(
      [for (final l in followUp.lookedAt) l.place],
      const [CenterPlace(0), CenterPlace(2)],
    );
    // The drunk's swap moved a center card.
    expect(timeline.centerMoved.first, isTrue);
    expect(
      timeline.finalPositions.center.first,
      isNot(timeline.dealt.center.first),
    );
  });

  test('the shared results parser names vote targets from the results', () {
    final json = ContractSamples.map('http/game/results');
    final result = outcome('results').result;
    for (final (i, p) in (json['players'] as List).cast<Map>().indexed) {
      final target = p['vote_target_id'] as int?;
      expect(result.players[i].voteTargetId, target?.toString());
      if (target != null) expect(result.players[i].voteTargetName, isNotNull);
    }
  });

  test('a timeline the server could not build (null) leaves the rest', () {
    // The server sends null for an old game; the key is still sent.
    final json = ContractSamples.map('http/game/results')
      ..['night_timeline'] = null;
    expect(GameOutcome.fromJson(json).timeline, isNull);
    expect(GameOutcome.fromJson(json).result.players, isNotEmpty);
  });
}
