import 'dart:convert';
import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/features/game/presentation/stage_seconds.dart';

import '../../../helpers/contract/contract_samples.dart';
import '../../../helpers/contract/contract_shape.dart';
import '../../../helpers/live_game_setup.dart';

// A whole talk, played on a phone while everything a real game sends arrives
// in seeded random orders: every frame the server sends on a game socket (from
// the recorded samples, so a new kind is in the next run), `/me/` reads whose
// `Date` the live host holds up to 20 s, the socket dropping and coming back,
// the app coming back. After each, the clock the phone shows must be within a
// second of the true time left and never more than it showed before
// (owner, 28 November 2026: "The timer is fucked. Keeps jumping around").

void main() {
  final night = ContractSamples.map('ws/game/me_night')['me'] as Map;
  final talk = (ContractSamples.map('ws/game/me_talk')['me'] as Map)
      .cast<String, dynamic>();
  final opened = DateTime.parse(talk['stage_started_at'] as String);
  final deadline = DateTime.parse(talk['deadline'] as String);

  /// Every frame the server sends on a game socket, as it would during the
  /// talk: a view is the talk's, a phase or a deadline the talk's.
  final frames = [
    for (final s in ContractSamples.index)
      if (s.kind == 'ws' && s.socket == 'game')
        if (s.type == 'me')
          {'type': 'me', 'me': talk}
        else
          {
            ...ContractSamples.map(s.name),
            if (ContractSamples.map(s.name).containsKey('phase'))
              'phase': 'discussion',
            if (ContractSamples.map(s.name).containsKey('deadline'))
              'deadline': talk['deadline'],
          },
  ];

  for (var seed = 1; seed <= 12; seed++) {
    test('seed $seed: the shown clock never counts up and stays within a '
        'second of the time left', () async {
      final random = Random(seed);
      var server = opened.subtract(const Duration(seconds: 7));
      final skew = Duration(minutes: random.nextInt(21) - 10);
      final setup = LiveGameSetup.create(
        night.cast<String, dynamic>(),
        clock: () => server.add(skew),
      );
      addTearDown(setup.dispose);
      DateTime held() {
        final at = server.subtract(Duration(seconds: random.nextInt(21)));
        return at.subtract(Duration(milliseconds: at.millisecond));
      }

      setup.answerMe(night.cast<String, dynamic>(), serverDate: held());
      await setup.load();
      server = opened.add(Duration(milliseconds: 50 + random.nextInt(300)));
      setup.answerMe(talk, serverDate: held());
      setup.ws.addServerEvent(jsonEncode({'type': 'me', 'me': talk}));
      await setup.settle();

      final kinds = <String, Future<void> Function()>{
        for (final frame in frames)
          'frame ${frame['type']}': () async {
            checkSocketEvent(frame);
            setup.ws.addServerEvent(jsonEncode(frame));
          },
        'a /me/ read': () => setup.notifier.refresh(),
        'the socket drops and is back': () async => setup.reconnect(),
        'the app comes back': () async => setup.resume(),
      };
      final names = kinds.keys.toList();
      int? before;
      final seen = <String>[];
      while (server.isBefore(deadline)) {
        server = server.add(Duration(milliseconds: 50 + random.nextInt(2500)));
        final kind = names[random.nextInt(names.length)];
        seen.add(kind);
        setup.answerMe(talk, serverDate: held());
        await kinds[kind]!();
        await setup.settle();
        final left = setup.notifier.untilServer(deadline);
        final truth = deadline.difference(server);
        final shown = Countdown.secondsFor(left);
        final at = 'after ${seen.length} steps (last: $kind)';
        expect(
          (left - truth).abs(),
          lessThanOrEqualTo(const Duration(seconds: 1)),
          reason: '$at: shows $left left, the server has $truth',
        );
        if (before != null) {
          expect(shown, lessThanOrEqualTo(before), reason: '$at: counted up');
        }
        before = shown;
      }
      expect(seen.toSet(), names.toSet(), reason: 'every kind arrived');
    });
  }
}
