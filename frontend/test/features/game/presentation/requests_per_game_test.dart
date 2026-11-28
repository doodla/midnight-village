import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

import '../../../helpers/contract/contract_samples.dart';
import '../../../helpers/stream_replay.dart';

/// What every phone asks the server in a whole game at six seats.
///
/// Each seat of the recorded game (`ws_stream/six_seats`: a seeded six-seat
/// game as each phone saw it) is replayed through the strict mocks
/// ([SeatReplay]) and every request it makes is counted, by moment: the game
/// opening, each stage change, each tap. Two rules:
///
/// 1. **A stage change asks nothing.** The server tells each phone its own
///    view as a stage opens (`me`, before the table's event), so no phone
///    reads anything at a stage change, and none reads after its own tap (its
///    answer carries what it needs). Designed: 0 reads, every seat, every
///    stage change and tap.
/// 2. **Nothing grows quietly.** Each seat's counts are what
///    `request_budget.json` says under `after`; a change that asks more, or
///    less, fails until it is re-recorded (`UPDATE_REQUEST_BUDGET=after`) and
///    the diff reviewed. `before` is the phone of main before this rule
///    (`UPDATE_REQUEST_BUDGET=before` on that build), kept for comparison.
void main() {
  const stream = 'ws_stream/six_seats';
  final budgetFile = File(
    'test/features/game/presentation/request_budget.json',
  );
  final update = Platform.environment['UPDATE_REQUEST_BUDGET'];
  final seats = ContractSamples.stream(stream).keys.toList();
  final measured = <String, Map<String, Map<String, int>>>{};

  for (final seat in seats) {
    test('$seat asks nothing at a stage change or after its own tap', () async {
      final replay = SeatReplay.of(stream, seat);
      await replay.run();
      measured[seat] = replay.asked;
      if (update != null) return;
      final reads = <String>[
        for (final MapEntry(key: moment, value: asked) in replay.asked.entries)
          if (moment != 'open')
            for (final MapEntry(key: request, value: n) in asked.entries)
              if (request.startsWith('GET')) '$moment: $request x$n',
      ];
      expect(reads, isEmpty, reason: '$seat read after the server told it');
    });
  }

  test('every frame of the vote opening lost on a socket that stays alive: '
      'the beat costs one read of /me/, nothing else changes', () async {
    bool votesOpening(Map<String, dynamic> event) => switch (event['type']) {
      'me' => (event['me'] as Map)['phase'] == 'voting',
      'phase_change' => event['phase'] == 'voting',
      'progress' => event['stage'] == 'vote' && event['done'] == 0,
      _ => false,
    };
    final healthy = SeatReplay.of(stream, 'Ana');
    await healthy.run();
    final lost = SeatReplay.of(stream, 'Ana', lose: votesOpening);
    await lost.run();
    int reads(SeatReplay r) => [
      for (final asked in r.asked.values)
        for (final e in asked.entries)
          if (e.key.startsWith('GET')) e.value,
    ].fold(0, (a, b) => a + b);
    expect(reads(healthy), 4, reason: 'a healthy game: its opening only');
    expect(lost.asked['beat'], {'GET me': 1});
    expect(reads(lost), reads(healthy) + 1);
  });

  tearDownAll(() {
    if (measured.length != seats.length) return;
    final budget = budgetFile.existsSync()
        ? (jsonDecode(budgetFile.readAsStringSync()) as Map)
              .cast<String, dynamic>()
        : <String, dynamic>{};
    final counted = {
      for (final seat in seats)
        seat: {
          'moments': measured[seat],
          'total': {
            for (final moment in measured[seat]!.values)
              for (final e in moment.entries) e.key: 0,
          },
        },
    };
    for (final seat in seats) {
      final total = counted[seat]!['total']!;
      for (final moment in measured[seat]!.values) {
        for (final e in moment.entries) {
          total[e.key] = (total[e.key] as int) + e.value;
        }
      }
    }
    if (update != null) {
      budget['about'] =
          'Requests each phone makes in the six-seat game '
          '(requests_per_game_test.dart). Do not edit: re-record with '
          'UPDATE_REQUEST_BUDGET=after and review the diff.';
      budget[update] = counted;
      budgetFile.writeAsStringSync(
        '${const JsonEncoder.withIndent('  ').convert(budget)}\n',
      );
      return;
    }
    expect(
      jsonEncode(counted),
      jsonEncode(budget['after']),
      reason:
          'What a phone asks in a game changed: re-record with '
          'UPDATE_REQUEST_BUDGET=after and review the diff of '
          'request_budget.json.',
    );
  });
}
