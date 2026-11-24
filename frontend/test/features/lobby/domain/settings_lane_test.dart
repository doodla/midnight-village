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

/// [lane]'s change out taken: the server's answer is [_table] with it.
SettingsLane _take(SettingsLane lane) => lane.taken(
  _server({
    'roles': _roles,
    'seats': 4,
    'card_look_seconds': 240,
    if (lane.out case SettingsChange(:final patch)) ...patch,
  }),
);

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

  group('NoFlickerBack (a): an answered change stays laid over the screen '
      'until nothing older can land', () {
    SettingsLane fiveTaken() => _sent(
      _asked(SettingsLane.empty, [
        _settings({'seats': 5}),
      ]),
      _take,
    );

    test('a lobby older than the answer (a read served before it) shows the '
        'answered value, not the old one, and Deal is not held up', () {
      final shown = fiveTaken().over(_table);
      expect(shown.table.seats, 5);
      expect(shown.settling, isFalse, reason: 'answered: not pending');
    });

    test('its own lobby_update heard and no read out: it goes, and the '
        "server's lobby shows as it is", () {
      final lane = fiveTaken().heard(_seats(5));
      expect(lane.over(_seats(7)).table.seats, 7);
    });

    test('an older lobby_update (values it never had) leaves it laid', () {
      final lane = fiveTaken().heard(_table);
      expect(lane.over(_table).table.seats, 5);
    });

    test('heard while a read is out, it stays until the read is done', () {
      var lane = fiveTaken().readAsked().heard(_seats(5));
      expect(lane.over(_table).table.seats, 5, reason: 'the read may be old');
      lane = lane.readEnded();
      expect(lane.over(_seats(7)).table.seats, 7);
    });

    test('a read asked before the answer keeps it laid even with nothing '
        'more to hear', () {
      final asked = _asked(SettingsLane.empty, [
        _settings({'seats': 5}),
      ]).readAsked();
      var lane = _sent(asked, _take).socketDropped();
      expect(lane.over(_table).table.seats, 5);
      lane = lane.readEnded();
      expect(lane.over(_seats(7)).table.seats, 7);
    });

    test(
      'the socket dropped: no update of it can come any more, so it goes',
      () {
        final lane = fiveTaken().socketDropped();
        expect(lane.over(_seats(7)).table.seats, 7);
      },
    );

    test('an update heard before the answer counts: it goes at the answer', () {
      var lane = _asked(SettingsLane.empty, [
        _settings({'seats': 5}),
      ]);
      (lane, _) = lane.sendNext();
      lane = _take(lane.heard(_seats(5)));
      expect(lane.over(_seats(7)).table.seats, 7);
    });

    test('updates are told apart by order, oldest first: 5, 6, 5 answered, '
        'the first 5 heard marks only the first', () {
      var lane = _asked(SettingsLane.empty, [
        _settings({'seats': 5}),
        _settings({'seats': 6}),
        _settings({'seats': 5}),
      ]);
      for (var i = 0; i < 3; i++) {
        lane = _sent(lane, _take);
      }
      lane = lane.heard(_seats(5));
      expect(lane.over(_seats(6)).table.seats, 5, reason: 'the third is laid');
      lane = lane.heard(_seats(6)).heard(_seats(5));
      expect(lane.over(_seats(8)).table.seats, 8, reason: 'all heard');
    });

    test('a lost change may have got through: its update does not pass for a '
        "newer change's", () {
      var lane = _asked(SettingsLane.empty, [
        _settings({'seats': 6}),
        _settings({'seats': 6}),
      ]);
      lane = _sent(lane, (l) => l.lose());
      lane = _sent(lane, _take);
      // The lost one's update (6) arrives first: only it is marked.
      lane = lane.heard(_seats(6));
      expect(lane.over(_table).table.seats, 6, reason: 'the second is laid');
      lane = lane.heard(_seats(6));
      expect(lane.over(_seats(7)).table.seats, 7);
    });

    test('values are compared whole: a deck heard with its roles, practice '
        'by what was asked', () {
      const roles = {'Werewolf': 2, 'Seer': 1, 'Villager': 3};
      const deck = SettingsChange({'deck': 'custom', 'roles': roles}, 1);
      expect(
        deck.heardIn(_server(const {'deck': 'custom', 'roles': roles})),
        isTrue,
      );
      expect(
        deck.heardIn(_server(const {'deck': 'custom', 'roles': _roles})),
        isFalse,
      );
      final three = FromSample.lobby(
        ContractSamples.map('http/lobby/practice_three'),
      );
      expect(
        const PracticeChange(PracticeAsk(count: 3), 1).heardIn(three),
        isTrue,
      );
      expect(
        const PracticeChange(PracticeAsk(count: 2), 1).heardIn(three),
        isFalse,
      );
      expect(
        const PracticeChange(PracticeAsk(on: false), 1).heardIn(three),
        isFalse,
      );
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
      expect(lane.serverShown().refusedShown, isFalse);
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
      expect(() => lane.taken(_table), throwsA(isA<AssertionError>()));
      expect(lane.refused, throwsA(isA<AssertionError>()));
      expect(lane.settle, throwsA(isA<AssertionError>()));
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
