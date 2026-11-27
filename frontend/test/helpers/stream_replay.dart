import 'dart:convert';

import 'package:midnight_village/core/healing/healing.dart';
import 'package:midnight_village/design_system/night/night_pick.dart';

import 'contract/contract_samples.dart';
import 'live_game_setup.dart';
import 'mock_http_client.dart';

/// Heal timing for a replay: every heal as fast as in any test, but no slow
/// table poll (it runs by the clock, so how many it makes depends on how long a
/// replay takes; its own test counts it at rest).
const replayTiming = HealTiming(
  afterDeadline: Duration(milliseconds: 10),
  poll: Duration(milliseconds: 30),
  firstRetry: Duration(milliseconds: 10),
  maxRetry: Duration(milliseconds: 40),
  tablePoll: Duration(hours: 1),
);

/// One phone replaying its seat of a recorded whole game (`ws_stream/*`,
/// `ContractSamples.stream`) through the strict mocks, as the app plays it:
/// the game opens (its table, its `/me/`, its socket coming up), then every
/// event its socket got, in order, and every tap it made, sent where the
/// recording says it left; what the tap caused is heard before its answer is
/// let through (the order of a phone whose socket is the faster), and every
/// read the phone makes is answered with the newest `/me/` the server had sent
/// this seat (and, at the results, the results it sent).
///
/// [asked] counts every request the phone made, by moment: `open`, each stage
/// change (`look -> night`, `night -> talk`, `talk -> vote`, `vote -> end`,
/// `play again`, from the view or the event that brings it) and each tap
/// (`tap ...`: its own request and whatever it led the phone to ask).
class SeatReplay {
  SeatReplay(this.seat, this.items);

  /// [seat] of the stream sample [name].
  factory SeatReplay.of(String name, String seat) =>
      SeatReplay(seat, ContractSamples.stream(name)[seat]!);

  final String seat;
  final List<Map<String, dynamic>> items;

  /// Moment -> request (`GET /me/`, `POST ready`, ...) -> how many.
  final Map<String, Map<String, int>> asked = {};

  late final LiveGameSetup setup;
  String _moment = 'open';
  int _counted = 0;

  Map<String, dynamic> get _firstMe =>
      items
              .map((i) => i['answer'])
              .whereType<Map<String, dynamic>>()
              .firstWhere((a) => a['method'] == 'GET')['body']
          as Map<String, dynamic>;

  /// Plays the whole seat; [asked] holds the counts after.
  Future<void> run() async {
    final me = _firstMe;
    final start = DateTime.parse(me['stage_started_at'] as String);
    setup = LiveGameSetup.create(me, clock: () => start, timing: replayTiming);
    final code = me['lobby_code'] as String;
    final gameId = me['game_id'] as String;
    String real(String path) =>
        path.replaceAll('{game_id}', gameId).replaceAll('{code}', code);

    // The game opens: the table screen (its seat), the game, the socket up.
    setup.screen;
    await setup.load();
    setup.back();
    await _settle();

    var opened = false;
    Future<void>? tap;
    HeldReplies? held;
    for (final item in items) {
      if (item['event'] case final Map<String, dynamic> event) {
        if (!opened) continue; // heard before the game's own first read
        _count();
        _momentOf(event);
        if (event['type'] == 'me') {
          setup.answerMe(event['me'] as Map<String, dynamic>);
          if (event['results'] case final Map<String, dynamic> results) {
            setup.http.answer(
              'GET',
              real('/onuw/games/{game_id}/results/'),
              results,
            );
          }
        }
        setup.ws.addServerEvent(jsonEncode(event));
        await _settle();
      } else if (item['request'] case final Map<String, dynamic> request) {
        if (request['method'] == 'GET') continue; // the game's own first read
        _count();
        _moment = 'tap ${_tapName(request)}';
        final path = real(request['path'] as String);
        final answer = _answerOf(item);
        setup.http.answer(
          request['method'] as String,
          path,
          answer['body'],
          status: answer['status'] as int,
        );
        held = setup.http.hold(method: request['method'] as String, path: path);
        tap = _tap(request);
        await _settle();
      } else if (item['answer'] case final Map<String, dynamic> answer) {
        if (answer['method'] == 'GET') {
          opened = true;
          continue;
        }
        final path = real(answer['path'] as String);
        held?.releaseAll();
        setup.http.stopHolding(method: answer['method'] as String, path: path);
        await tap;
        await _settle();
      }
    }
    await _settle();
    _count();
    setup.dispose();
  }

  /// Every request made since the last count goes to the moment it was in.
  void _count() {
    final requests = setup.http.requests;
    for (final r in requests.skip(_counted)) {
      final name = '${r.method} ${_short(r.path)}';
      final at = asked.putIfAbsent(_moment, () => {});
      at[name] = (at[name] ?? 0) + 1;
    }
    _counted = requests.length;
  }

  static String _short(String path) {
    final parts = path.split('/').where((p) => p.isNotEmpty).toList();
    if (path == '/me/table/') return '/me/table/';
    return parts.last;
  }

  void _momentOf(Map<String, dynamic> event) {
    final moment = switch (event['type']) {
      'me' => switch ((event['me'] as Map)['phase']) {
        'night' => 'look -> night',
        'discussion' => 'night -> talk',
        'voting' => 'talk -> vote',
        _ => 'vote -> end',
      },
      'night_window' => 'look -> night',
      'phase_change' =>
        event['phase'] == 'discussion' ? 'night -> talk' : 'talk -> vote',
      'vote_reveal' || 'game_results' => 'vote -> end',
      'play_again' => 'play again',
      _ => null,
    };
    if (moment != null) _moment = moment;
  }

  static String _tapName(Map<String, dynamic> request) {
    final path = request['path'] as String;
    final sent = (request['sent'] as Map?)?.cast<String, dynamic>() ?? {};
    final stage = (sent['stage'] as String?)?.split('.').first;
    if (path.endsWith('/ready/')) return 'ready ($stage)';
    if (path.endsWith('/action/')) return 'choose';
    if (path.endsWith('/seen/')) return 'My night';
    if (path.endsWith('/vote/')) return sent['lock'] == true ? 'lock' : 'pick';
    if (path.endsWith('/play-again/')) return 'play again';
    return path;
  }

  Map<String, dynamic> _answerOf(Map<String, dynamic> request) {
    final at = items.indexOf(request);
    return items
        .skip(at + 1)
        .map((i) => i['answer'])
        .whereType<Map<String, dynamic>>()
        .first;
  }

  Future<void> _tap(Map<String, dynamic> request) async {
    final notifier = setup.notifier;
    final path = request['path'] as String;
    final sent = (request['sent'] as Map? ?? {}).cast<String, dynamic>();
    if (path.endsWith('/ready/')) {
      await notifier.setReady(sent['ready'] as bool);
    } else if (path.endsWith('/action/')) {
      final picks = [
        for (final pick in (sent['picks'] as List).cast<Map<String, dynamic>>())
          if (pick['player_id'] case final int id)
            PlayerPick(id)
          else
            CenterPick(pick['center_index'] as int),
      ];
      await notifier.choose(sent['stage'] as String, picks);
    } else if (path.endsWith('/seen/')) {
      await notifier.acknowledgeNightResults();
    } else if (path.endsWith('/vote/')) {
      final target = sent['target_player_id'] as int;
      await (sent['lock'] == true
          ? notifier.lockVote(target)
          : notifier.pickVote(target));
    } else if (path.endsWith('/play-again/')) {
      await notifier.playAgain();
    }
  }

  Future<void> _settle() async {
    for (var i = 0; i < 4; i++) {
      await setup.settle();
    }
  }
}
