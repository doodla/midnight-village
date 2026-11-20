import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/logging/app_logger.dart';
import '../../../../core/wakelock/wakelock_service.dart';
import '../../../../core/websocket/websocket_channel.dart';
import '../../../../design_system/copy/copy.dart';
import '../../../../design_system/layout/space.dart';
import '../../../../design_system/primitives/notice.dart';
import '../../../../design_system/primitives/screen_frame.dart';
import '../../../../design_system/skin/ground.dart';
import '../../../../design_system/skin/ground_scope.dart';
import '../../../../design_system/skin/skin.dart';
import '../../../lobby/presentation/at_table_screen.dart';
import '../../../lobby/presentation/deck_screen.dart';
import '../../../lobby/presentation/join_screen.dart';
import '../../domain/game_me.dart' show GamePhase;
import '../../domain/screen_table.dart';
import '../../data/game_service.dart' show UnplayableGameException;
import '../game_socket.dart';
import '../protocol_two_game.dart';
import '../table_screen.dart';
import 'count_screen.dart';
import 'night_screen.dart';
import 'results_screen.dart';
import 'talk_screen.dart';
import 'unplayable_screen.dart';
import 'vote_screen.dart';
import 'your_card_screen.dart';

/// The app's one place for a table: it shows exactly the screen
/// [tableScreenProvider] names ([screenFor] on `/me/table/`, the
/// table's game's `/me/` and the local steps) and nothing else decides
/// which. No socket event, timer or tap navigates: they change what the
/// server is fetched to say, and the screen follows.
///
/// - 01 Join, 02 Table, 03 Deck (`features/lobby`), 04 Your card, the
///   night board (06, 05 while `/me/` loads), 08 Talk, 09 Vote, 10 The count
///   and 11 Results (their calm wait while the results load). 08 and 09
///   show their day ground, nothing on it, while their `/me/` loads.
/// - PROTOCOL 1: a game whose `/me/` has no `stage` (a night this app does
///   not play)
///   is [UnplayableScreen]: a calm line and "Leave", never a retry loop.
/// - A change of screen fades quickly ([Motion.settle]); with reduce motion
///   it is instant. Nothing waits for it.
/// - While nothing is known yet (the first `/me/table/`), the night ground
///   and nothing on it; "One moment" when that fetch fails (it is retried
///   until it succeeds), and while the game's socket is down and its
///   fetches fail too.
/// - The screen is kept awake while the shell is shown.
class TableShell extends ConsumerStatefulWidget {
  const TableShell({super.key});

  @override
  ConsumerState<TableShell> createState() => _TableShellState();
}

class _TableShellState extends ConsumerState<TableShell>
    with WidgetsBindingObserver {
  late final WakelockService _wakelock;

  @override
  void initState() {
    super.initState();
    _wakelock = ref.read(wakelockServiceProvider);
    _keepAwake(_wakelock.enable);
    WidgetsBinding.instance.addObserver(this);
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _keepAwake(_wakelock.disable);
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The platform drops the lock in the background. (The game fetches
    // again on resume by itself: `appResumesProvider`.)
    if (state == AppLifecycleState.resumed) _keepAwake(_wakelock.enable);
  }

  void _keepAwake(Future<void> Function() call) => unawaited(
    call().catchError((Object e) => logger.d('Wakelock call failed: $e')),
  );

  @override
  Widget build(BuildContext context) {
    final at = ref.watch(tableScreenProvider);
    final shown = at.value;
    final gameId = shown?.gameId;
    final gameAsync = gameId == null
        ? null
        : ref.watch(protocolTwoGameProvider(gameId));
    final game = gameAsync?.value;
    final unplayable = gameAsync?.error is UnplayableGameException;
    final (key, screen) = switch (shown) {
      null => ('nothing', const _Nothing()),
      _ when unplayable && _inGame(shown.screen) => (
        'unplayable|$gameId',
        const UnplayableScreen(),
      ),
      _ => _screen(shown, game),
    };
    // Offline: nothing fetched yet and the fetch fails, or the socket is
    // down and the fetches fail too (a socket refused while fetches work
    // changes nothing on the screen).
    final offline =
        (shown == null && at.hasError) ||
        (gameId != null &&
            _socketDown(ref, gameId) &&
            (game?.fetchFailing ?? false));
    final still = MediaQuery.disableAnimationsOf(context);
    return Stack(
      children: [
        Positioned.fill(
          child: AnimatedSwitcher(
            duration: still ? Duration.zero : Motion.settle,
            switchInCurve: Motion.curve,
            switchOutCurve: Motion.curve,
            child: KeyedSubtree(key: ValueKey(key), child: screen),
          ),
        ),
        if (offline) const _OfflineBanner(),
      ],
    );
  }

  /// The screen for [shown], and the key that says when it is another one.
  (String, Widget) _screen(TableScreen shown, ProtocolTwoGame? game) {
    final gameId = shown.gameId;
    // The player too: a `/debug` perspective switch is another phone, and
    // nothing of one player's screen (a reveal, picks) carries to the next.
    final key = '${shown.screen.name}|$gameId|${game?.me.playerId}';
    // A game screen is built only from a `/me/` of its own phase: when the
    // table names a later phase than the `/me/` held (it is being fetched),
    // the screen waits on its ground with nothing on it, never showing the
    // earlier phase's values (the talk's count as the vote's).
    ProtocolTwoGame? at(GamePhase phase) =>
        game != null && game.me.phase == phase ? game : null;
    final night = at(GamePhase.night);
    final talk = at(GamePhase.discussion);
    final vote = at(GamePhase.voting);
    final end = at(GamePhase.results);
    return switch (shown.screen) {
      // 01 to 03 (features/lobby) read the table and the lobby themselves.
      AppScreen.join => (key, const JoinScreen()),
      AppScreen.table => (key, const AtTableScreen()),
      AppScreen.deck => (key, const DeckScreen()),
      AppScreen.yourCard when night != null && night.me.window == 0 => (
        key,
        YourCardScreen(game: night, gameId: gameId!),
      ),
      AppScreen.yourCard || AppScreen.nightBoard when gameId != null => (
        // 05 and the board fade into each other too.
        '$key|${_boardOpen(night) ? 'board' : 'wait'}',
        NightScreen(gameId: gameId, game: night),
      ),
      AppScreen.talk when talk != null => (
        key,
        TalkScreen(game: talk, gameId: gameId!),
      ),
      AppScreen.vote when vote != null => (
        key,
        VoteScreen(game: vote, gameId: gameId!),
      ),
      AppScreen.count when gameId != null => (
        key,
        CountScreen(gameId: gameId, game: end),
      ),
      AppScreen.results when gameId != null => (
        key,
        ResultsScreen(gameId: gameId, game: end),
      ),
      // 08 and 09 while their own `/me/` loads (and a game screen with no
      // game, which the screen table never names): the screen's ground,
      // nothing on it.
      AppScreen.talk || AppScreen.vote => (key, const _Nothing(day: true)),
      _ => (key, const _Nothing()),
    };
  }

  /// A screen of the game (not 01 to 03, which never read it).
  static bool _inGame(AppScreen screen) => switch (screen) {
    AppScreen.join || AppScreen.table || AppScreen.deck => false,
    _ => true,
  };

  static bool _boardOpen(ProtocolTwoGame? game) {
    final me = game?.me;
    return me != null && me.inWindow && me.prompt != null;
  }

  static bool _socketDown(WidgetRef ref, String gameId) =>
      switch (ref.watch(gameConnectionStateProvider(gameId)).value) {
        WebSocketConnectionState.disconnected ||
        WebSocketConnectionState.reconnecting => true,
        _ => false,
      };
}

/// Before the first answer: the night's (or the day's) ground, nothing on
/// it.
class _Nothing extends StatelessWidget {
  const _Nothing({this.day = false});

  final bool day;

  @override
  Widget build(BuildContext context) => ScreenFrame(
    ground: day ? GroundKind.day : GroundKind.night,
    body: const SizedBox.shrink(),
  );
}

/// "One moment", over the top of whatever is shown: this phone is offline.
/// Nothing else changes; the screen heals by itself when it is back.
class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  @override
  Widget build(BuildContext context) => Positioned(
    top: MediaQuery.paddingOf(context).top + Space.sm,
    left: Space.gutter,
    right: Space.gutter,
    child: GroundScope(
      ground: GroundKind.night,
      child: Builder(
        builder: (context) => DecoratedBox(
          decoration: BoxDecoration(
            color: context.ground.ground,
            borderRadius: BorderRadius.circular(context.skin.shape.radius),
          ),
          child: const Notice(message: BannerCopy.offline),
        ),
      ),
    ),
  );
}
