import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/logging/app_logger.dart';
import '../../../../core/wakelock/wakelock_service.dart';
import '../../../../core/websocket/websocket_channel.dart';
import '../../../../design_system/copy/copy.dart';
import '../../../../design_system/layout/space.dart';
import '../../../../design_system/primitives/band.dart';
import '../../../../design_system/primitives/fit_line.dart';
import '../../../../design_system/primitives/layered_art.dart';
import '../../../../design_system/primitives/notice.dart';
import '../../../../design_system/primitives/scene_switcher.dart';
import '../../../../design_system/primitives/screen_frame.dart';
import '../../../../design_system/skin/art_set.dart';
import '../../../../design_system/skin/ground.dart';
import '../../../../design_system/skin/ground_scope.dart';
import '../../../../design_system/skin/skin.dart';
import '../../../lobby/presentation/at_table_screen.dart';
import '../../../lobby/presentation/deck_screen.dart';
import '../../../lobby/presentation/join_screen.dart';
import '../../domain/game_me.dart' show GamePhase;
import '../../domain/screen_table.dart';
import '../game_socket.dart';
import '../live_game.dart';
import '../table_screen.dart';
import 'count_screen.dart';
import 'night_screen.dart';
import 'results_screen.dart';
import 'talk_screen.dart';
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
/// - A change of screen fades quickly ([Motion.settle]); two changes are a
///   scene the whole table shares ([Motion.scene], `SceneSwitcher`): the
///   deal to the night (dusk) and the night to the talk (dawn). With reduce
///   motion it is instant. The screen arriving takes touches from the first
///   frame; nothing waits for any of it.
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

  /// This phone was at the table (02, 03) and the game has started: until the
  /// night's own `/me/` lands, the night's first screen is the card's frame.
  var _dealt = false;

  /// The day's layers are decoded once this phone is at the night.
  var _dawnWarm = false;

  @override
  void initState() {
    super.initState();
    _wakelock = ref.read(wakelockServiceProvider);
    _keepAwake(_wakelock.enable);
    WidgetsBinding.instance.addObserver(this);
    _warm(LayeredSceneId.nightVillage);
  }

  /// The layers of a header decoded before the scene that brings it in, at
  /// the size the screen draws them, so a scene never lands on an empty
  /// header and the same decoded pictures are found. Not awaited: the app
  /// does not start slower for it. The night's (04's village) when the shell
  /// first shows, since the deal comes to every phone; the day's (08's dawn)
  /// once the phone is at the night, so a player who is not yet dealt does
  /// not fetch it.
  void _warm(LayeredSceneId id) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      final size = MediaQuery.sizeOf(context);
      final top = MediaQuery.paddingOf(context).top;
      final width = size.width.clamp(0, ScreenFrame.maxWidth).toDouble();
      LayeredArt.precache(context, id, switch (id) {
        LayeredSceneId.nightVillage => Size(
          width,
          TopArtLayout.backdrop.height + top,
        ),
        LayeredSceneId.dawnGallows => Size(
          width,
          TimerBand.skyFor(size.height) + top,
        ),
      });
    });
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
    switch (shown?.screen) {
      case AppScreen.table || AppScreen.deck:
        _dealt = true;
      case AppScreen.yourCard || AppScreen.nightBoard:
        if (!_dawnWarm) {
          _dawnWarm = true;
          _warm(LayeredSceneId.dawnGallows);
        }
      case _:
        _dealt = false;
    }
    final gameId = shown?.gameId;
    final gameAsync = gameId == null
        ? null
        : ref.watch(liveGameProvider(gameId));
    final game = gameAsync?.value;
    final (key, screen) = switch (shown) {
      null => ('nothing', const _Nothing()),
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
    return Stack(
      children: [
        Positioned.fill(
          child: SceneSwitcher<_Stage>(
            stage: (key: key, screen: shown?.screen),
            sceneBetween: _sceneBetween,
            child: screen,
          ),
        ),
        if (offline) const _OfflineBanner(),
      ],
    );
  }

  /// The screen for [shown], and the key that says when it is another one.
  (String, Widget) _screen(TableScreen shown, LiveGame? game) {
    final gameId = shown.gameId;
    // The player too: a `/debug` perspective switch is another phone, and
    // nothing of one player's screen (a reveal, picks) carries to the next.
    final key = '${shown.screen.name}|$gameId|${game?.me.playerId}';
    // A game screen is built only from a `/me/` of its own phase: when the
    // table names a later phase than the `/me/` held (it is being fetched),
    // the screen waits on its ground with nothing on it, never showing the
    // earlier phase's values (the talk's count as the vote's).
    LiveGame? at(GamePhase phase) =>
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
      // 04 while its `/me/` loads: its own frame, village and headline, so
      // the card arrives onto the screen it belongs to (a scene lands on it).
      AppScreen.yourCard || AppScreen.nightBoard
          when night == null &&
              gameId != null &&
              (shown.screen == AppScreen.yourCard || _dealt) =>
        ('$key|wait', const _CardWaits()),
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
      // 08 while its `/me/` loads: its own frame, the layered dawn and the
      // headline, so the day breaks on the screen it belongs to.
      AppScreen.talk => ('$key|wait', const _TalkWaits()),
      // 09 while its `/me/` loads (and a game screen with no game, which the
      // screen table never names): the screen's ground, nothing on it.
      AppScreen.vote => (key, const _Nothing(day: true)),
      _ => (key, const _Nothing()),
    };
  }

  static bool _boardOpen(LiveGame? game) {
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

/// Which screen the shell shows: its key (it changes with the screen, the
/// game and the player) and the screen the table names.
typedef _Stage = ({String key, AppScreen? screen});

/// The scene a change of screen is, if it is one: the deal's dusk (02 or 03
/// to the night) and the night's dawn (04 or the board to the talk). Every
/// other change, the vote to the count included, is a crossfade.
SceneKind? _sceneBetween(_Stage from, _Stage to) =>
    switch ((from.screen, to.screen)) {
      (
        AppScreen.table || AppScreen.deck,
        AppScreen.yourCard || AppScreen.nightBoard,
      ) =>
        SceneKind.dusk,
      (AppScreen.yourCard || AppScreen.nightBoard, AppScreen.talk) =>
        SceneKind.dawn,
      _ => null,
    };

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

/// 04 while its `/me/` loads: the frame the card is laid in, nothing in it
/// but the headline.
class _CardWaits extends StatelessWidget {
  const _CardWaits();

  @override
  Widget build(BuildContext context) => ScreenFrame(
    ground: GroundKind.night,
    topScene: LayeredSceneId.nightVillage,
    topArtLayout: TopArtLayout.backdrop,
    fitsHeight: true,
    body: Align(
      alignment: Alignment.centerLeft,
      child: Semantics(
        header: true,
        child: FitLine(
          CardCopy.headline,
          style: context.skin.typography.screenTitle,
        ),
      ),
    ),
  );
}

/// 08 while its `/me/` loads: the frame the talk is laid in, the sky with the
/// sun at the start of its arc and the headline, no number yet.
class _TalkWaits extends StatelessWidget {
  const _TalkWaits();

  @override
  Widget build(BuildContext context) => ScreenFrame(
    ground: GroundKind.day,
    topSlot: const TimerBand.sun(
      secondsLeft: null,
      elapsed: 0,
      title: TalkCopy.headline,
    ),
    fitsHeight: true,
    minBodyHeight: TalkView.minBody,
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
