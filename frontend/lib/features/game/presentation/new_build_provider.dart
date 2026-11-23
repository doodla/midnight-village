import 'package:flutter/widgets.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/healing/healing.dart';
import '../../../core/requests/player_request.dart';
import '../../../core/update/build_id.dart';
import '../../../core/update/new_build.dart';
import '../../../core/update/page_stub.dart'
    if (dart.library.js_interop) '../../../core/update/page_web.dart'
    as page;
import '../../../core/update/stale_smell.dart';
import '../../../core/storage/tab_storage_provider.dart';
import '../../lobby/domain/lobby_state.dart' show TableCards;
import '../../lobby/presentation/join_flow.dart' show joinDraftProvider;
import '../../lobby/presentation/lobby_notifier.dart';
import '../../lobby/presentation/scan/scan_session.dart';
import '../../lobby/presentation/where_am_i_provider.dart';
import '../domain/reload_rule.dart';
import 'live_game.dart';

part 'new_build_provider.g.dart';

/// This build's commit (`BuildId.mine`). A test says which build the app is.
@Riverpod(keepAlive: true)
String buildId(Ref ref) => BuildId.mine;

/// The commit the live site was built from, or null when it cannot be read.
@Riverpod(keepAlive: true)
Future<String?> Function() liveBuildFetch(Ref ref) => page.fetchLiveBuild;

/// Brings the page's service worker up to date before a reload; false when it
/// could not. A test says how it goes.
@Riverpod(keepAlive: true)
Future<bool> Function() workerRenewal(Ref ref) => page.renewServiceWorker;

/// Reloads the page. A test counts reloads instead.
@Riverpod(keepAlive: true)
Future<void> Function() pageReload(Ref ref) => page.reloadPage;

/// The clock `NewBuild` measures how long the tab was away by (the healing
/// clock; a test moves its own).
@Riverpod(keepAlive: true)
DateTime Function() newBuildClock(Ref ref) => ref.watch(clockProvider);

/// Where this TAB keeps the build it last reloaded for (`NewBuild`, the loop
/// guard): per tab (`TabStorage`), so another tab, still running the old
/// build, reloads for it on its own.
const reloadedForKey = 'mv.reloadedFor.v1';

/// The app learning of a newer build and renewing itself at a safe moment
/// (`NewBuild`, `mayReloadNow`). Null where there is nothing to renew: a
/// local run, a test, the installed app. Started by `App`.
@Riverpod(keepAlive: true)
NewBuild? newBuild(Ref ref) {
  final mine = ref.watch(buildIdProvider);
  if (!BuildId.isReal(mine)) return null;
  final storage = ref.read(tabStorageProvider);
  final watch = NewBuild(
    mine: mine,
    fetchLive: ref.read(liveBuildFetchProvider),
    renewWorker: ref.read(workerRenewalProvider),
    reload: ref.read(pageReloadProvider),
    reloadedFor: () async => storage.read(reloadedForKey),
    rememberReload: (build) async => storage.write(reloadedForKey, build),
    safe: (place, moment) => mayReloadNow(
      place: place,
      moment: moment,
      busy: _tapsOnTheWay(ref),
      halfTyped: _halfDone(ref),
    ),
    now: ref.read(newBuildClockProvider),
  );
  // The tab hidden and coming back (the web reports it as the app's
  // lifecycle): a running game renews itself only at a come-back after a
  // while away.
  final lifecycle = AppLifecycleListener(
    onStateChange: (state) {
      switch (state) {
        case AppLifecycleState.hidden:
        case AppLifecycleState.paused:
        case AppLifecycleState.detached:
          watch.hidden();
        case AppLifecycleState.resumed:
          watch.resumed();
        case AppLifecycleState.inactive:
          break;
      }
    },
  );
  var out = playerRequestsOut.value;
  void requestsChanged() {
    final was = out;
    out = playerRequestsOut.value;
    if (was > 0 && out == 0) watch.settled();
  }

  playerRequestsOut.addListener(requestsChanged);
  final unlisten = StaleSmell.listen(watch.smelled);
  ref.onDispose(() {
    lifecycle.dispose();
    playerRequestsOut.removeListener(requestsChanged);
    unlisten();
    watch.dispose();
  });
  watch.start();
  return watch;
}

/// Something this phone has asked for that is not settled: a request out, a
/// game tap not sent or not answered, a host's change at the table still on
/// its way. Reads only what is held: nothing is created to ask.
bool _tapsOnTheWay(Ref ref) {
  if (playerRequestsOut.value > 0) return true;
  final table = ref.exists(myTableProvider)
      ? ref.read(myTableProvider).value
      : null;
  if (table == null) return false;
  final gameId = table.gameId;
  if (gameId != null && ref.exists(liveGameProvider(gameId))) {
    final game = ref.read(liveGameProvider(gameId)).value;
    if (game != null && game.outbox.hasTapsOnTheWay) return true;
  }
  final code = table.lobbyCode;
  if (ref.exists(lobbyProvider(code))) {
    if (ref.read(lobbyProvider(code)).value?.settling ?? false) return true;
  }
  return false;
}

/// Something typed or open on the first screen that a reload could cost:
/// a name or a code typed (`JoinDraft`: every field's edit lands there, kept
/// across a reload as well), text in the focused field, or the camera
/// scanner open (a reload would close it). A name that is only the account's
/// own, shown in its field, is not typed.
bool _halfDone(Ref ref) =>
    ref.read(joinDraftProvider).isTyped ||
    ref.read(scanSessionProvider).open ||
    textIsBeingTyped();

/// Text in the focused field and not sent anywhere: a reload would lose it.
@visibleForTesting
bool textIsBeingTyped() {
  final focused = FocusManager.instance.primaryFocus?.context;
  final field = focused?.findAncestorStateOfType<EditableTextState>();
  return field != null && field.textEditingValue.text.isNotEmpty;
}
