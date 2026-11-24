import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/features/game/presentation/stage_seconds.dart';

import '../../../helpers/live_game_setup.dart';

// The seconds a countdown shows are the server's, whatever the phone's own
// clock says (issue 15). The server stamps every `/me/` answer with its time
// (the `Date` header); the phone counts from that stamp with a stopwatch and
// never compares its own clock with the server's. So a phone whose clock is
// minutes ahead, minutes behind or years off shows the same number as one
// that is right. `StageSeconds` (every countdown on 05, 06, 08 and 09) shows
// exactly `secondsFor(untilServer(deadline))`, which is what is read here.

void main() {
  final me = recordedMe('me_choose_prompt_seer');
  final deadline = DateTime.parse(me['deadline'] as String);

  /// The seconds a countdown shows on a phone whose clock reads [phone],
  /// when the server answered `/me/` at [server].
  Future<int> shown({required DateTime phone, DateTime? server}) async {
    final setup = LiveGameSetup.create(me, clock: () => phone);
    addTearDown(setup.dispose);
    setup.answerMe(me, serverDate: server);
    await setup.load();
    return StageSeconds.secondsFor(setup.notifier.untilServer(deadline));
  }

  // The server answered with 20 s of the stage left.
  final server = deadline.subtract(const Duration(seconds: 20));

  for (final (name, phone) in [
    ('right', server),
    ('7 minutes ahead', server.add(const Duration(minutes: 7))),
    ('7 minutes behind', server.subtract(const Duration(minutes: 7))),
    (
      'past the deadline by its own reckoning',
      deadline.add(const Duration(hours: 3)),
    ),
    ('years off', DateTime.utc(2030)),
  ]) {
    test(
      'a phone whose clock is $name shows the server\'s 20 seconds',
      () async {
        expect(await shown(phone: phone, server: server), 20);
      },
    );
  }

  test('the server past the deadline shows 0 on a phone that thinks there is '
      'time left', () async {
    final seconds = await shown(
      phone: deadline.subtract(const Duration(minutes: 5)),
      server: deadline.add(const Duration(seconds: 2)),
    );
    expect(seconds, 0);
  });

  test('an answer with no readable time falls back to the phone\'s own clock: '
      'the only case it is used', () async {
    final seconds = await shown(
      phone: deadline.subtract(const Duration(seconds: 12)),
    );
    expect(seconds, 12);
  });
}
