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
import '../../../design_system/skin/skin_choice.dart'
    show devicePreferencesProvider;
import '../../lobby/domain/lobby_state.dart' show TableCards;
import '../../lobby/presentation/lobby_notifier.dart';
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

/// Reloads the page. A test counts reloads instead.
@Riverpod(keepAlive: true)
Future<void> Function() pageReload(Ref ref) => page.reloadPage;

/// Where this device keeps the build it last reloaded for (`NewBuild`).
const reloadedForPrefix = 'mv.reloaded.v1.';

/// The app learning of a newer build and renewing itself at a safe moment
/// (`NewBuild`, `mayReloadNow`). Null where there is nothing to renew: a
/// local run, a test, the installed app. Started by `App`.
@Riverpod(keepAlive: true)
NewBuild? newBuild(Ref ref) {
  final mine = ref.watch(buildIdProvider);
  if (!BuildId.isReal(mine)) return null;
  final preferences = ref.read(devicePreferencesProvider);
  final watch = NewBuild(
    mine: mine,
    fetchLive: ref.read(liveBuildFetchProvider),
    reload: ref.read(pageReloadProvider),
    reloadedFor: () async {
      final kept = await preferences.readFlags(reloadedForPrefix);
      return kept.firstOrNull?.substring(reloadedForPrefix.length);
    },
    rememberReload: (build) async {
      await preferences.clearFlags(reloadedForPrefix);
      await preferences.setFlag('$reloadedForPrefix$build');
    },
    safe: (place, moment) => mayReloadNow(
      place: place,
      moment: moment,
      busy: _tapsOnTheWay(ref),
      halfTyped: textIsBeingTyped(),
    ),
    now: ref.read(clockProvider),
  );
  ref.listen(appResumesProvider, (_, next) {
    if (next.hasValue) watch.resumed();
  });
  var out = playerRequestsOut.value;
  void requestsChanged() {
    final was = out;
    out = playerRequestsOut.value;
    if (was > 0 && out == 0) watch.settled();
  }

  playerRequestsOut.addListener(requestsChanged);
  final unlisten = StaleSmell.listen(watch.smelled);
  ref.onDispose(() {
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

/// Text typed into a field and not sent anywhere: a reload would lose it.
@visibleForTesting
bool textIsBeingTyped() {
  final focused = FocusManager.instance.primaryFocus?.context;
  final field = focused?.findAncestorStateOfType<EditableTextState>();
  return field != null && field.textEditingValue.text.isNotEmpty;
}
