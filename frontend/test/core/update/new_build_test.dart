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

    test('at once on the first screen, a table before the deal, the count '
        'and the results', () {
      for (final place in [
        AppScreen.join,
        AppScreen.table,
        AppScreen.deck,
        AppScreen.count,
        AppScreen.results,
        'join',
        'elsewhere',
      ]) {
        expect(may(place, Moment.learned), isTrue, reason: '$place');
      }
    });

    test('in a running game only when the game moves on or the app comes '
        'back', () {
      for (final place in [
        AppScreen.yourCard,
        AppScreen.nightBoard,
        AppScreen.talk,
        AppScreen.vote,
      ]) {
        expect(may(place, Moment.learned), isFalse, reason: '$place');
        expect(may(place, Moment.screenChanged), isTrue, reason: '$place');
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

    test('in a game it waits for the next phase', () {
      fakeAsync((async) {
        final page = _Page(live: 'new', place: AppScreen.talk)..build(async);
        page.watch.start();
        page.settle(async);
        expect(page.watch.waiting, isTrue);
        expect(page.reloads, isEmpty);
        page.show(async, AppScreen.vote);
        expect(page.reloads, ['new']);
      });
    });

    test('in a game it also goes when the app comes back, whichever is '
        'first', () {
      fakeAsync((async) {
        final page = _Page(live: 'new', place: AppScreen.vote)..build(async);
        page.watch.start();
        page.settle(async);
        expect(page.reloads, isEmpty);
        page.watch.resumed();
        page.settle(async);
        expect(page.reloads, ['new']);
      });
    });

    test('a resume that learns of it is a moment', () {
      fakeAsync((async) {
        final page = _Page(place: AppScreen.nightBoard)..build(async);
        page.watch.start();
        page.settle(async);
        page.live = 'new';
        async.elapse(const Duration(seconds: 11));
        page.watch.resumed();
        page.settle(async);
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
        page.show(async, AppScreen.talk);
        expect(page.reloads, ['new']);
      });
    });
  });

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
    Future<int> smells(
      Response<dynamic> Function(RequestOptions) answer,
    ) async {
      var count = 0;
      final unlisten = StaleSmell.listen(() => count++);
      final dio = Dio()..interceptors.add(StalePageInterceptor());
      dio.httpClientAdapter = _Fake(answer);
      try {
        await dio.get<dynamic>('http://api.test/x');
      } on DioException {
        // refused answers are the callers' business
      }
      unlisten();
      return count;
    }

    Response<dynamic> reply(
      RequestOptions o,
      int status,
      String type,
      Object body,
    ) => Response(
      requestOptions: o,
      statusCode: status,
      data: body,
      headers: Headers.fromMap({
        Headers.contentTypeHeader: [type],
      }),
    );

    test('an API call answered with a page', () async {
      expect(
        await smells((o) => reply(o, 200, 'text/html', '<html></html>')),
        1,
      );
    });

    test('a 404 that is not the server\'s own JSON', () async {
      expect(await smells((o) => reply(o, 404, 'text/plain', 'NOT_FOUND')), 1);
    });

    test('the server\'s own answers and refusals smell of nothing', () async {
      expect(await smells((o) => reply(o, 200, 'application/json', '{}')), 0);
      expect(
        await smells((o) => reply(o, 404, 'application/json', '{"a":1}')),
        0,
      );
      expect(
        await smells((o) => reply(o, 400, 'application/json', '{"a":1}')),
        0,
      );
    });
  });
}

class _Fake implements HttpClientAdapter {
  _Fake(this.answer);

  final Response<dynamic> Function(RequestOptions) answer;

  @override
  Future<ResponseBody> fetch(
    RequestOptions options,
    Stream<List<int>>? requestStream,
    Future<void>? cancelFuture,
  ) async {
    final r = answer(options);
    return ResponseBody.fromString(
      r.data as String,
      r.statusCode!,
      headers: r.headers.map,
    );
  }

  @override
  void close({bool force = false}) {}
}
