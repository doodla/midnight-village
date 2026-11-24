import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/features/lobby/domain/lobby_state.dart';
import 'package:midnight_village/features/lobby/domain/settings_lane.dart';

import '../../../helpers/contract/contract_samples.dart';
import '../../../helpers/contract/from_sample.dart';
import '../../../helpers/contract/server_json.dart';

// The host's settings lane as a pure value (`SettingsLane`): one test per
// rule of the model (`docs/dev/models/phone/lobby/README.md`, `PhoneLobby.tla`)
// as far as the lane holds it, the known gaps pinned as they are today. What
// the lane does not hold (the reads, the socket, the server) is pinned on the
// notifier: `settings_lane_order_test.dart`.

/// The server's lobby with [settings] (a recorded body).
LobbyState _server(Map<String, Object?> settings) => FromSample.lobby(
  withValues(serverLobby(), {'settings': Map<String, Object?>.of(settings)}),
);

const _roles = {'Werewolf': 2, 'Seer': 1, 'Robber': 1, 'Villager': 2};
final _table = _server(const {
  'roles': _roles,
  'seats': 4,
  'card_look_seconds': 240,
});

LaneChange Function(int) _settings(Map<String, Object?> patch) =>
    (n) => SettingsChange(patch, n);
LaneChange Function(int) _practice(PracticeAsk ask) =>
    (n) => PracticeChange(ask, n);

/// [lane] with each of [makes] asked, in order.
SettingsLane _asked(SettingsLane lane, List<LaneChange Function(int)> makes) {
  var next = lane;
  for (final make in makes) {
    (next, _) = next.ask(make);
  }
  return next;
}

/// [lane] with its next change sent and [answer]ed.
SettingsLane _sent(
  SettingsLane lane,
  SettingsLane Function(SettingsLane) answer,
) {
  final (out, change) = lane.sendNext();
  expect(change, isNotNull, reason: 'a change to send');
  return answer(out);
}

/// What the request of [change] carries.
Object _body(LaneChange change) => switch (change) {
  SettingsChange(:final patch) => patch,
  PracticeChange(:final ask) => ask,
};

/// What "Try again" would send now, oldest first (each made with a number).
List<LaneChange> _resent(SettingsLane lane) {
  final (_, again) = lane.takeResend();
  return [for (final (i, make) in again.indexed) make(100 + i)];
}

void main() {
  group('NeverOlder: one lane, tap order, one out at a time', () {
    test('each change is numbered in the order asked and waits in that '
        'order, settings and practice together', () {
      final lane = _asked(SettingsLane.empty, [
        _settings({'seats': 5}),
        _practice(const PracticeAsk(on: true)),
        _settings({'seats': 6}),
      ]);
      expect([for (final c in lane.pending) c.number], [1, 2, 3]);
      expect(
        [for (final c in lane.pending) _body(c)],
        [
          {'seats': 5},
          const PracticeAsk(on: true),
          {'seats': 6},
        ],
      );
      expect(lane.out, isNull, reason: 'asking sends nothing by itself');
    });

    test('the oldest goes first, and nothing more while it is out', () {
      var lane = _asked(SettingsLane.empty, [
        _settings({'seats': 5}),
        _settings({'seats': 6}),
      ]);
      final (sending, first) = lane.sendNext();
      lane = sending;
      expect(_body(first!), {'seats': 5});
      expect(lane.out, same(first));
      final (still, second) = lane.sendNext();
      expect(second, isNull, reason: 'one out at a time');
      expect(still, same(lane));
    });

    test('every tap is sent, two on one key both (no coalescing)', () {
      var lane = _asked(SettingsLane.empty, [
        _settings({'seats': 5}),
        _settings({'seats': 6}),
        _settings({'seats': 7}),
      ]);
      final bodies = <Object>[];
      while (true) {
        final (out, change) = lane.sendNext();
        if (change == null) break;
        bodies.add(_body(change));
        lane = out.settle();
      }
      expect(bodies, [
        {'seats': 5},
        {'seats': 6},
        {'seats': 7},
      ]);
      expect(lane.pending, isEmpty);
    });

    test('an empty lane has nothing to send', () {
      final (lane, change) = SettingsLane.empty.sendNext();
      expect(change, isNull);
      expect(lane.out, isNull);
    });

    test('after a 403 (host gone, settled like any answer) each later change '
        'is still sent', () {
      var lane = _asked(SettingsLane.empty, [
        _settings({'seats': 5}),
        _settings({'card_look_seconds': 300}),
      ]);
      lane = _sent(lane, (l) => l.settle());
      final (_, next) = lane.sendNext();
      expect(_body(next!), {'card_look_seconds': 300});
    });
  });

  group('Shown: the screen is the server\'s lobby with every pending change '
      'over it, in order', () {
    test('settings merged in tap order, the newest on a key winning', () {
      final lane = _asked(SettingsLane.empty, [
        _settings({'seats': 5}),
        _settings({'card_look_seconds': 300}),
        _settings({'seats': 6}),
      ]);
      final shown = lane.over(_table);
      expect(shown.table.seats, 6);
      expect(shown.table.raw['card_look_seconds'], 300);
      expect(shown.pendingKeys, {'seats', 'card_look_seconds'});
      expect(shown.settling, isTrue);
    });

    test('a custom deck shows its roles; the rest of the lobby is the '
        "server's", () {
      const roles = {'Werewolf': 2, 'Seer': 1, 'Villager': 3};
      final lane = _asked(SettingsLane.empty, [
        _settings({'deck': 'custom', 'roles': roles, 'seats': 6}),
      ]);
      final server = _server(const {
        'roles': _roles,
        'seats': 4,
        'card_look_seconds': 360,
      });
      final shown = lane.over(server);
      expect(shown.roleConfig, roles);
      expect(shown.table.seats, 6);
      expect(shown.table.raw['card_look_seconds'], 360);
      expect(shown.pendingKeys, {'deck', 'roles', 'seats'});
    });

    test('practice changes fold as the server applies them, under one key', () {
      final three = FromSample.lobby(
        ContractSamples.map('http/lobby/practice_three'),
      );
      final lane = _asked(SettingsLane.empty, [
        _practice(const PracticeAsk(count: 4)),
        _practice(const PracticeAsk(count: 5)),
        _practice(const PracticeAsk(count: 4)),
      ]);
      final shown = lane.over(three);
      expect(shown.practiceAsk, const PracticeAsk(on: true, count: 4));
      expect(shown.practiceCount, 4);
      expect(shown.pendingKeys, {PracticeAsk.key});
    });

    test('nothing pending: the server\'s lobby, settled, no practice ask', () {
      final shown = SettingsLane.empty.over(
        _table.copyWith(
          pendingKeys: const {'seats'},
          practiceAsk: const PracticeAsk(on: true),
        ),
      );
      expect(shown.pendingKeys, isEmpty);
      expect(shown.settling, isFalse);
      expect(shown.practiceAsk, isNull);
      expect(shown.table, _table.table);
    });

    test('an answered change is no longer laid over: the answer shows, the '
        'rest of the queue over it', () {
      var lane = _asked(SettingsLane.empty, [
        _settings({'seats': 5}),
        _settings({'card_look_seconds': 300}),
      ]);
      lane = _sent(lane, (l) => l.settle());
      final answer = _server(const {
        'roles': _roles,
        'seats': 5,
        'card_look_seconds': 240,
      });
      final shown = lane.over(answer);
      expect(shown.table.seats, 5);
      expect(shown.table.raw['card_look_seconds'], 300);
      expect(shown.pendingKeys, {'card_look_seconds'});
    });

    test('KNOWN GAP (a), NoFlickerBack: an answered change is dropped at '
        'once, so an older lobby laid under the lane shows the old value', () {
      var lane = _asked(SettingsLane.empty, [
        _settings({'seats': 5}),
      ]);
      lane = _sent(lane, (l) => l.settle());
      // A read served before the answer. Fixed (a "confirming" leg), 5.
      expect(lane.over(_table).table.seats, 4);
    });
  });

  group('a refusal and a loss', () {
    test('a refusal (an answer) is dropped: never "Not sent.", never kept '
        'for Try again', () {
      var lane = _asked(SettingsLane.empty, [
        _settings({'seats': 5}),
      ]);
      lane = _sent(lane, (l) => l.settle());
      expect(lane.pending, isEmpty);
      expect(lane.unsent, isEmpty);
      expect(lane.notSent, isFalse);
      expect(lane.tryAgain, isNull);
    });

    test('a loss is dropped from the queue, kept for Try again, and says '
        '"Not sent."; the next change goes on', () {
      var lane = _asked(SettingsLane.empty, [
        _settings({'seats': 5}),
        _settings({'card_look_seconds': 300}),
      ]);
      lane = _sent(lane, (l) => l.lose());
      expect(
        [for (final c in lane.unsent) _body(c)],
        [
          {'seats': 5},
        ],
      );
      expect(lane.notSent, isTrue);
      expect(lane.tryAgain, TryAgain.resend);
      expect(lane.out, isNull);
      expect(lane.over(_table).pendingKeys, {'card_look_seconds'});
      final (_, next) = lane.sendNext();
      expect(_body(next!), {'card_look_seconds': 300});
    });

    test('an answer with nothing out changes nothing', () {
      final lane = _asked(SettingsLane.empty, [
        _settings({'seats': 5}),
      ]);
      expect(lane.settle(), same(lane));
      expect(lane.lose(), same(lane));
    });
  });

  group('NeverOlder: Try again never undoes a newer change', () {
    test('a lost change is trimmed to the keys nothing newer asked for, '
        'and goes at the back of the queue, renumbered', () {
      const roles = {'Werewolf': 2, 'Seer': 1, 'Villager': 3};
      var lane = _asked(SettingsLane.empty, [
        _settings({'deck': 'custom', 'roles': roles, 'seats': 6}),
        _settings({'seats': 7}),
      ]);
      lane = _sent(lane, (l) => l.lose());
      final (retried, again) = lane.takeRetry();
      expect(again, TryAgain.resend);
      final (emptied, makes) = retried.takeResend();
      expect(emptied.unsent, isEmpty);
      lane = _asked(emptied, makes);
      expect([for (final c in lane.pending) c.number], [2, 3]);
      expect(
        [for (final c in lane.pending) _body(c)],
        [
          {'seats': 7},
          {'deck': 'custom', 'roles': roles},
        ],
      );
      expect(lane.over(_table).table.seats, 7);
    });

    test('a resent change counts as the newest ask on its keys', () {
      var lane = _asked(SettingsLane.empty, [
        _settings({'seats': 5}),
      ]);
      lane = _sent(lane, (l) => l.lose());
      final (emptied, makes) = lane.takeResend();
      lane = _asked(emptied, makes);
      // The resent one is lost again: Try again sends it once more.
      lane = _sent(lane, (l) => l.lose());
      expect(
        [for (final c in _resent(lane)) _body(c)],
        [
          {'seats': 5},
        ],
      );
    });

    test('LATE (known_late): a newer ask on the same key leaves the lost '
        'change nothing to send, so the phone never resends it', () {
      var lane = _asked(SettingsLane.empty, [
        _settings({'seats': 5}),
        _settings({'seats': 6}),
      ]);
      lane = _sent(lane, (l) => l.lose());
      expect(lane.unsent, hasLength(1));
      expect(_resent(lane), isEmpty, reason: 'an empty trim is not sent');
      // The server applying the lost request late is the server's (#16).
    });

    test('a practice change keeps its ask when resent', () {
      var lane = _asked(SettingsLane.empty, [
        _practice(const PracticeAsk(count: 2)),
      ]);
      lane = _sent(lane, (l) => l.lose());
      final again = _resent(lane).single;
      expect(again, isA<PracticeChange>());
      expect(_body(again), const PracticeAsk(count: 2));
      expect(again.keys, {PracticeAsk.key});
    });
  });

  group('the one "Try again" slot, shared with the deal', () {
    test('Try again empties the slot and takes "Not sent." away', () {
      var lane = _asked(SettingsLane.empty, [
        _settings({'seats': 5}),
      ]);
      lane = _sent(lane, (l) => l.lose());
      final (after, again) = lane.takeRetry();
      expect(again, TryAgain.resend);
      expect(after.tryAgain, isNull);
      expect(after.notSent, isFalse);
      expect(after.unsent, hasLength(1), reason: 'taken by takeResend');
      final (_, none) = after.takeRetry();
      expect(none, isNull);
    });

    test('a lost deal says "Not sent." and Try again is the deal', () {
      final lane = SettingsLane.empty.dealLost();
      expect(lane.notSent, isTrue);
      expect(lane.takeRetry().$2, TryAgain.deal);
    });

    test('a taken deal empties the slot but leaves "Not sent." as it was; '
        'a refused deal clears both', () {
      var lane = _asked(SettingsLane.empty, [
        _settings({'seats': 5}),
      ]);
      lane = _sent(lane, (l) => l.lose());
      final taken = lane.dealTaken();
      expect(taken.tryAgain, isNull);
      expect(taken.notSent, isTrue, reason: 'the game opens over it');
      final refused = lane.dealRefused();
      expect(refused.tryAgain, isNull);
      expect(refused.notSent, isFalse);
      expect(refused.unsent, hasLength(1), reason: 'unsaid: gap (c)');
    });

    test('KNOWN GAP (b), LostFlagged: a new tap takes "Not sent." away '
        'while the lost change still waits in the slot', () {
      var lane = _asked(SettingsLane.empty, [
        _settings({'seats': 5}),
      ]);
      lane = _sent(lane, (l) => l.lose());
      lane = _asked(lane, [_practice(const PracticeAsk(on: true))]);
      // Fixed, "Not sent." stays.
      expect(lane.notSent, isFalse);
      expect(lane.tryAgain, TryAgain.resend);
      expect(lane.unsent, hasLength(1));
    });

    test('KNOWN GAP (b2), NoHiddenResend: Try again resends the hidden lost '
        'change too, oldest first', () {
      var lane = _asked(SettingsLane.empty, [
        _settings({'seats': 5}),
      ]);
      lane = _sent(lane, (l) => l.lose());
      lane = _asked(lane, [_practice(const PracticeAsk(on: true))]);
      lane = _sent(lane, (l) => l.lose());
      expect(lane.notSent, isTrue);
      final (retried, again) = lane.takeRetry();
      expect(again, TryAgain.resend);
      // Fixed, only the practice switch.
      expect(
        [for (final c in _resent(retried)) _body(c)],
        [
          {'seats': 5},
          const PracticeAsk(on: true),
        ],
      );
    });

    test('KNOWN GAP (c), RetryCoversAll: a lost deal after a lost change '
        'takes the slot; Try again is the deal only', () {
      var lane = _asked(SettingsLane.empty, [
        _settings({'seats': 5}),
      ]);
      lane = _sent(lane, (l) => l.lose());
      expect(lane.over(_table).settling, isFalse, reason: 'Deal is live');
      lane = lane.dealLost();
      final (after, again) = lane.takeRetry();
      // Fixed, the seats go too.
      expect(again, TryAgain.deal);
      expect(after.unsent, hasLength(1));
    });
  });
}
