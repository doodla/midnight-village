import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design_system/copy/copy.dart';
import '../../../../design_system/layout/space.dart';
import '../../../../design_system/faces/held_face.dart';
import '../../../../design_system/primitives/candle_gauge.dart';
import '../../../../design_system/primitives/face_down_card.dart';
import '../../../../design_system/primitives/fit_line.dart';
import '../../../../design_system/primitives/notice.dart';
import '../../../../design_system/primitives/primary_button.dart';
import '../../../../design_system/primitives/paper_banner.dart';
import '../../../../design_system/primitives/progress_pips.dart';
import '../../../../design_system/primitives/screen_frame.dart';
import '../../../../design_system/primitives/world_timer.dart';
import '../../../../design_system/skin/art_set.dart';
import '../../../../design_system/skin/dress.dart';
import '../../../../design_system/skin/skin_choice.dart';
import '../../../../design_system/skin/ground.dart';
import '../../../../design_system/skin/skin.dart';
import '../../../../design_system/teach/teach_once.dart';
import '../../../../design_system/teach/teaching_hold.dart';
import '../../domain/game_me.dart';
import '../live_game.dart';
import '../stage_seconds.dart';

/// 04 Your card (first-time play spec, section 3, the look stage): the dealt
/// card face down, as large as the screen allows; holding it shows the role
/// text ([GameMe.report]'s card) for as long as it is held; "Ready" is
/// locked until a 0.8 s reveal on this phone in this stage (a tap on it
/// replays the hold cue), then sends `ready` through the game's outbox and
/// shows "Ready ✓" from the tap on. Under it, how many have looked, as plain
/// pips: counts only, never who. The time left (the table's
/// `card_look_seconds`, by the server's deadline) is on the title's banner
/// in every state, the night's candle and number; a `/me/` with no deadline
/// draws no clock (the server has none: a table set to 0 has no look stage).
///
/// While held, the card turns over where it is (a friendly game: no popup,
/// no moving it out from under the thumb).
///
/// A phone that restarts in the look stage reads its own `ready` from `/me/`:
/// ready, it opens at "Ready ✓". Not yet, but it had seen its card: this
/// device remembers the stage it was seen in ([lookedPrefix], one key, the
/// latest stage, by player), so "Ready" is open again without another
/// hold. The stage
/// ends on the server (everyone ready, or its backstop); this screen never
/// decides it.
class YourCardScreen extends ConsumerStatefulWidget {
  const YourCardScreen({
    super.key,
    required this.game,
    required this.gameId,
    this.dress,
  });

  /// How the screen is dressed (`ScreenFrame.dress`; null: as the screen
  /// above it).
  final Dress? dress;

  /// Where this device keeps the look stage its card was seen in
  /// (`DevicePreferences`, beside the learned cues).
  static const lookedPrefix = 'mv.looked.v1.';

  /// The game as the shell has it (`/me/` with this phone's taps on it).
  final LiveGame game;
  final String gameId;

  @override
  ConsumerState<YourCardScreen> createState() => _YourCardScreenState();
}

class _YourCardScreenState extends ConsumerState<YourCardScreen> {
  final _replay = CueReplay();

  /// The stage in which this phone held its card for a reveal that counts.
  String? _revealedIn;

  var _candleWarmed = false;

  @override
  void initState() {
    super.initState();
    unawaited(_recall());
  }

  /// The flag for [me]'s stage, by player (the `/debug` toolbar plays
  /// several on one device) and stage; never the role.
  static String _flag(GameMe me) =>
      '${YourCardScreen.lookedPrefix}${me.playerId}.${me.stage}';

  /// A reveal this device made in this stage before a restart.
  Future<void> _recall() async {
    final me = widget.game.me;
    if (me.stage == null) return;
    final seen = await ref
        .read(devicePreferencesProvider)
        .readFlags(YourCardScreen.lookedPrefix);
    if (mounted && seen.contains(_flag(me))) {
      setState(() => _revealedIn ??= me.stage);
    }
  }

  Future<void> _remember(GameMe me) async {
    if (me.stage == null) return;
    final preferences = ref.read(devicePreferencesProvider);
    await preferences.clearFlags(YourCardScreen.lookedPrefix);
    await preferences.setFlag(_flag(me));
  }

  @override
  void dispose() {
    _replay.dispose();
    super.dispose();
  }

  LiveGameNotifier get _notifier =>
      ref.read(liveGameProvider(widget.gameId).notifier);

  @override
  Widget build(BuildContext context) => DressScope(
    dress: widget.dress ?? Dress.paper,
    child: Builder(builder: _screen),
  );

  Widget _screen(BuildContext context) {
    final skin = context.skin;
    final me = widget.game.me;
    final progress = me.progress;
    final unsent = widget.game.unsent.contains(OutboxLane.ready);
    return ScreenFrame(
      ground: GroundKind.night,
      topScene: LayeredSceneId.nightVillage,
      topArtLayout: TopArtLayout.backdrop,
      fitsHeight: true,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Left, clear of the moon in the picture.
          Align(
            alignment: Alignment.centerLeft,
            // Dressed up, on a torn banner, pinned: the moon stays clear on
            // the right. The look stage's clock, when the table set one, is
            // on the same banner after the title, where the night board's
            // stands: quiet, the card stays the hero.
            child: PaperBanner(
              id: #card,
              padding: _bannerPadding(context, me),
              child: (context) => Row(
                mainAxisSize: MainAxisSize.min,
                spacing: Space.md,
                children: [
                  Flexible(
                    child: Semantics(
                      header: true,
                      child: FitLine(
                        CardCopy.headline,
                        style: skin.typography.screenTitle.copyWith(
                          color: context.ground.text,
                        ),
                      ),
                    ),
                  ),
                  if (me.deadline != null) _clock(context, me),
                ],
              ),
            ),
          ),
          const SizedBox(height: Space.lg),
          Expanded(
            child: LayoutBuilder(
              // The card takes the whole room between the title and the foot
              // (the face's portrait is as large as that allows).
              builder: (context, room) => Center(
                child: _card(
                  me,
                  math.min(room.maxWidth, HeldFace.maxWidth),
                  room.maxHeight,
                ),
              ),
            ),
          ),
        ],
      ),
      actionGap: Space.lg,
      actions: [
        if (unsent)
          Notice(
            message: BannerCopy.notSent,
            action: BannerCopy.tryAgain,
            onAction: () => unawaited(_notifier.retry(OutboxLane.ready)),
          ),
        _button(me),
        if (progress != null)
          ProgressPips(
            done: progress.done,
            total: progress.needed,
            label: CommonCopy.progress.fill({
              'd': progress.done,
              'n': progress.needed,
            }),
            centred: true,
          ),
      ],
    );
  }

  /// The banner's own padding, less what the clock's line stands above the
  /// title's: the banner is no taller with the clock than without it, so
  /// the card keeps its room (on a small phone its words stay at the
  /// reading floor).
  EdgeInsets _bannerPadding(BuildContext context, GameMe me) {
    final title = context.skin.typography.screenTitle;
    final line = MediaQuery.textScalerOf(
      context,
    ).scale(title.fontSize! * (title.height ?? 1));
    final over = me.deadline == null
        ? 0.0
        : math.max(0.0, WorldTimer.quietLine - line) / 2;
    return EdgeInsets.fromLTRB(
      Space.lg,
      math.max(0.0, Space.md - over),
      Space.lg,
      math.max(0.0, Space.md - over),
    );
  }

  /// The time left in the look stage, by the server's deadline: the night's
  /// candle and number ([WorldTimer.candleCompact], as on the board), at the
  /// quiet line, the candle as high on the banner as the board's is.
  Widget _clock(BuildContext context, GameMe me) {
    final candle = WorldTimer.quietLine * context.skin.parts.bannerCandle;
    if (!_candleWarmed) {
      // The candle's cuts decoded now, for its first frame (as the board's).
      _candleWarmed = true;
      CandleGauge.precache(context, candle);
    }
    return StageSeconds(
      gameId: widget.gameId,
      deadline: me.deadline,
      builder: (context, seconds) => WorldTimer.candleCompact(
        secondsLeft: seconds,
        share: StageShare.left(
          startedAt: me.stageStartedAt,
          deadline: me.deadline,
          secondsLeft: seconds,
        ),
        lineHeight: WorldTimer.quietLine,
        candleHeight: candle,
      ),
    );
  }

  Widget _card(GameMe me, double width, double height) => TeachingHold(
    target: CardCopy.headline,
    face: me.report.card,
    replay: _replay,
    inPlace: true,
    onRevealed: () {
      if (_revealedIn != me.stage) unawaited(_remember(me));
      if (mounted) setState(() => _revealedIn = me.stage);
    },
    cover: (teaching) => FaceDownCard(
      size: FaceDownSize.hero,
      cardWidth: width,
      cardHeight: height,
      hold: teaching,
    ),
  );

  Widget _button(GameMe me) {
    if (me.ready ?? false) {
      return const PrimaryButton.done(
        label: CommonCopy.readyDone,
        size: ButtonSize.large,
      );
    }
    if (_revealedIn != me.stage) {
      return PrimaryButton.locked(
        label: CardCopy.readyLocked,
        onLockedTap: _replay.replay,
        size: ButtonSize.large,
      );
    }
    return PrimaryButton(
      label: CardCopy.ready,
      onPressed: () => unawaited(_notifier.setReady(true)),
      size: ButtonSize.large,
    );
  }
}
