import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/features/game/domain/game_me.dart';
import 'package:midnight_village/features/lobby/domain/lobby_state.dart';

import '../../../helpers/contract/from_sample.dart';
import '../../../helpers/contract/contract_samples.dart';
import '../../../helpers/sheet/sheet_data.dart' show recordedMe;

// Practice players as the app reads them from what the server sends
// (`players[].practice`, the lobby's `practice`), and as it shows them while
// a change of the host's is on its way (`PracticeAsk`).

void main() {
  group('the lobby body', () {
    test('a table that never used them: nobody is practice, switched off', () {
      final lobby = FromSample.lobby(
        ContractSamples.map('http/lobby/detail_seats_8_full'),
      );
      expect(lobby.players.where((p) => p.practice), isEmpty);
      expect(lobby.practiceMost, isNull);
      expect(lobby.practiceOn, isFalse);
      expect(lobby.practiceCount, 0);
    });

    test('switched on with nobody seated: on, none, the server\'s most', () {
      final body = ContractSamples.map('http/lobby/practice_on');
      final lobby = FromSample.lobby(body);
      expect(lobby.practiceOn, isTrue);
      expect(lobby.practiceCount, 0);
      expect(lobby.practiceLimit, (body['practice'] as Map)['most']);
    });

    test('three seated: each marked, always here, counted', () {
      final lobby = FromSample.lobby(
        ContractSamples.map('http/lobby/practice_three'),
      );
      final practice = lobby.players.where((p) => p.practice).toList();
      expect(practice.map((p) => p.displayName), [
        'Scarecrow',
        'Teapot',
        'Broom',
      ]);
      expect(practice.every((p) => p.connected), isTrue);
      expect(lobby.practiceCount, 3);
      expect(lobby.players.where((p) => !p.practice).single.displayName, 'Pia');
    });

    test('switched off: as a table that never used them', () {
      final lobby = FromSample.lobby(
        ContractSamples.map('http/lobby/practice_off'),
      );
      expect(lobby.practiceOn, isFalse);
      expect(lobby.players.where((p) => p.practice), isEmpty);
    });
  });

  group('a change on its way shows at once', () {
    final three = FromSample.lobby(
      ContractSamples.map('http/lobby/practice_three'),
    );
    final off = FromSample.lobby(
      ContractSamples.map('http/lobby/detail_seats_8_full'),
    );

    test('switching on a table that has none', () {
      final asked = off.copyWith(practiceAsk: const PracticeAsk(on: true));
      expect(asked.practiceOn, isTrue);
      expect(asked.practiceCount, 0);
      // Before the server says how many may sit: the seats no person holds.
      expect(asked.practiceLimit, 0, reason: 'eight of eight are here');
    });

    test('a count asked is the count shown', () {
      expect(
        three.copyWith(practiceAsk: const PracticeAsk(count: 1)).practiceCount,
        1,
      );
    });

    test('switching off shows none at once', () {
      final asked = three.copyWith(practiceAsk: const PracticeAsk(on: false));
      expect(asked.practiceOn, isFalse);
      expect(asked.practiceCount, 0);
    });
  });

  group('several changes on their way fold as the server applies them', () {
    PracticeAsk fold(List<PracticeAsk> asks) =>
        asks.fold(const PracticeAsk(), (a, b) => a.then(b));

    test('switched on, then + + − −: still on, at 0', () {
      expect(
        fold(const [
          PracticeAsk(on: true),
          PracticeAsk(count: 1),
          PracticeAsk(count: 2),
          PracticeAsk(count: 1),
          PracticeAsk(count: 0),
        ]),
        const PracticeAsk(on: true, count: 0),
      );
    });

    test('a count alone switches on; 0 alone leaves the switch as it is', () {
      expect(fold(const [PracticeAsk(count: 2)]).on, isTrue);
      expect(fold(const [PracticeAsk(count: 0)]).on, isNull);
    });

    test('off takes every one away; on again starts from none', () {
      expect(
        fold(const [PracticeAsk(count: 3), PracticeAsk(on: false)]),
        const PracticeAsk(on: false, count: 0),
      );
      expect(
        fold(const [PracticeAsk(on: false), PracticeAsk(on: true)]),
        const PracticeAsk(on: true, count: 0),
      );
    });

    test('Deal waits: a practice change on its way is pending', () {
      final three = FromSample.lobby(
        ContractSamples.map('http/lobby/practice_three'),
      );
      expect(DealState.of(three), isA<CanDeal>());
      final asked = three.copyWith(
        practiceAsk: const PracticeAsk(count: 2),
        pendingKeys: const {PracticeAsk.key},
      );
      expect(asked.seatedCount, 3);
      expect(DealState.of(asked), isNot(isA<CanDeal>()));
    });
  });

  group('the game', () {
    test("/me/ names the practice players (and an older body's none)", () {
      final me = GameMe.fromJson(recordedMe('me_voting_practice'));
      final names = {
        for (final seat in me.seats)
          if (me.practiceIds.contains(seat.id)) seat.name,
      };
      expect(names, {'Scarecrow', 'Teapot'});
      expect(
        GameMe.fromJson(recordedMe('me_voting_unpicked')).practiceIds,
        isEmpty,
      );
    });
  });
}
