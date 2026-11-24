import 'package:fake_async/fake_async.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/core/healing/healing.dart';
import 'package:midnight_village/core/storage/tab_storage.dart';
import 'package:midnight_village/core/storage/tab_storage_provider.dart';
import 'package:midnight_village/features/game/domain/screen_table.dart';
import 'package:midnight_village/features/game/presentation/new_build_provider.dart';
import 'package:midnight_village/features/lobby/presentation/join_flow.dart';
import 'package:midnight_village/features/lobby/presentation/scan/scan_session.dart';

/// What the app will not reload away on the first screen, and what survives
/// the reload when it does, with the app's own providers: the clock is the
/// test's (`fakeAsync`), the fetch, the worker and the reload are fakes, the
/// tab's storage is memory that outlives the container (the page's reload
/// keeps the tab).
class _Tab {
  _Tab({TabStorage? storage}) : storage = storage ?? MemoryTabStorage();

  final TabStorage storage;
  final reloads = <String>[];
  var live = 'new';

  ProviderContainer open(FakeAsync async) {
    final container = ProviderContainer(
      overrides: [
        buildIdProvider.overrideWithValue('old'),
        liveBuildFetchProvider.overrideWithValue(() async => live),
        workerRenewalProvider.overrideWithValue(() async => true),
        pageReloadProvider.overrideWithValue(() async => reloads.add(live)),
        tabStorageProvider.overrideWithValue(storage),
        clockProvider.overrideWithValue(
          () => async.getClock(DateTime(2026, 11, 23)).now(),
        ),
      ],
    );
    addTearDown(container.dispose);
    return container;
  }

  void settle(FakeAsync async) {
    async.flushMicrotasks();
    async.elapse(Duration.zero);
    async.flushMicrotasks();
  }
}

void main() {
  group('the first screen', () {
    test('nothing typed: the reload goes at once', () {
      fakeAsync((async) {
        final tab = _Tab();
        final container = tab.open(async);
        container.read(newBuildProvider)!.seen(AppScreen.join);
        tab.settle(async);
        expect(tab.reloads, ['new']);
      });
    });

    test('the account\'s own name in its field and an open code field are '
        'not typing', () {
      fakeAsync((async) {
        final tab = _Tab();
        final container = tab.open(async);
        container
            .read(joinDraftProvider.notifier)
            .keep(const JoinDraft(codeOpen: true));
        container.read(newBuildProvider)!.seen(AppScreen.join);
        tab.settle(async);
        expect(tab.reloads, ['new']);
      });
    });

    for (final (what, draft) in [
      ('a name typed', const JoinDraft(name: 'Ana')),
      ('a code typed', const JoinDraft(code: 'K7Q', codeOpen: true)),
      ('a name and a code typed', const JoinDraft(name: 'Ana', code: 'K7QX4M')),
    ]) {
      test('$what (keyboard dismissed, no field focused): no reload until it '
          'is sent', () {
        fakeAsync((async) {
          final tab = _Tab();
          final container = tab.open(async);
          container.read(joinDraftProvider.notifier).keep(draft);
          final watch = container.read(newBuildProvider)!;
          watch.seen(AppScreen.join);
          tab.settle(async);
          expect(tab.reloads, isEmpty);
          expect(watch.waiting, isTrue);

          // Joined: the draft is cleared and the table is shown. The table
          // is no moment (nobody waits only on 01).
          container.read(joinDraftProvider.notifier).clear();
          watch.seen(AppScreen.table);
          tab.settle(async);
          expect(tab.reloads, isEmpty);
          // Back on 01 (the table left) with nothing typed: it goes at once.
          watch.seen(AppScreen.join);
          tab.settle(async);
          expect(tab.reloads, ['new']);
        });
      });
    }

    test('the camera scanner open is not closed by a reload', () {
      fakeAsync((async) {
        final tab = _Tab();
        final container = tab.open(async);
        container.read(scanSessionProvider.notifier).open();
        final watch = container.read(newBuildProvider)!;
        watch.seen(AppScreen.join);
        tab.settle(async);
        expect(tab.reloads, isEmpty);

        container.read(scanSessionProvider.notifier).close();
        watch.settled();
        tab.settle(async);
        expect(tab.reloads, ['new']);
      });
    });
  });

  group('what a reload keeps', () {
    test('01\'s name and code come back after the page reloads (the tab\'s '
        'storage), and are gone once cleared', () {
      fakeAsync((async) {
        final tab = _Tab();
        final before = tab.open(async);
        before
            .read(joinDraftProvider.notifier)
            .keep(const JoinDraft(name: 'Ana', code: 'K7Q', codeOpen: true));
        before.dispose();

        final after = tab.open(async);
        final restored = after.read(joinDraftProvider);
        expect(restored.name, 'Ana');
        expect(restored.code, 'K7Q');
        expect(restored.codeOpen, isTrue);

        after.read(joinDraftProvider.notifier).clear();
        expect(tab.open(async).read(joinDraftProvider).isTyped, isFalse);
      });
    });

    test('a draft nobody typed in is not kept; an unreadable one is empty', () {
      fakeAsync((async) {
        final tab = _Tab();
        final container = tab.open(async);
        container.read(joinDraftProvider.notifier).keep(const JoinDraft());
        expect(tab.storage.read(joinDraftKey), isNull);
        tab.storage.write(joinDraftKey, '{not json');
        expect(tab.open(async).read(joinDraftProvider).isTyped, isFalse);
      });
    });
  });

  group('the loop guard is per tab', () {
    test('tab one reloads for the new build and records it; tab two, still on '
        'the old build, reloads for it too', () {
      fakeAsync((async) {
        final one = _Tab();
        final two = _Tab();
        one.open(async).read(newBuildProvider)!.seen(AppScreen.join);
        one.settle(async);
        expect(one.reloads, ['new']);
        expect(one.storage.read(reloadedForKey), 'new');
        expect(two.storage.read(reloadedForKey), isNull);

        two.open(async).read(newBuildProvider)!.seen(AppScreen.join);
        two.settle(async);
        expect(two.reloads, ['new'], reason: 'its own tab, its own turn');
      });
    });

    test('the same tab, reloaded into a shell that is still the old build, '
        'is left alone', () {
      fakeAsync((async) {
        final tab = _Tab();
        tab.open(async).read(newBuildProvider)!.seen(AppScreen.join);
        tab.settle(async);
        expect(tab.reloads, ['new']);

        final again = tab.open(async).read(newBuildProvider)!;
        again.seen(AppScreen.join);
        tab.settle(async);
        expect(tab.reloads, ['new'], reason: 'once, never in a loop');
        expect(again.waiting, isFalse);
      });
    });
  });
}
