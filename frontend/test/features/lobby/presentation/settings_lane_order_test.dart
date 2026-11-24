import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/core/api/api_exception.dart';
import 'package:midnight_village/core/api/authenticated_client.dart';
import 'package:midnight_village/core/requests/player_request.dart';
import 'package:midnight_village/features/auth/presentation/auth_notifier.dart';
import 'package:midnight_village/features/lobby/data/lobby_service.dart';
import 'package:midnight_village/features/lobby/domain/lobby_state.dart';
import 'package:midnight_village/features/lobby/presentation/lobby_notifier.dart';
import 'package:mocktail/mocktail.dart';

import '../../../helpers/contract/contract_samples.dart';
import '../../../helpers/contract/from_sample.dart';
import '../../../helpers/contract/server_json.dart';
import '../../../helpers/game_events.dart';
import '../../../helpers/mock_http_client.dart';
import '../../../helpers/mock_websocket.dart';

// The lobby's settings lane (`lobby_notifier.dart`: `_change`, `_send`,
// `_resendUnsent`, `retry`, `deal`; the lane's rules in `SettingsLane`) against
// a stand-in server. The rules are the model's:
// `docs/dev/models/phone/lobby/README.md` (`PhoneLobby.tla`).
//
// What is pinned here (and not elsewhere; `practice_players_test` pins + + −
// one at a time with every tap sent, the refusals, the loss and the stale
// "Try again"; `lobby_notifier_test` the tap shown at once and the answer
// adopted):
// - settings and practice share ONE lane: every tap sent, one out at a time,
//   in tap order, two taps on one key both sent;
// - a `lobby_update` while a tap is out never takes the tap back;
// - after a refusal or a loss the next change waits for the lobby read; the
//   refused value stays shown until that read lands, the lost one while Try
//   again would still send it (the screen shows what will go);
// - "Try again" goes at the back of the queue, trimmed to the keys nothing
//   newer asked for;
// - a deal goes behind the lane: a lost change is sent again first;
// - the host role moving mid-queue, and the table left with changes queued.
// And the model's gaps a, b (b2) and c, each on the trace that showed it,
// now closed (each test names its rule and its run, `rule_*.cfg`), and the
// review's findings 1 to 6 (its last group). The tests that need lobby bodies
// with `rev` are skipped until `contract_samples/` has them.
//
// The stand-in server holds every request until the test answers it, so the
// order of everything is the test's: payloads from `contract_samples/`.

class _MockLobbyService extends Mock implements LobbyService {}

const _code = 'ABC123';

/// One request the phone sent and the server has not answered yet.
class _Request {
  _Request(this.what, this.body);

  /// `PATCH`, `PRACTICE` or `DEAL`.
  final String what;
  final Map<String, Object?> body;
  final answer = Completer<Object?>();

  bool get open => !answer.isCompleted;

  @override
  String toString() => '$what $body';
}

/// One lobby read: the lobby as the server served it when the phone asked.
class _Read {
  _Read(this.served);
  final LobbyState served;
  final answer = Completer<LobbyState>();
}

/// The stand-in server and the host's phone at table [_code].
class _Lane {
  _Lane._(this.container, this.service, this.ws);

  final ProviderContainer container;
  final _MockLobbyService service;
  final MockWebSocketChannel ws;
  late final ProviderSubscription<AsyncValue<LobbyState>> _sub;

  /// The table's settings as the server has them.
  final settings = <String, Object?>{
    'roles': const {'Werewolf': 2, 'Seer': 1, 'Robber': 1, 'Villager': 2},
    'seats': 4,
    'card_look_seconds': 240,
  };

  /// Who hosts, as the server says.
  var hostId = 1;

  /// The table's number (`rev`): it rises with every change the server
  /// tells anyone, as `apps/core` numbers it.
  var rev = 0;

  /// When the table was opened (a new table at the same code: another).
  String? createdAt;

  /// Someone else changes the table (a presence change, a join, another
  /// writer): [change] on the server's lobby, and its number rises.
  void someoneElse([void Function()? change]) {
    change?.call();
    rev++;
  }

  /// Every request the phone sent, in the order sent.
  final sent = <_Request>[];

  /// Lobby reads: answered at once unless [holdReads].
  var holdReads = false;
  final reads = <_Read>[];

  static Future<_Lane> open() async {
    final service = _MockLobbyService();
    final ws = MockWebSocketChannel();
    final container = ProviderContainer(
      overrides: [
        lobbyServiceProvider.overrideWithValue(service),
        lobbyWebSocketFactoryProvider.overrideWithValue((_) => ws),
        authenticatedClientProvider.overrideWithValue(
          AuthenticatedClient.forTesting(dio: MockHttpClient().dio),
        ),
      ],
    );
    addTearDown(container.dispose);
    final lane = _Lane._(container, service, ws);
    when(() => service.fetchLobby(_code)).thenAnswer((_) {
      if (!lane.holdReads) return Future.value(lane.lobby());
      final read = _Read(lane.lobby());
      lane.reads.add(read);
      return read.answer.future;
    });
    when(() => service.patchSettings(any(), _code, any())).thenAnswer(
      (call) => lane._hold(
        'PATCH',
        (call.positionalArguments[2] as Map).cast<String, Object?>(),
      ),
    );
    when(
      () => service.setPractice(
        any(),
        _code,
        on: any(named: 'on'),
        count: any(named: 'count'),
      ),
    ).thenAnswer(
      (call) => lane._hold('PRACTICE', {
        if (call.namedArguments[#on] case final bool on) 'on': on,
        if (call.namedArguments[#count] case final int count) 'count': count,
      }),
    );
    when(
      () => service.startGame(any(), _code),
    ).thenAnswer((_) => lane._hold('DEAL', const {}));
    lane._sub = container.listen(lobbyProvider(_code), (_, _) {});
    await container.read(lobbyProvider(_code).future);
    return lane;
  }

  Future<T> _hold<T>(String what, Map<String, Object?> body) {
    final request = _Request(what, body);
    sent.add(request);
    return request.answer.future.then((v) => v as T);
  }

  /// The server's lobby body now.
  Map<String, dynamic> json() =>
      withValues(serverLobby(code: _code, hostId: hostId), {
        'settings': Map<String, Object?>.of(settings),
        'rev': rev,
        'created_at': ?createdAt,
      });

  LobbyState lobby() => FromSample.lobby(json());

  /// What the host's phone shows.
  LobbyState get shown => container.read(lobbyProvider(_code)).value!;
  LobbyNotifier get notifier => container.read(lobbyProvider(_code).notifier);

  /// The requests sent and not answered yet.
  List<_Request> get out => [
    for (final r in sent)
      if (r.open) r,
  ];

  /// The one request out (the lane sends one at a time).
  _Request get theOneOut {
    expect(out, hasLength(1), reason: 'one request out at a time');
    return out.single;
  }

  /// What was sent, in order.
  List<String> get log => [for (final r in sent) '$r'];

  /// The server takes the one request out and answers with its lobby.
  Future<void> take() async {
    final r = theOneOut;
    switch (r.what) {
      case 'PATCH':
        settings.addAll(r.body);
        rev++;
        r.answer.complete(lobby());
      case 'PRACTICE':
        rev++;
        r.answer.complete(lobby());
      case 'DEAL':
        r.answer.complete(
          ContractSamples.map('http/game/started')['game_id'] as String,
        );
    }
    await _drain();
  }

  /// The server refuses the one request out (a recorded refusal).
  Future<void> refuse() async {
    final r = theOneOut;
    final body = r.what == 'DEAL'
        ? ContractSamples.map('http/game/start_not_waiting')
        : ContractSamples.map('http/lobby/settings_invalid');
    r.answer.completeError(ValidationException(parseServerErrors(body)));
    await _drain();
  }

  /// The one request out gets no answer (offline, a timeout).
  Future<void> lose() async {
    theOneOut.answer.completeError(const NetworkException('offline'));
    await _drain();
  }

  /// The host role moved: the server answers 403.
  Future<void> forbid() async {
    theOneOut.answer.completeError(const ForbiddenException());
    await _drain();
  }

  /// The oldest read still out lands, with what it was served.
  Future<void> landRead() async {
    final read = reads.firstWhere((r) => !r.answer.isCompleted);
    read.answer.complete(read.served);
    await _drain();
  }

  /// The oldest read still out fails (offline).
  Future<void> failRead() async {
    final read = reads.firstWhere((r) => !r.answer.isCompleted);
    read.answer.completeError(const NetworkException('offline'));
    await _drain();
  }

  int get readsOut => reads.where((r) => !r.answer.isCompleted).length;

  /// The server's `lobby_update` (the whole lobby body): of the lobby now,
  /// or [body], one sent earlier.
  Future<void> lobbyUpdate([Map<String, dynamic>? body]) async {
    ws.addServerEvent(
      withValues(ContractSamples.map('ws/lobby/lobby_update'), {
        'data': body ?? json(),
      }),
    );
    await _drain();
  }

  /// The server's `host_changed` (a handover) to [to], numbered [at].
  Future<void> hostChanged(int to, {required int at}) async {
    ws.addServerEvent(
      withValues(ContractSamples.map('ws/lobby/host_changed_transferred'), {
        'host_id': to,
        'rev': at,
      }),
    );
    await _drain();
  }

  /// The table is left: the lobby's notifier goes away.
  Future<void> leave() async {
    _sub.close();
    await _drain();
  }
}

/// Lets every answer already given run through the phone (event-loop turns,
/// never a stretch of time).
Future<void> _drain() async {
  for (var i = 0; i < 20; i++) {
    await Future<void>.delayed(Duration.zero);
  }
}

String _patch(Map<String, Object?> body) => 'PATCH $body';

String _practice(Map<String, Object?> body) => 'PRACTICE $body';

void main() {
  setUpAll(() {
    registerFallbackValue(Door.forTest());
    registerFallbackValue(<String, Object?>{});
  });

  group('one lane, tap order, one at a time, every tap sent', () {
    test('settings and practice taps mixed go out one at a time in the '
        'order tapped, two taps on one key both sent', () async {
      final t = await _Lane.open();
      unawaited(t.notifier.setSeats(5));
      unawaited(t.notifier.togglePractice());
      unawaited(t.notifier.setLength('card_look_seconds', 300));
      unawaited(t.notifier.setSeats(6));
      unawaited(t.notifier.setPracticeCount(1));
      await _drain();

      // Shown at once, all of them over the server's lobby.
      expect(t.shown.table.seats, 6);
      expect(t.shown.table.raw['card_look_seconds'], 300);
      expect(t.shown.practiceCount, 1);
      expect(t.shown.settling, isTrue);

      for (var answered = 0; answered < 5; answered++) {
        t.theOneOut; // exactly one out
        await t.take();
        if (answered < 4) {
          expect(t.shown.table.seats, 6, reason: 'after ${answered + 1}');
        }
      }
      expect(t.log, [
        _patch({'seats': 5}),
        _practice({'on': true}),
        _patch({'card_look_seconds': 300}),
        _patch({'seats': 6}),
        _practice({'count': 1}),
      ]);
      expect(t.shown.settling, isFalse);
      expect(t.settings['seats'], 6);
    });

    test('a lobby_update while a tap is out keeps the tap shown and the '
        'lobby settling; the rest of the update is taken', () async {
      final t = await _Lane.open();
      unawaited(t.notifier.setSeats(5));
      await _drain();
      // Meanwhile the server's lobby moves on another key.
      t.someoneElse(() => t.settings['card_look_seconds'] = 360);
      await t.lobbyUpdate();

      expect(t.shown.table.seats, 5, reason: 'the tap is not taken back');
      expect(t.shown.table.raw['card_look_seconds'], 360);
      expect(t.shown.settling, isTrue);

      await t.take();
      expect(t.shown.table.seats, 5);
      expect(t.shown.table.raw['card_look_seconds'], 360);
      expect(t.shown.settling, isFalse);
    });
  });

  group('after a refusal or a loss', () {
    for (final lost in [false, true]) {
      final how = lost ? 'a loss' : 'a refusal';
      test(
        '$how: the next change waits for the lobby read; the '
        '${lost ? 'lost' : 'refused'} value stays shown until it lands',
        () async {
          final t = await _Lane.open();
          t.holdReads = true;
          unawaited(t.notifier.setSeats(5));
          unawaited(t.notifier.setLength('card_look_seconds', 300));
          await _drain();
          expect(t.log, [
            _patch({'seats': 5}),
          ]);

          lost ? await t.lose() : await t.refuse();
          expect(t.readsOut, 1, reason: 'the lobby is read again');
          expect(t.out, isEmpty, reason: 'the next change waits for the read');
          expect(t.shown.table.seats, 5, reason: 'until the read lands');
          expect(t.shown.notSent, lost, reason: '"Not sent." only for a loss');

          await t.landRead();
          // A lost 5 is what Try again or Deal would send: it stays shown,
          // with "Not sent." (E); a refused one goes with the read.
          expect(t.shown.table.seats, lost ? 5 : 4);
          expect(
            t.shown.table.raw['card_look_seconds'],
            300,
            reason: 'pending',
          );
          expect(t.log, [
            _patch({'seats': 5}),
            _patch({'card_look_seconds': 300}),
          ]);
          await t.take();
          expect(t.settings['seats'], 4, reason: 'never sent again by itself');
          expect(t.shown.notSent, lost);
        },
      );
    }

    test('the host role moved (403) mid-queue: the change and every one '
        'waiting are dropped with no "Not sent." (each would meet its own '
        '403)', () async {
      final t = await _Lane.open();
      unawaited(t.notifier.setSeats(5));
      unawaited(t.notifier.setLength('card_look_seconds', 300));
      await _drain();
      t.someoneElse(() => t.hostId = 2);
      await t.forbid();
      expect(t.shown.hostId, 2);
      expect(t.shown.notSent, isFalse);
      expect(t.log, [
        _patch({'seats': 5}),
      ]);
      expect(t.out, isEmpty);
      expect(t.shown.table.seats, 4);
      expect(t.shown.table.raw['card_look_seconds'], 240);
      expect(t.shown.settling, isFalse);
      expect(t.shown.notSent, isFalse);
    });

    test('the table left with changes queued: nothing more is sent', () async {
      final t = await _Lane.open();
      unawaited(t.notifier.setSeats(5));
      unawaited(t.notifier.setLength('card_look_seconds', 300));
      await _drain();
      await t.leave();
      await t.take();
      expect(t.log, [
        _patch({'seats': 5}),
      ]);
    });
  });

  group('"Try again"', () {
    test('goes at the back of the queue, after what is still queued, '
        'trimmed to the keys nothing newer asked for', () async {
      final t = await _Lane.open();
      final roles = {'Werewolf': 2, 'Seer': 1, 'Villager': 3};
      // A custom deck for 6 (deck, roles and seats in one tap), then 7 seats.
      unawaited(t.notifier.startCustomDeck(roles, seats: 6));
      unawaited(t.notifier.setSeats(7));
      await _drain();
      await t.lose();
      expect(t.shown.notSent, isTrue);
      // The read landed; the seats went out after it.
      expect(t.theOneOut.body, {'seats': 7});

      unawaited(t.notifier.retry());
      await _drain();
      expect(t.shown.notSent, isFalse);
      expect(t.theOneOut.body, {'seats': 7}, reason: 'Try again waits');
      await t.take();
      await t.take();
      expect(t.log, [
        _patch({'deck': 'custom', 'roles': roles, 'seats': 6}),
        _patch({'seats': 7}),
        _patch({'deck': 'custom', 'roles': roles}),
      ], reason: 'the newer seats are never undone');
      expect(t.settings['seats'], 7);
      expect(t.shown.table.seats, 7);
    });

    test('a deal after a lost change sends the change again first, then the '
        'deal; once both are answered (taken or refused) Try again sends '
        'nothing', () async {
      for (final refused in [false, true]) {
        final t = await _Lane.open();
        unawaited(t.notifier.setSeats(5));
        await _drain();
        await t.lose();
        expect(t.shown.notSent, isTrue);

        final dealt = t.notifier.deal();
        await _drain();
        expect(t.theOneOut.body, {'seats': 5}, reason: 'the change first');
        expect(t.shown.notSent, isFalse);
        await t.take();
        expect(t.theOneOut.what, 'DEAL');
        refused ? await t.refuse() : await t.take();
        await dealt;
        // A refused deal says why; nothing is "Not sent." either way.
        expect(t.shown.notSent, isFalse, reason: 'refused: $refused');
        if (refused) expect(t.shown.dealRefused, isNotNull);

        final before = t.sent.length;
        await t.notifier.retry();
        await _drain();
        expect(t.sent.length, before, reason: 'refused: $refused');
        expect(t.settings['seats'], 5);
      }
    });
  });

  group('the model\'s gaps a, b, b2 and c, closed '
      '(docs/dev/models/phone/lobby/README.md)', () {
    test('(a) NoFlickerBack, rule_a.cfg: a read that crosses an answer never '
        'shows the old value', () async {
      final t = await _Lane.open();
      t.holdReads = true;
      unawaited(t.notifier.setSeats(5));
      await _drain();
      // Someone sits down: a read, served before the server applies 5.
      t.ws.addServerEvent(GameEvents.playerJoined());
      await _drain();
      expect(t.readsOut, 1);
      await t.take();
      expect(t.shown.table.seats, 5, reason: 'the answer');

      await t.landRead();
      // The read was asked before the answer: the answer stays over it.
      expect(t.shown.table.seats, 5);
      expect(t.shown.settling, isFalse, reason: 'answered: Deal is live');

      await t.lobbyUpdate();
      expect(t.shown.table.seats, 5);
    });

    test('(a) NoFlickerBack, rule_a.cfg: the socket alone: the first tap\'s '
        'lobby_update after the second tap\'s answer never shows the first '
        'count', () async {
      final t = await _Lane.open();
      unawaited(t.notifier.setSeats(5));
      unawaited(t.notifier.setSeats(6));
      await _drain();
      await t.take();
      final first = t.json();
      await t.take();
      expect(t.shown.table.seats, 6);
      t.ws.addServerEvent(
        withValues(ContractSamples.map('ws/lobby/lobby_update'), {
          'data': first,
        }),
      );
      await _drain();
      expect(t.shown.table.seats, 6, reason: 'the 5 is older than the answer');
      // The second tap's own update: nothing older can come; the server's
      // lobby shows as it is from here on.
      await t.lobbyUpdate();
      expect(t.shown.table.seats, 6);
      t.someoneElse(() => t.settings['seats'] = 7);
      await t.lobbyUpdate();
      expect(t.shown.table.seats, 7);
    });

    test('(b) LostFlagged, rule_b.cfg: a new tap on another key leaves "Not '
        'sent." while the lost change still waits for Try again', () async {
      final t = await _Lane.open();
      t.holdReads = true;
      unawaited(t.notifier.setSeats(5));
      await _drain();
      await t.lose();
      expect(t.shown.notSent, isTrue);
      expect(t.shown.table.seats, 5);

      unawaited(t.notifier.togglePractice());
      await _drain();
      expect(t.shown.notSent, isTrue);
      expect(t.shown.table.seats, 5);

      await t.landRead();
      expect(t.shown.table.seats, 5, reason: 'what Try again would send (E)');
      expect(t.shown.notSent, isTrue, reason: 'still said, with Try again');
    });

    test('(b2) NoHiddenResend, rule_b2.cfg: Try again sends a lost change '
        'only while "Not sent." showed for it', () async {
      final t = await _Lane.open();
      unawaited(t.notifier.setSeats(5));
      await _drain();
      await t.lose();
      unawaited(t.notifier.togglePractice());
      await _drain();
      expect(t.shown.notSent, isTrue, reason: 'never hidden by the new tap');
      await t.lose(); // practice is lost too
      expect(t.shown.notSent, isTrue);

      unawaited(t.notifier.retry());
      await _drain();
      await t.take();
      await t.take();
      // Both were said all along: both go again, oldest first.
      expect(t.log.skip(2), [
        _patch({'seats': 5}),
        _practice({'on': true}),
      ]);
      expect(t.settings['seats'], 5);
      expect(t.shown.notSent, isFalse);
    });

    test(
      '(c) RetryCoversAll, DealAsShown, rule_c.cfg: a lost change, then a '
      'deal that did not go: Try again redoes both, the change first',
      () async {
        final t = await _Lane.open();
        unawaited(t.notifier.setSeats(5));
        await _drain();
        await t.lose();
        expect(t.shown.settling, isFalse, reason: 'Deal is live');

        final dealt = t.notifier.deal();
        await _drain();
        expect(t.shown.table.seats, 5, reason: 'shown at once, as dealt');
        await t.lose(); // the change, sent again first, is lost again
        expect(await dealt, isNull, reason: 'the deal never went past it');
        expect(t.shown.notSent, isTrue);

        final again = t.notifier.retry();
        await _drain();
        await t.take();
        await t.take();
        await again;
        expect(t.log, [
          _patch({'seats': 5}),
          _patch({'seats': 5}),
          _patch({'seats': 5}),
          'DEAL {}',
        ]);
        expect(t.settings['seats'], 5, reason: 'dealt as shown');
      },
    );

    test('(c) DealAsShown: a refused value still on screen keeps the deal '
        'back ("Not sent."); Try again after the read deals', () async {
      final t = await _Lane.open();
      t.holdReads = true;
      unawaited(t.notifier.setSeats(5));
      await _drain();
      await t.refuse();
      expect(t.shown.table.seats, 5, reason: 'until the read lands');

      expect(await t.notifier.deal(), isNull);
      expect(t.out, isEmpty, reason: 'no deal past the refused 5');
      expect(t.shown.notSent, isTrue);

      await t.landRead();
      expect(t.shown.table.seats, 4);
      final again = t.notifier.retry();
      await _drain();
      expect(t.theOneOut.what, 'DEAL');
      await t.take();
      await again;
      expect(t.settings['seats'], 4);
    });
  });

  group('the review of lobby-lane-gaps: each finding on its trace, fixed', () {
    test('(1) Try again while the deal still waits joins that deal: it goes, '
        'once', () async {
      final t = await _Lane.open();
      unawaited(t.notifier.setSeats(5));
      await _drain();
      await t.lose();
      t.holdReads = true;
      final dealt = t.notifier.deal();
      await _drain();
      await t.lose(); // the 5, sent again first, is lost again
      expect(t.shown.notSent, isTrue);
      expect(t.readsOut, 1, reason: 'the deal still waits behind the read');

      final again = t.notifier.retry();
      await t.landRead();
      expect(t.theOneOut.body, {'seats': 5});
      await t.take();
      expect(t.theOneOut.what, 'DEAL');
      await t.take();
      await again;
      expect(await dealt, isNotNull, reason: 'the one deal went');
      expect(t.log.where((r) => r.startsWith('DEAL')), hasLength(1));
      expect(t.settings['seats'], 5);
    });

    test('(1) a setting tapped while the deal waits keeps it back at once '
        'and says so: never a silent end', () async {
      final t = await _Lane.open();
      unawaited(t.notifier.setSeats(5));
      await _drain();
      await t.lose();
      final dealt = t.notifier.deal();
      await _drain();
      expect(t.theOneOut.body, {'seats': 5});
      unawaited(t.notifier.setLength('card_look_seconds', 300));
      await _drain();
      expect(t.shown.notSent, isTrue, reason: 'at once');
      await t.take();
      expect(await dealt, isNull);
      await t.take();
      expect(t.log.where((r) => r.startsWith('DEAL')), isEmpty);
      expect(t.shown.notSent, isTrue, reason: 'still said');

      final again = t.notifier.retry();
      await _drain();
      expect(t.theOneOut.what, 'DEAL', reason: 'Try again deals what shows');
      await t.take();
      await again;
      expect(t.settings['card_look_seconds'], 300);
    });

    test('(1) two deals at once are one deal: one DEAL request', () async {
      final t = await _Lane.open();
      final first = t.notifier.deal();
      final second = t.notifier.deal();
      await _drain();
      expect(t.theOneOut.what, 'DEAL');
      await t.take();
      expect(await first, await second);
      expect(t.log, ['DEAL {}']);
    });

    test('(1) a setting tapped while the deal is out goes after its '
        'answer, never beside it', () async {
      final t = await _Lane.open();
      final dealt = t.notifier.deal();
      await _drain();
      unawaited(t.notifier.setSeats(5));
      await _drain();
      expect(t.theOneOut.what, 'DEAL', reason: 'the change waits');
      await t.lose();
      expect(await dealt, isNull);
      expect(t.theOneOut.body, {'seats': 5});
    });

    test('(2) Try again with a refused value on screen after a failed read '
        'reads the lobby; then it deals what the read shows', () async {
      final t = await _Lane.open();
      t.holdReads = true;
      unawaited(t.notifier.setSeats(5));
      await _drain();
      await t.refuse();
      await t.failRead();
      expect(t.shown.table.seats, 5, reason: 'the refused value, no read yet');
      expect(await t.notifier.deal(), isNull);
      expect(t.shown.notSent, isTrue);

      final read = t.notifier.retry();
      await _drain();
      expect(t.readsOut, 1, reason: 'Try again does something: a read');
      await t.landRead();
      await read;
      expect(t.shown.table.seats, 4);
      expect(t.shown.notSent, isTrue, reason: 'the deal is still back');
      expect(t.out, isEmpty, reason: 'nothing dealt the host did not see');

      final again = t.notifier.retry();
      await _drain();
      expect(t.theOneOut.what, 'DEAL');
      await t.take();
      await again;
      expect(t.settings['seats'], 4);
    });

    test('(3) nothing is held over the screen: after an answer, and after a '
        'loss and Try again, a read shows what someone else wrote', () async {
      final t = await _Lane.open();
      unawaited(t.notifier.setSeats(5));
      await _drain();
      await t.take();
      // Someone else writes the key (no lobby_update of it heard here).
      t.someoneElse(() => t.settings['seats'] = 7);
      t.ws.addServerEvent(GameEvents.playerJoined());
      await _drain();
      expect(t.shown.table.seats, 7);

      unawaited(t.notifier.setSeats(6));
      await _drain();
      await t.lose();
      unawaited(t.notifier.retry());
      await _drain();
      await t.take();
      t.someoneElse(() => t.settings['seats'] = 8);
      t.ws.addServerEvent(GameEvents.playerJoined());
      await _drain();
      expect(t.shown.table.seats, 8, reason: 'the resend holds nothing');
    });

    test('(4) a stale lobby_update from someone else is never taken for the '
        "host's own: seats 4, taps 5 then 4; 4 stays", () async {
      final t = await _Lane.open();
      // A presence change, sent before 5 is applied.
      t.someoneElse();
      final presence = t.json();
      unawaited(t.notifier.setSeats(5));
      unawaited(t.notifier.setSeats(4));
      await _drain();
      await t.take();
      final fives = t.json();
      await t.lobbyUpdate(presence);
      expect(t.shown.table.seats, 4, reason: 'the tap of 4 is on its way');
      await t.take();
      expect(t.shown.table.seats, 4);
      // 5's own update, late: older than the answer shown.
      await t.lobbyUpdate(fives);
      expect(t.shown.table.seats, 4);
      await t.lobbyUpdate(presence);
      expect(t.shown.table.seats, 4);
    });

    test('(5) after a 403 the phone is a guest\'s: no "Not sent.", nothing '
        'kept to send again or to deal', () async {
      final t = await _Lane.open();
      unawaited(t.notifier.setSeats(5));
      await _drain();
      await t.lose();
      expect(t.shown.notSent, isTrue);
      final dealt = t.notifier.deal();
      await _drain();
      t.someoneElse(() => t.hostId = 2);
      await t.forbid();
      expect(await dealt, isNull);
      expect(t.shown.hostId, 2);
      expect(t.shown.notSent, isFalse);
      expect(t.out, isEmpty);
      final before = t.sent.length;
      await t.notifier.retry();
      await _drain();
      expect(t.sent.length, before, reason: 'Try again has nothing to send');
    });

    test('(6) what is dealt is what the screen showed at the tap: a lost '
        'value stays shown (with "Not sent.") and is dealt', () async {
      final t = await _Lane.open();
      unawaited(t.notifier.setSeats(5));
      await _drain();
      await t.lose();
      expect(t.settings['seats'], 4, reason: 'the server never had it');
      expect(t.shown.table.seats, 5, reason: 'the read put nothing back');
      expect(t.shown.notSent, isTrue);
      final atTap = t.shown.table.seats;

      final dealt = t.notifier.deal();
      await _drain();
      await t.take();
      await t.take();
      expect(await dealt, isNotNull);
      expect(t.settings['seats'], atTap);
    });

    test('a lobby_update held while a read is out is shown after it, over '
        'the read (nothing listens to the socket alone any more)', () async {
      final t = await _Lane.open();
      t.holdReads = true;
      t.ws.addServerEvent(GameEvents.playerJoined());
      await _drain();
      t.someoneElse(() => t.settings['seats'] = 7);
      await t.lobbyUpdate();
      expect(t.shown.table.seats, 4, reason: 'held until the read lands');
      await t.landRead();
      expect(t.shown.table.seats, 7);
    });

    test('rev: an equal number is shown, never skipped (presence and a '
        'read crossing a write differ under one number)', () async {
      final t = await _Lane.open();
      t.settings['card_look_seconds'] = 360; // under the same number
      await t.lobbyUpdate();
      expect(t.shown.table.raw['card_look_seconds'], 360);
    });

    test('rev: a body with no number (a server from before it) is shown, '
        'and leaves the newest number as it was', () async {
      final t = await _Lane.open();
      t.someoneElse(() => t.settings['seats'] = 6);
      t.someoneElse();
      await t.lobbyUpdate();
      final older = withValues(t.json(), {'rev': 1});
      t.settings['seats'] = 7;
      // Off the contract of today on purpose: a server from before `rev`.
      t.ws.addOffContractEvent(
        withValues(ContractSamples.map('ws/lobby/lobby_update'), {
          'data': Map.of(t.json())..remove('rev'),
        }),
      );
      await _drain();
      expect(t.shown.table.seats, 7, reason: 'no number: shown');
      await t.lobbyUpdate(older);
      expect(t.shown.table.seats, 7, reason: 'the newest is still 2');
    });

    test('rev: a host_changed lower than the newest shown never puts an '
        'older host back; a newer one is shown at its number', () async {
      final t = await _Lane.open();
      t.someoneElse(() => t.hostId = 2); // the first handover, numbered 1
      t.someoneElse(() => t.hostId = 1); // and back, numbered 2
      t.ws.addServerEvent(GameEvents.playerJoined());
      await _drain();
      expect(t.shown.hostId, 1, reason: 'the read');
      await t.hostChanged(2, at: 1); // the first handover's event, late
      expect(t.shown.hostId, 1);
      await t.hostChanged(2, at: 3);
      expect(t.shown.hostId, 2);
      // A lobby older than the host change is not shown after it.
      t.settings['seats'] = 9;
      await t.lobbyUpdate(withValues(t.json(), {'rev': 2}));
      expect(t.shown.table.seats, 4);
    });

    test('rev: a new table at the same code starts again: its first, lower '
        'number is shown', () async {
      final t = await _Lane.open();
      for (var i = 0; i < 5; i++) {
        t.someoneElse();
      }
      await t.lobbyUpdate();
      t
        ..createdAt = '2026-11-24T21:00:00Z'
        ..rev = 1
        ..settings['seats'] = 6;
      await t.lobbyUpdate();
      expect(t.shown.table.seats, 6);
    });

    test('rev: the same change sent twice is answered twice, each one '
        'higher: both shown, nothing stuck', () async {
      final t = await _Lane.open();
      unawaited(t.notifier.setSeats(5));
      unawaited(t.notifier.setSeats(5));
      await _drain();
      await t.take();
      await t.take();
      expect(t.rev, 2);
      expect(t.shown.table.seats, 5);
      expect(t.shown.settling, isFalse);
      expect(t.shown.notSent, isFalse);
    });
  });
}
