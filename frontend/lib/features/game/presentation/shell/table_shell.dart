import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../core/logging/app_logger.dart';
import '../../../../core/wakelock/wakelock_service.dart';
import '../../../../design_system/copy/copy.dart';
import '../../../../design_system/layout/space.dart';
import '../../../../design_system/primitives/art_precache.dart';
import '../../../../design_system/primitives/notice.dart';
import '../../../../design_system/primitives/scene_switcher.dart';
import '../../../../design_system/skin/art_set.dart';
import '../../../../design_system/skin/card_back.dart';
import '../../../../design_system/skin/card_back_scope.dart';
import '../../../../design_system/skin/ground.dart';
import '../../../../design_system/skin/ground_scope.dart';
import '../../../../design_system/skin/skin.dart';
import '../../../../design_system/skin/werewolf_portrait.dart';
import '../../../lobby/presentation/at_table_screen.dart';
import '../../../lobby/presentation/deck_screen.dart';
import '../../../lobby/presentation/join_flow.dart';
import '../../../lobby/presentation/join_screen.dart';
import '../../../lobby/presentation/where_am_i_provider.dart';
import '../../domain/game_me.dart' show GamePhase;
import '../../domain/screen_table.dart';
import '../card_back_provider.dart';
import '../live_game.dart';
import '../table_screen.dart';
import 'end_screen.dart';
import 'night_screen.dart';
import 'talk_screen.dart';
import 'vote_screen.dart';
import 'waits.dart';
import 'your_card_screen.dart';

/// The app's one place for a table: it shows exactly the screen
/// [tableScreenProvider] names ([screenFor] on `/me/table/`, the
/// table's game's `/me/` and the local steps) and nothing else decides
/// which. No socket event, timer or tap navigates: they change what the
/// server is fetched to say, and the screen follows.
///
/// - 01 Join, 02 Table, 03 Deck (`features/lobby`), 04 Your card, the
///   night board (06, 05 while `/me/` loads), 08 Talk, 09 Vote and the end
///   board (its calm wait while the results load; its reveal once per result,
///   for a phone that saw the game played: [EndRevealLatch]). While a
///   game screen's `/me/` loads it shows that screen's own frame with the
///   one waiting body in it (`waits.dart`, [Waiting]): never a bare ground.
/// - A change of screen fades quickly ([Motion.settle]); two changes are a
///   scene the whole table shares ([Motion.scene], `SceneSwitcher`): the
///   deal to the night (dusk) and the night to the talk (dawn). With reduce
///   motion it is instant. The screen arriving takes touches from the first
///   frame; nothing waits for any of it.
/// - While nothing is known yet (the first `/me/table/`), the opening, as
///   it was while the saved account was read back (`OpeningWait`); "One
///   moment" with "Try again" when that fetch fails (it is retried until it
///   succeeds). Over a screen that is shown, "One moment" whenever the
///   fetches that keep it true fail (the socket down or not); the seat and
///   the screen stay.
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

  /// The game whose card back has been decoded (the fallback's is decoded at
  /// start).
  String? _backWarmFor;

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
      SceneSwitcher.precacheHeader(context, id);
    });
  }

  /// The back this game draws, decoded once, when the game is first named:
  /// only the back in use (`gameCardBackProvider`).
  void _warmBack(String gameId) {
    if (_backWarmFor == gameId) return;
    _backWarmFor = gameId;
    final wolf = ref.read(gameWerewolfPortraitProvider(gameId));
    if (wolf != WerewolfPortrait.fallback) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) return;
        unawaited(precacheWerewolf(context, wolf));
      });
    }
    final back = ref.read(gameCardBackProvider(gameId));
    if (back == CardBack.fallback) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted) return;
      unawaited(precacheCardBack(context, back));
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
    // 01's last failure ("Not sent.", a refusal) belongs to 01: once the
    // phone is anywhere else, it is gone, so it can never show up later,
    // after a Leave, as a failure of something that worked.
    ref.listen(tableScreenProvider.select((a) => a.value?.screen), (_, next) {
      if (next != null && next != AppScreen.join) {
        ref.read(joinFlowProvider.notifier).clearBanner();
      }
    });
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
    final tableFailing = ref.watch(
      myTableProvider.select((table) => table.hasError),
    );
    final gameId = shown?.gameId;
    if (gameId != null) _warmBack(gameId);
    // A phone at the game's night, talk or vote is in it when the results
    // come: its end board plays the reveal.
    if (gameId != null &&
        switch (shown?.screen) {
          AppScreen.yourCard ||
          AppScreen.nightBoard ||
          AppScreen.talk ||
          AppScreen.vote => true,
          _ => false,
        }) {
      ref.read(endRevealLatchProvider).inPlay(gameId);
    }
    final gameAsync = gameId == null
        ? null
        : ref.watch(liveGameProvider(gameId));
    final game = gameAsync?.value;
    // The wait for a game's first `/me/`: failing is told in the wait's own
    // frame, with "Try again" to read it now.
    final failing = gameAsync?.hasError ?? false;
    void readNow() {
      if (gameId != null) {
        unawaited(ref.read(liveGameProvider(gameId).notifier).refresh());
      }
    }

    final (key, screen) = switch (shown) {
      // Nothing known yet (the first `/me/table/`): the opening, as it was
      // while the saved account was read back, so the app opens in one
      // place until it knows where the player is.
      null => (
        'opening',
        OpeningWait(
          // `tableScreen` turns a read that is being retried into a plain
          // loading: the read itself says whether it is failing.
          unanswered: tableFailing,
          onRetry: () => ref.invalidate(myTableProvider),
        ),
      ),
      _ => _screen(shown, game, failing: failing, onRetry: readNow),
    };
    // Offline: a screen is shown and the fetches that keep it true fail (a
    // socket refused while fetches work changes nothing on the screen, and
    // a fetch that fails with the socket up is no less a phone the server
    // cannot reach). The waits above say it in their own frame.
    final offline =
        shown != null && ((game?.fetchFailing ?? false) || tableFailing);
    return Stack(
      children: [
        Positioned.fill(
          child: SceneSwitcher<_Stage>(
            stage: (key: key, screen: shown?.screen),
            sceneBetween: _sceneBetween,
            // Every card of the game, on every screen of it, has the game's one
            // back; the screens that are not a game's (01 to 03) the fallback.
            child: CardBackScope(
              back: gameId == null
                  ? null
                  : ref.watch(gameCardBackProvider(gameId)),
              child: WerewolfPortraitScope(
                portrait: gameId == null
                    ? null
                    : ref.watch(gameWerewolfPortraitProvider(gameId)),
                child: screen,
              ),
            ),
          ),
        ),
        if (offline) const _OfflineBanner(),
      ],
    );
  }

  /// The screen for [shown], and the key that says when it is another one.
  (String, Widget) _screen(
    TableScreen shown,
    LiveGame? game, {
    required bool failing,
    required VoidCallback onRetry,
  }) {
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
        ('$key|wait', CardWait(failing: failing, onRetry: onRetry)),
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
      // The results being read are one wait, however many answers (`/me/`,
      // then the results) come before them: one key, so the wait is not
      // crossfaded into itself (its sign would blink).
      AppScreen.end when gameId != null => (
        end?.outcome == null ? '${shown.screen.name}|$gameId|wait' : key,
        EndScreen(gameId: gameId, game: end),
      ),
      // 08 while its `/me/` loads: its own frame, the layered dawn and the
      // headline, so the day breaks on the screen it belongs to.
      AppScreen.talk => (
        '$key|wait',
        TalkWait(failing: failing, onRetry: onRetry),
      ),
      // 09 while its `/me/` loads: its own frame, the band and the headline.
      AppScreen.vote => (
        '$key|wait',
        VoteWait(failing: failing, onRetry: onRetry),
      ),
      // A game screen with no game, which the screen table never names.
      _ => (key, GameWait(failing: failing, onRetry: onRetry)),
    };
  }

  static bool _boardOpen(LiveGame? game) {
    final me = game?.me;
    return me != null && me.inWindow && me.prompt != null;
  }
}

/// Which screen the shell shows: its key (it changes with the screen, the
/// game and the player) and the screen the table names.
typedef _Stage = ({String key, AppScreen? screen});

/// The scene a change of screen is, if it is one: the deal's dusk (02 or 03
/// to the night) and the night's dawn (04 or the board to the talk). Every
/// other change, the vote to the end board included, is a crossfade.
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

/// "One moment", over the top of whatever is shown: this phone cannot reach
/// the server. The seat and the screen stay as they are, nothing else
/// changes; the screen heals by itself when it is back. It settles in from
/// 8 px above over [Motion.settle] (a cut with reduce motion).
class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner();

  static const _from = 8.0;

  @override
  Widget build(BuildContext context) => Positioned(
    top: MediaQuery.paddingOf(context).top + Space.sm,
    left: Space.gutter,
    right: Space.gutter,
    child: TweenAnimationBuilder<double>(
      tween: Tween(begin: 0, end: 1),
      duration: Motion.within(context, Motion.settle),
      curve: Motion.curve,
      builder: (context, t, child) => Opacity(
        opacity: t,
        child: Transform.translate(
          offset: Offset(0, -_from * (1 - t)),
          child: child,
        ),
      ),
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
    ),
  );
}
