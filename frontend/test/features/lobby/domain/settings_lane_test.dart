import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/features/lobby/domain/lobby_state.dart';
import 'package:midnight_village/features/lobby/domain/settings_lane.dart';

import '../../../helpers/contract/contract_samples.dart';
import '../../../helpers/contract/from_sample.dart';
import '../../../helpers/contract/server_json.dart';

// The host's settings lane as a pure value (`SettingsLane`): one test per
// rule of the model (`docs/dev/models/phone/lobby/README.md`, `PhoneLobby.tla`)
// as far as the lane holds it. What the lane does not hold (the reads, the
// socket, the server) is pinned on the notifier: `settings_lane_order_test.dart`.

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

/// The server's lobby with [seats] (the rest as [_table]).
LobbyState _seats(int seats) =>
    _server({'roles': _roles, 'seats': seats, 'card_look_seconds': 240});

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

/// [lane]'s change out taken (its answer is shown as `admit` says).
SettingsLane _take(SettingsLane lane) => lane.taken();

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
        lane = _take(out);
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

    test('GuestQuiet (D): after a 403 the lane forgets everything it would '
        'send: no "Not sent." on a guest\'s phone', () {
      var lane = _asked(SettingsLane.empty, [
        _settings({'seats': 5}),
      ]);
      lane = _sent(lane, (l) => l.lose()).dealLost();
      lane = _asked(lane, [
        _settings({'card_look_seconds': 300}),
        _practice(const PracticeAsk(on: true)),
      ]);
      expect(lane.notSent, isTrue);
      lane = _sent(lane, (l) => l.settle());
      expect(lane.notSent, isFalse);
      expect(lane.dealHeld, isFalse);
      expect(lane.unsent, isEmpty);
      expect(lane.pending, isEmpty, reason: 'each would meet its own 403');
      expect(lane.sendNext().$2, isNull);
      expect(lane.over(_table).settling, isFalse);
      // A 403 on the deal itself (nothing out) settles the same way.
      final waiting = lane.dealBehind().settle();
      expect(waiting.dealWaiting, isFalse);
      final (settled, go) = waiting.dealGoes();
      expect(go, isFalse);
      expect(settled.notSent, isFalse, reason: 'a guest: nothing said');
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

    test('an answered change is no longer pending: the answer shows, the '
        'rest of the queue over it', () {
      var lane = _asked(SettingsLane.empty, [
        _settings({'seats': 5}),
        _settings({'card_look_seconds': 300}),
      ]);
      lane = _sent(lane, _take);
      final shown = lane.over(_seats(5));
      expect(shown.table.seats, 5);
      expect(shown.table.raw['card_look_seconds'], 300);
      expect(shown.pendingKeys, {'card_look_seconds'});
    });
  });

  group('NoFlickerBack (A): a server lobby older than the newest shown is '
      'never shown', () {
    test('older is not shown; equal and newer are', () {
      final (seven, shown) = SettingsLane.empty.admit(7);
      expect(shown, isTrue, reason: 'the first lobby');
      expect(seven.admit(6).$2, isFalse, reason: 'older');
      expect(seven.admit(7).$2, isTrue, reason: 'equal: presence may differ');
      final (eight, newer) = seven.admit(8);
      expect(newer, isTrue);
      expect(eight.admit(7).$2, isFalse, reason: 'the newest shown is 8 now');
    });

    test('an older lobby leaves the lane as it was', () {
      final (seven, _) = SettingsLane.empty.admit(7);
      final (after, _) = seven.admit(5);
      expect(identical(after, seven), isTrue);
    });

    test('a lobby with no rev (a server from before it) is always shown, and '
        'leaves the newest number as it was', () {
      final (seven, _) = SettingsLane.empty.admit(7);
      final (none, shown) = seven.admit(null);
      expect(shown, isTrue);
      expect(none.admits(6), isFalse);
      expect(SettingsLane.empty.admits(null), isTrue);
    });

    test('an answered change is not held over the screen: the answer, or a '
        'newer lobby, is what shows', () {
      var lane = _asked(SettingsLane.empty, [
        _settings({'seats': 5}),
      ]);
      lane = _sent(lane, _take);
      expect(lane.over(_seats(7)).table.seats, 7, reason: 'someone else');
      expect(lane.over(_seats(5)).settling, isFalse);
    });
  });

  group('the screen shows what will go (E)', () {
    test('a lost change lies over the server\'s value while Try again would '
        'still send it, with "Not sent."', () {
      var lane = _asked(SettingsLane.empty, [
        _settings({'seats': 5}),
      ]);
      lane = _sent(lane, (l) => l.lose());
      final shown = lane.over(_table);
      expect(shown.table.seats, 5);
      expect(shown.notSent, isTrue);
      expect(
        shown.settling,
        isFalse,
        reason: 'lost, not pending: Deal is live',
      );
    });

    test('a newer tap on its key covers it; once answered, the server\'s '
        'value shows, never the lost one', () {
      var lane = _asked(SettingsLane.empty, [
        _settings({'seats': 5}),
      ]);
      lane = _sent(lane, (l) => l.lose());
      lane = _asked(lane, [
        _settings({'seats': 6}),
      ]);
      expect(lane.over(_table).table.seats, 6);
      lane = _sent(lane, _take);
      expect(lane.over(_seats(7)).table.seats, 7);
    });

    test('only the keys no newer change asked for lie over it', () {
      const roles = {'Werewolf': 2, 'Seer': 1, 'Villager': 3};
      var lane = _asked(SettingsLane.empty, [
        _settings({'deck': 'custom', 'roles': roles, 'seats': 6}),
        _settings({'seats': 7}),
      ]);
      lane = _sent(lane, (l) => l.lose());
      lane = _sent(lane, _take);
      final shown = lane.over(_seats(7));
      expect(shown.roleConfig, roles);
      expect(shown.table.seats, 7);
    });

    test('a lost practice change lies over too', () {
      final three = FromSample.lobby(
        ContractSamples.map('http/lobby/practice_three'),
      );
      var lane = _asked(SettingsLane.empty, [
        _practice(const PracticeAsk(count: 5)),
      ]);
      lane = _sent(lane, (l) => l.lose());
      expect(lane.over(three).practiceCount, 5);
    });

    test('Try again or a deal takes them: they are pending then, the same '
        'values', () {
      var lane = _asked(SettingsLane.empty, [
        _settings({'seats': 5}),
      ]);
      lane = _sent(lane, (l) => l.lose());
      final before = lane.over(_table).table;
      final (taken, makes) = lane.takeResend();
      lane = _asked(taken, makes);
      expect(lane.over(_table).table, before);
      expect(lane.over(_table).notSent, isFalse);
    });
  });
  group('a refusal and a loss', () {
    test('a refused change is dropped and never sent again: no "Not sent.", '
        'nothing kept for Try again; its value stays shown until a lobby of '
        "the server's", () {
      var lane = _asked(SettingsLane.empty, [
        _settings({'seats': 5}),
      ]);
      lane = _sent(lane, (l) => l.refused());
      expect(lane.pending, isEmpty);
      expect(lane.sendNext().$2, isNull, reason: 'never sent again');
      expect(lane.unsent, isEmpty);
      expect(lane.notSent, isFalse);
      expect(lane.refusedShown, isTrue);
      expect(lane.over(_table).table.seats, 5, reason: 'until a server lobby');
      final (read, _) = lane.admit(null);
      expect(read.refusedShown, isFalse);
      expect(read.over(_table).table.seats, 4);
    });

    test('a refused value stays over an older lobby (not shown), and goes '
        'with an equal one', () {
      var lane = SettingsLane.empty.admit(3).$1;
      lane = _asked(lane, [
        _settings({'seats': 5}),
      ]);
      lane = _sent(lane, (l) => l.refused());
      expect(lane.admit(2).$1.refusedShown, isTrue);
      expect(lane.admit(3).$1.refusedShown, isFalse);
    });

    test('a refused value under a newer tap on its key is covered by it', () {
      var lane = _asked(SettingsLane.empty, [
        _settings({'seats': 5}),
      ]);
      lane = _sent(lane, (l) => l.refused());
      lane = _asked(lane, [
        _settings({'seats': 6}),
      ]);
      expect(lane.over(_table).table.seats, 6);
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
      expect(lane.over(_table).notSent, isTrue, reason: 'the screen says it');
      expect(lane.out, isNull);
      expect(lane.over(_table).pendingKeys, {'card_look_seconds'});
      final (_, next) = lane.sendNext();
      expect(_body(next!), {'card_look_seconds': 300});
    });

    test('an answer with nothing out is a bug: asserted', () {
      final lane = _asked(SettingsLane.empty, [
        _settings({'seats': 5}),
      ]);
      expect(lane.taken, throwsA(isA<AssertionError>()));
      expect(lane.refused, throwsA(isA<AssertionError>()));
      expect(lane.lose, throwsA(isA<AssertionError>()));
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
      final (emptied, makes) = lane.takeResend();
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
      expect(lane.notSent, isFalse, reason: 'nothing left to send');
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

  group('LostFlagged, NoHiddenResend (b, b2): "Not sent." is derived', () {
    test('(b) a new tap on another key leaves "Not sent." while the lost '
        'change still waits for Try again', () {
      var lane = _asked(SettingsLane.empty, [
        _settings({'seats': 5}),
      ]);
      lane = _sent(lane, (l) => l.lose());
      lane = _asked(lane, [_practice(const PracticeAsk(on: true))]);
      expect(lane.notSent, isTrue);
      expect(lane.unsent, hasLength(1));
    });

    test('(b) a new tap on the same key takes it away: the lost value has '
        'nothing left to send', () {
      var lane = _asked(SettingsLane.empty, [
        _settings({'seats': 5}),
      ]);
      lane = _sent(lane, (l) => l.lose());
      lane = _asked(lane, [
        _settings({'seats': 6}),
      ]);
      expect(lane.notSent, isFalse);
      expect(_resent(lane), isEmpty);
    });

    test('(b2) Try again after two losses sends both, oldest first: '
        '"Not sent." showed for both all along', () {
      var lane = _asked(SettingsLane.empty, [
        _settings({'seats': 5}),
      ]);
      lane = _sent(lane, (l) => l.lose());
      lane = _asked(lane, [_practice(const PracticeAsk(on: true))]);
      expect(lane.notSent, isTrue, reason: 'never hidden');
      lane = _sent(lane, (l) => l.lose());
      expect(
        [for (final c in _resent(lane)) _body(c)],
        [
          {'seats': 5},
          const PracticeAsk(on: true),
        ],
      );
      final (after, _) = lane.takeResend();
      expect(after.notSent, isFalse, reason: 'all sent again');
    });
  });

  group('RetryCoversAll, DealAsShown (c): the deal goes behind the lane', () {
    test('a lost deal says "Not sent."; Try again deals', () {
      final lane = SettingsLane.empty.dealLost();
      expect(lane.notSent, isTrue);
      expect(lane.dealHeld, isTrue);
      expect(lane.dealBehind().notSent, isFalse);
    });

    test('a lost change and then a lost deal: both wait, the change is still '
        'sent again first, then the deal', () {
      var lane = _asked(SettingsLane.empty, [
        _settings({'seats': 5}),
      ]);
      lane = _sent(lane, (l) => l.lose());
      lane = lane.dealLost();
      expect(lane.dealHeld, isTrue);
      expect(
        [for (final c in _resent(lane)) _body(c)],
        [
          {'seats': 5},
        ],
      );
      final (resent, makes) = lane.takeResend();
      lane = _asked(resent, makes).dealBehind();
      expect(lane.notSent, isFalse);
      lane = _sent(lane, _take);
      final (_, go) = lane.dealGoes();
      expect(go, isTrue, reason: 'every change before it answered');
    });

    test('a change before the deal lost or refused keeps the deal back: '
        '"Not sent."', () {
      for (final lost in [true, false]) {
        var lane = _asked(SettingsLane.empty, [
          _settings({'seats': 5}),
        ]).dealBehind();
        lane = _sent(lane, (l) => lost ? l.lose() : l.refused());
        expect(lane.dealHeld, isTrue, reason: 'lost: $lost');
        expect(lane.notSent, isTrue, reason: 'lost: $lost');
        final (_, go) = lane.dealGoes();
        expect(go, isFalse, reason: 'lost: $lost');
      }
    });

    test('(B) a deal never ends silently: whenever its turn comes and it does '
        'not go, the lane says "Not sent."', () {
      final waiting = _asked(SettingsLane.empty, [
        _settings({'seats': 5}),
      ]).dealBehind();
      final (held, go) = waiting.dealGoes();
      expect(go, isFalse, reason: 'a change still before it');
      expect(held.dealHeld, isTrue);
      expect(held.notSent, isTrue);
      expect(held.dealWaiting, isFalse);
    });

    test('(B) a tap while the deal waits keeps it back at once: "Not sent.", '
        'and Try again deals what is shown then', () {
      var lane = _asked(SettingsLane.empty, [
        _settings({'seats': 5}),
      ]).dealBehind();
      lane = _asked(lane, [
        _settings({'card_look_seconds': 300}),
      ]);
      expect(lane.dealWaiting, isFalse);
      expect(lane.dealHeld, isTrue);
      expect(lane.notSent, isTrue);
      expect(lane.pending, hasLength(2), reason: 'the tap is still sent');
    });

    test('(B) a deal not waiting (held already, or settled by a 403) gives '
        'no second answer at its turn', () {
      final lost = SettingsLane.empty.dealBehind().dealLost();
      final (still, go) = lost.dealGoes();
      expect(go, isFalse);
      expect(still.dealHeld, isTrue);
    });

    test('a deal answered (taken or refused) is no longer held, but a lost '
        'change still says "Not sent."', () {
      var lane = _asked(SettingsLane.empty, [
        _settings({'seats': 5}),
      ]);
      lane = _sent(lane, (l) => l.lose()).dealLost();
      for (final answered in [lane.dealTaken(), lane.dealRefused()]) {
        expect(answered.dealHeld, isFalse);
        expect(answered.notSent, isTrue, reason: 'the seats still wait');
        expect(answered.unsent, hasLength(1));
      }
    });
  });
}
