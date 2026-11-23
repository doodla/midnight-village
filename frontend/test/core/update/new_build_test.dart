import 'dart:async';

import 'package:dio/dio.dart';
import 'package:fake_async/fake_async.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/core/update/new_build.dart';
import 'package:midnight_village/core/update/stale_page_interceptor.dart';
import 'package:midnight_village/core/update/stale_smell.dart';
import 'package:midnight_village/features/game/domain/reload_rule.dart';
import 'package:midnight_village/features/game/domain/screen_table.dart';

/// The app learning of a newer build and renewing itself: the clock is the
/// test's (`fakeAsync`), the fetch and the reload are fakes, nothing sleeps.
class _Page {
  _Page({this.mine = 'old', this.live = 'old', this.place = AppScreen.join});

  final String mine;
  String? live;
  Object? place;
  var busy = false;
  var typing = false;
  var fetches = 0;
  var renewals = 0;

  /// Whether the service worker can be brought up to date (false: the
  /// update failed or no new worker came within its bound).
  var workerRenews = true;

  /// When set, the worker takes over when this completes.
  Completer<bool>? renewGate;
  var reloads = <String?>[];
  String? remembered;
  late final DateTime Function() now;
  late final NewBuild watch;

  void build(FakeAsync async, {String? rememberedBefore}) {
    remembered = rememberedBefore;
    now = () => async.getClock(DateTime(2026, 11, 23)).now();
    watch = NewBuild(
      mine: mine,
      fetchLive: () async {
        fetches++;
        return live;
      },
      renewWorker: () async {
        renewals++;
        return renewGate?.future ?? Future.value(workerRenews);
      },
      reload: () async => reloads.add(live),
      reloadedFor: () async => remembered,
      rememberReload: (build) async => remembered = build,
      safe: (shown, moment) => mayReloadNow(
        place: shown,
        moment: moment,
        busy: busy,
        halfTyped: typing,
      ),
      now: now,
    );
    watch.seen(place);
  }

  /// Lets everything due now run.
  void settle(FakeAsync async) {
    async.flushMicrotasks();
    async.elapse(Duration.zero);
    async.flushMicrotasks();
  }

  /// The tab goes to the background for [away] and comes back.
  void comeBack(FakeAsync async, Duration away) {
    watch.hidden();
    async.elapse(away);
    watch.resumed();
    settle(async);
  }

  void show(FakeAsync async, Object next) {
    place = next;
    watch.seen(next);
    settle(async);
  }
}

void main() {
  group('the rule (mayReloadNow)', () {
    bool may(
      Object? place,
      Moment moment, {
      bool busy = false,
      bool typed = false,
    }) => mayReloadNow(
      place: place,
      moment: moment,
      busy: busy,
      halfTyped: typed,
    );

    test('at once on the first screen, a table before the deal and the '
        'results', () {
      for (final place in [
        AppScreen.join,
        AppScreen.table,
        AppScreen.deck,
        AppScreen.results,
        'join',
        'elsewhere',
      ]) {
        for (final moment in Moment.values) {
          expect(may(place, moment), isTrue, reason: '$place $moment');
        }
      }
    });

    test('in a running game ONLY when the app comes back: never on a phase '
        'change or on the timer (the end board too: its reveal plays as the '
        'results arrive)', () {
      for (final place in [
        AppScreen.yourCard,
        AppScreen.nightBoard,
        AppScreen.talk,
        AppScreen.vote,
        AppScreen.count,
        AppScreen.end,
      ]) {
        expect(may(place, Moment.learned), isFalse, reason: '$place');
        expect(may(place, Moment.screenChanged), isFalse, reason: '$place');
        expect(may(place, Moment.resumed), isTrue, reason: '$place');
      }
    });

    test('never with a request out or an unsent tap, or text half typed, '
        'wherever the player is', () {
      for (final place in AppScreen.values) {
        for (final moment in Moment.values) {
          expect(may(place, moment, busy: true), isFalse);
          expect(may(place, moment, typed: true), isFalse);
        }
      }
    });

    test('not while the app is still finding out where it is', () {
      for (final moment in Moment.values) {
        expect(may('opening', moment), isFalse);
        expect(may(null, moment), isFalse);
      }
    });
  });

  group('learning of a newer build', () {
    test('the same build: nothing happens, at any moment', () {
      fakeAsync((async) {
        final page = _Page()..build(async);
        page.watch.start();
        page.settle(async);
        page.watch.resumed();
        page.settle(async);
        expect(page.reloads, isEmpty);
        expect(page.watch.waiting, isFalse);
      });
    });

    test('a local build never asks', () {
      fakeAsync((async) {
        final page = _Page(mine: 'local', live: 'new')..build(async);
        page.watch.start();
        page.settle(async);
        expect(page.fetches, 0);
        expect(page.reloads, isEmpty);
      });
    });

    test('a newer build on the first screen reloads at once, and the build '
        'is remembered', () {
      fakeAsync((async) {
        final page = _Page(live: 'new')..build(async);
        page.watch.start();
        page.settle(async);
        expect(page.reloads, ['new']);
        expect(page.remembered, 'new');
      });
    });

    test('in a game a phase change is no moment: the player enters the night '
        'or the vote with no reload inside a timed stage', () {
      fakeAsync((async) {
        final page = _Page(live: 'new', place: AppScreen.talk)..build(async);
        page.watch.start();
        page.settle(async);
        expect(page.watch.waiting, isTrue);
        for (final next in [
          AppScreen.vote,
          AppScreen.nightBoard,
          AppScreen.yourCard,
          AppScreen.talk,
          AppScreen.count,
        ]) {
          page.show(async, next);
        }
        expect(page.reloads, isEmpty);
        expect(page.renewals, 0, reason: 'nothing was even touched');
      });
    });

    test('in a game the slow timer never reloads either', () {
      fakeAsync((async) {
        final page = _Page(place: AppScreen.vote)..build(async);
        page.watch.start();
        page.settle(async);
        page.live = 'new';
        async.elapse(const Duration(minutes: 20));
        page.settle(async);
        expect(page.watch.waiting, isTrue, reason: 'it has learned of it');
        expect(page.reloads, isEmpty);
      });
    });

    test('in a game it goes when the tab comes back after a while away', () {
      fakeAsync((async) {
        final page = _Page(live: 'new', place: AppScreen.vote)..build(async);
        page.watch.start();
        page.settle(async);
        expect(page.reloads, isEmpty);
        page.comeBack(async, const Duration(seconds: 6));
        expect(page.reloads, ['new']);
      });
    });

    test('a glance away is not a come-back: a game is left alone', () {
      fakeAsync((async) {
        final page = _Page(live: 'new', place: AppScreen.nightBoard)
          ..build(async);
        page.watch.start();
        page.settle(async);
        page.comeBack(async, const Duration(seconds: 2));
        page.comeBack(async, const Duration(seconds: 5));
        expect(page.reloads, isEmpty);
        page.comeBack(async, const Duration(seconds: 6));
        expect(page.reloads, ['new']);
      });
    });

    test('a come-back that learns of it is a moment', () {
      fakeAsync((async) {
        final page = _Page(place: AppScreen.nightBoard)..build(async);
        page.watch.start();
        page.settle(async);
        page.live = 'new';
        page.comeBack(async, const Duration(seconds: 30));
        expect(page.reloads, ['new']);
      });
    });

    test('after the game, at the results, a reload that waited goes at '
        'once', () {
      fakeAsync((async) {
        final page = _Page(live: 'new', place: AppScreen.vote)..build(async);
        page.watch.start();
        page.settle(async);
        page.show(async, AppScreen.count);
        expect(page.reloads, isEmpty);
        page.show(async, AppScreen.results);
        expect(page.reloads, ['new']);
      });
    });

    test('and at the table after the game', () {
      fakeAsync((async) {
        final page = _Page(live: 'new', place: AppScreen.talk)..build(async);
        page.watch.start();
        page.settle(async);
        page.show(async, AppScreen.table);
        expect(page.reloads, ['new']);
      });
    });

    test('never with a request out or a tap unsent: it waits for the next '
        'moment', () {
      fakeAsync((async) {
        final page = _Page(live: 'new')
          ..busy = true
          ..build(async);
        page.watch.start();
        page.settle(async);
        page.watch.resumed();
        page.settle(async);
        expect(page.reloads, isEmpty);
        page.busy = false;
        page.watch.settled();
        page.settle(async);
        expect(page.reloads, ['new']);
      });
    });

    test('never with text half typed', () {
      fakeAsync((async) {
        final page = _Page(live: 'new')
          ..typing = true
          ..build(async);
        page.watch.start();
        page.settle(async);
        expect(page.reloads, isEmpty);
        page.typing = false;
        page.show(async, AppScreen.table);
        expect(page.reloads, ['new']);
      });
    });

    test('while the app finds out where it is, the screen that follows is '
        'the moment', () {
      fakeAsync((async) {
        final page = _Page(live: 'new', place: 'opening')..build(async);
        page.watch.start();
        page.settle(async);
        expect(page.reloads, isEmpty);
        page.show(async, AppScreen.table);
        expect(page.reloads, ['new']);
      });
    });
  });

  group(
    'the service worker is brought up to date first, nothing let go of',
    () {
      test('a worker that cannot be updated leaves the app running as it is, '
          'and the next look tries again', () {
        fakeAsync((async) {
          final page = _Page(live: 'new')
            ..workerRenews = false
            ..build(async);
          page.watch.start();
          page.settle(async);
          expect(page.renewals, 1);
          expect(page.reloads, isEmpty, reason: 'no reload');
          expect(page.remembered, isNull, reason: 'nothing recorded');
          expect(page.watch.waiting, isTrue);

          // The next look (the slow timer) finds the worker ready.
          page.workerRenews = true;
          async.elapse(const Duration(minutes: 5));
          page.settle(async);
          expect(page.renewals, 2);
          expect(page.reloads, ['new']);
          expect(page.remembered, 'new');
        });
      });

      test('the reload waits for the worker to take over', () {
        fakeAsync((async) {
          final took = Completer<bool>();
          final page = _Page(live: 'new')
            ..renewGate = took
            ..build(async);
          page.watch.start();
          page.settle(async);
          expect(page.renewals, 1);
          expect(
            page.reloads,
            isEmpty,
            reason: 'the worker has not taken over',
          );
          took.complete(true);
          page.settle(async);
          expect(page.reloads, ['new']);
        });
      });

      test('a tap that began while the worker was updating stops the reload '
          'until it settles', () {
        fakeAsync((async) {
          final took = Completer<bool>();
          final page = _Page(live: 'new')
            ..renewGate = took
            ..build(async);
          page.watch.start();
          page.settle(async);
          page.busy = true;
          took.complete(true);
          page.settle(async);
          expect(page.reloads, isEmpty);
          expect(page.remembered, isNull);
          page.busy = false;
          page.watch.settled();
          page.settle(async);
          expect(page.reloads, ['new']);
        });
      });
    },
  );

  group('no reload loop', () {
    test('a build already reloaded for is not reloaded for again (a shell '
        'that stayed old)', () {
      fakeAsync((async) {
        final page = _Page(live: 'new')..build(async, rememberedBefore: 'new');
        page.watch.start();
        page.settle(async);
        page.watch.resumed();
        page.show(async, AppScreen.table);
        expect(page.reloads, isEmpty);
        expect(page.watch.waiting, isFalse);
      });
    });

    test('a build newer still is reloaded for', () {
      fakeAsync((async) {
        final page = _Page(live: 'newer')
          ..build(async, rememberedBefore: 'new');
        page.watch.start();
        page.settle(async);
        expect(page.reloads, ['newer']);
        expect(page.remembered, 'newer');
      });
    });

    test('once reloading, it is not asked to again for the same build', () {
      fakeAsync((async) {
        final page = _Page(live: 'new')..build(async);
        page.watch.start();
        page.settle(async);
        page.show(async, AppScreen.table);
        page.watch.resumed();
        page.settle(async);
        expect(page.reloads, ['new']);
      });
    });
  });

  group('how often it looks', () {
    test('on a slow timer, one request each, and not more often than the '
        'gap for anything else', () {
      fakeAsync((async) {
        final page = _Page()..build(async);
        page.watch.start();
        page.settle(async);
        expect(page.fetches, 1, reason: 'the start');
        page.watch.resumed();
        page.watch.smelled();
        page.settle(async);
        expect(page.fetches, 1, reason: 'inside the gap');
        async.elapse(const Duration(seconds: 11));
        page.watch.resumed();
        page.settle(async);
        expect(page.fetches, 2);
        async.elapse(const Duration(minutes: 5));
        page.settle(async);
        expect(page.fetches, 3, reason: 'the slow timer');
      });
    });

    test('a stale smell makes it look', () {
      fakeAsync((async) {
        final page = _Page()..build(async);
        final unlisten = StaleSmell.listen(page.watch.smelled);
        page.watch.start();
        page.settle(async);
        async.elapse(const Duration(seconds: 11));
        page.live = 'new';
        StaleSmell.report();
        page.settle(async);
        expect(page.reloads, ['new']);
        unlisten();
      });
    });

    test('a live build that cannot be read changes nothing', () {
      fakeAsync((async) {
        final page = _Page(live: null)..build(async);
        page.watch.start();
        page.settle(async);
        expect(page.reloads, isEmpty);
      });
    });
  });

  group('what smells of a stale build', () {
    Response<dynamic> reply(int status, String type, Object body) => Response(
      requestOptions: RequestOptions(path: '/x'),
      statusCode: status,
      data: body,
      headers: Headers.fromMap({
        Headers.contentTypeHeader: [type],
      }),
    );

    /// How many smells an answer makes, as the success or the failure the
    /// client would see.
    int smells(Response<dynamic> answer) {
      var count = 0;
      final unlisten = StaleSmell.listen(() => count++);
      final interceptor = StalePageInterceptor();
      if (answer.statusCode! < 400) {
        interceptor.onResponse(answer, ResponseInterceptorHandler());
      } else {
        final handler = ErrorInterceptorHandler();
        // The failure is passed on to the caller, who is not here.
        // ignore: invalid_use_of_protected_member
        handler.future.ignore();
        interceptor.onError(
          DioException.badResponse(
            statusCode: answer.statusCode!,
            requestOptions: answer.requestOptions,
            response: answer,
          ),
          handler,
        );
      }
      unlisten();
      return count;
    }

    test('an API call answered with a page', () {
      expect(smells(reply(200, 'text/html', '<html></html>')), 1);
    });

    test("a 404 that is not the server's own JSON", () {
      expect(smells(reply(404, 'text/plain', 'NOT_FOUND')), 1);
    });

    test("the server's own answers and refusals smell of nothing", () {
      expect(smells(reply(200, 'application/json', '{}')), 0);
      expect(smells(reply(404, 'application/json', '{"a":1}')), 0);
      expect(smells(reply(400, 'application/json', '{"a":1}')), 0);
    });
  });
}
