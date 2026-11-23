import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design_system/copy/copy.dart';
import '../../../../design_system/layout/space.dart';
import '../../../../design_system/night/night_story.dart';
import '../../../../design_system/primitives/board_pieces.dart';
import '../../../../design_system/primitives/hold_to_reveal.dart';
import '../../../../design_system/primitives/notice.dart';
import '../../../../design_system/primitives/primary_button.dart';
import '../../../../design_system/primitives/screen_frame.dart';
import '../../../../design_system/primitives/sealed_note.dart';
import '../../../../design_system/primitives/sliced_art.dart';
import '../../../../design_system/primitives/square_sky.dart';
import '../../../../design_system/skin/dress.dart';
import '../../../../design_system/skin/ground.dart';
import '../../../../design_system/teach/learned_store.dart';
import '../../domain/game_me.dart';
import '../live_game.dart';
import '../stage_seconds.dart';
import 'talk_square.dart';

/// 08 Talk, wired to the server: [TalkView] fed from `/me/` (with this
/// phone's taps on it), the clock from the stage's deadline
/// ([StageSeconds]), "Ready to vote" sent through the game's outbox as a
/// toggle. A phone whose night told it something it has not acknowledged
/// opens the talk with My night up, once ([TalkView.openNight]): the ack
/// goes when it is shown, the first touch puts it away. Otherwise the
/// results are acknowledged the first time My night is held. The talk ends
/// on the server (everyone ready, or its deadline); this screen never
/// decides it.
class TalkScreen extends ConsumerStatefulWidget {
  const TalkScreen({super.key, required this.game, required this.gameId});

  /// The game as the shell has it (`/me/` with this phone's taps on it).
  final LiveGame game;
  final String gameId;

  @override
  ConsumerState<TalkScreen> createState() => _TalkScreenState();
}

class _TalkScreenState extends ConsumerState<TalkScreen> {
  LiveGameNotifier get _notifier =>
      ref.read(liveGameProvider(widget.gameId).notifier);

  /// My night is up as the talk opens: decided once, on the talk's first
  /// frame (results the server has not had acknowledged, and a night that
  /// told something). A restart after the ack opens nothing.
  late final bool _open =
      widget.game.me.hasUnseenResults && widget.game.me.report.tellsSomething;

  @override
  void initState() {
    super.initState();
    // Shown is seen: the ack goes once the first frame is up; nothing
    // waits on it.
    if (_open) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) unawaited(_notifier.acknowledgeNightResults());
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final me = widget.game.me;
    return StageSeconds(
      gameId: widget.gameId,
      deadline: me.deadline,
      builder: (context, seconds) => TalkView(
        me: me,
        secondsLeft: seconds,
        // A toggle; taps in a row go out in order, the latest last.
        onReady: () => unawaited(_notifier.setReady(!(me.ready ?? false))),
        onMyNightSeen: () => unawaited(_notifier.acknowledgeNightResults()),
        openNight: _open,
        notSent: widget.game.unsent.contains(OutboxLane.ready),
        onTryAgain: () => unawaited(_notifier.retry(OutboxLane.ready)),
      ),
    );
  }
}

/// 08 Talk as the square (the owner's choice, 23 November 2026): the clock
/// in the strip of night sky, the wall lantern; on the board, the deck in
/// play (a tap or a hold on a pile opens the role) and every player as a
/// name tag; "My night" sealed at the board's foot, its night shown on the
/// board, from the top, only while it is held ([MyNightPanel]); on the
/// cobbles the one amber "Ready to vote" with how many are ready under its
/// words, "Ready ✓" in navy once tapped, tapped again to take it back, never
/// locked. Who is ready is a count, never names.
///
/// It takes plain data and callbacks: [me] is `/me/` with this phone's taps
/// on it (its own [GameMe.ready]).
class TalkView extends ConsumerStatefulWidget {
  const TalkView({
    super.key,
    required this.me,
    required this.secondsLeft,
    required this.onReady,
    this.onMyNightSeen,
    this.openNight = false,
    this.notSent = false,
    this.onTryAgain,
  });

  /// The least height the body (the board and its foot) is given; a
  /// shorter phone (large text) scrolls the band and the body together.
  static const minBody = SquareMetrics.leastBody;

  final GameMe me;

  /// Null: the talk has no deadline (no number).
  final int? secondsLeft;

  /// "Ready to vote" / "Ready ✓" tapped.
  final VoidCallback onReady;

  /// My night was shown (held, or [openNight]).
  final VoidCallback? onMyNightSeen;

  /// My night is up as the talk opens, until the first touch: its first
  /// sight of a night that told this phone something, once.
  final bool openNight;

  /// The last ready tap got no answer: "Not sent." with [onTryAgain].
  final bool notSent;
  final VoidCallback? onTryAgain;

  @override
  ConsumerState<TalkView> createState() => _TalkViewState();
}

class _TalkViewState extends ConsumerState<TalkView> {
  /// The note is held (or shown to a screen reader).
  var _held = false;

  /// Up by itself as the talk opens ([TalkView.openNight]), until a touch.
  late var _opened = widget.openNight;

  /// How many times the seal has stirred to teach the hold.
  late var _stirs = !_learned && !widget.openNight ? 1 : 0;

  bool get _learned => ref.read(learnedCuesProvider).contains(Cue.myNight);

  void _shown(bool shown) {
    setState(() => _held = shown);
    if (shown) widget.onMyNightSeen?.call();
  }

  @override
  Widget build(BuildContext context) {
    final me = widget.me;
    final up = _held || _opened;
    final frame = ScreenFrame(
      ground: GroundKind.night,
      dress: Dress.paper,
      bleed: true,
      topSlot: SquareSky(
        secondsLeft: widget.secondsLeft,
        title: TalkCopy.headline,
      ),
      fitsHeight: true,
      minBodyHeight: TalkView.minBody,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: BoardFrame(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  Expanded(
                    child: up
                        ? MyNightPanel(story: NightStory.of(me.report))
                        : SquareBoard(
                            deck: me.deck,
                            seats: me.seats,
                            you: me.playerId,
                          ),
                  ),
                  const SizedBox(height: Space.sm),
                  Center(child: _note(me, pressed: up)),
                  const SizedBox(height: Space.md),
                ],
              ),
            ),
          ),
          _foot(context, me),
        ],
      ),
    );
    if (!_opened) return frame;
    // Up by itself: the first touch anywhere puts it away (and is only that).
    return Stack(
      children: [
        frame,
        Positioned.fill(
          child: Semantics(
            button: true,
            label: RoleSheetCopy.close,
            onTap: () => setState(() => _opened = false),
            child: GestureDetector(
              behavior: HitTestBehavior.opaque,
              onTapDown: (_) => setState(() => _opened = false),
            ),
          ),
        ),
      ],
    );
  }

  /// The sealed note: held, the night shows on the board.
  Widget _note(GameMe me, {required bool pressed}) {
    final mine = me.seats.where((s) => s.id == me.playerId).firstOrNull;
    return HoldToReveal(
      away: true,
      target: TalkCopy.myNight,
      face: me.report.myNight,
      onRevealChanged: _shown,
      onRevealed: () =>
          unawaited(ref.read(learnedCuesProvider.notifier).learn(Cue.myNight)),
      cover: GestureDetector(
        // A tap too short to open it: until it is learned, the seal stirs.
        onTap: () {
          if (!_learned) setState(() => _stirs++);
        },
        child: ExcludeSemantics(
          child: SealedNote(
            label: TalkCopy.myNight,
            token: mine?.token,
            pressed: pressed,
            stir: _stirs,
          ),
        ),
      ),
    );
  }

  /// On the cobbles: the one button, with the count under its words.
  Widget _foot(BuildContext context, GameMe me) {
    final progress = me.progress;
    final ready = me.ready ?? false;
    final count = progress == null
        ? null
        : CommonCopy.progress.fill({'d': progress.done, 'n': progress.needed});
    final button = ready
        ? PrimaryButton.on(
            label: CommonCopy.readyDone,
            detail: count,
            onPressed: widget.onReady,
          )
        : PrimaryButton(
            label: TalkCopy.readyToVote,
            detail: count,
            onPressed: widget.onReady,
          );
    return Stack(
      children: [
        const Positioned.fill(child: BoardFoot(height: double.infinity)),
        SafeArea(
          top: false,
          child: Padding(
            padding: const EdgeInsets.fromLTRB(
              Space.gutter,
              Space.xl,
              Space.gutter,
              Space.xl,
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              spacing: Space.sm,
              children: [
                if (widget.notSent && widget.onTryAgain != null)
                  Notice(
                    message: BannerCopy.notSent,
                    action: BannerCopy.tryAgain,
                    onAction: widget.onTryAgain,
                  ),
                ConstrainedBox(
                  constraints: const BoxConstraints(
                    maxWidth: SquareMetrics.buttonWidest,
                  ),
                  child: SizedBox(width: double.infinity, child: button),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}
