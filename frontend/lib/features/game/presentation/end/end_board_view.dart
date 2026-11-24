import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../design_system/primitives/pending.dart' show RequestFailure;
import '../../../../design_system/copy/copy.dart';
import '../../../../design_system/feel/haptics.dart';
import '../../../../design_system/layout/space.dart';
import '../../../../design_system/primitives/furled_scroll.dart';
import '../../../../design_system/primitives/layered_art.dart';
import '../../../../design_system/primitives/screen_frame.dart';
import '../../../../design_system/primitives/sliced_art.dart';
import '../../../../design_system/skin/art_set.dart';
import '../../../../design_system/skin/dress.dart';
import '../../../../design_system/skin/ground.dart';
import '../../../../design_system/skin/ground_scope.dart';
import '../../../../design_system/skin/skin.dart';
import '../../domain/end_banner.dart';
import '../../domain/end_board.dart';
import '../../domain/end_board_metrics.dart';
import '../../domain/end_reveal.dart';
import '../../domain/end_story.dart';
import '../../domain/game_outcome.dart';
import '../../domain/outcome_view.dart' show endSeatsOf;
export 'end_board_window.dart' show EndBoardWindow;
export 'end_foot.dart' show EndAct;

import 'end_board_window.dart';
import 'end_foot.dart';
import 'end_night.dart';
import 'end_night_foot.dart';
import 'end_reveal.dart';

/// The end of the game, settled: a notice board in the village square at
/// dawn, lit by one lantern (docs/specs/frontend/end-board.md). The banner
/// says who was hanged and what that means for this phone's player; every
/// player's card is pinned on the board (winners larger and in the light, the
/// hanged with a black ribbon, the votes as name tags under the card they
/// chose); at the foot are the scraps and the one amber plaque. The board is
/// the plan `planEndBoard` made: this measures the words, gives the plan the
/// room there is, and draws it. When the board is taller than its window it
/// scrolls between the fixed banner (the roof its eave) and the fixed foot,
/// opening where the hanged are in view. No motion: the reveal and "What
/// happened" are other pieces.
///
/// Built from the results alone (what this phone's player may see is exactly
/// what the results body gives), who this phone's player is ([viewerId]), and
/// who is host.
///
/// With [reveal] (the results arrived while this phone was in the game) the
/// board plays its reveal once (`revealOf`, section 8 of the spec): face down
/// in place, the hanged up big and stamped with the one knock, then every card
/// turned and the board settled. A touch anywhere settles it at once (the
/// controls work from the first frame); reduce motion or a screen reader gets
/// the settled board, faded in. Without [reveal] (opened late, a second view)
/// it is the settled board and nothing moves or vibrates.
///
/// "What happened" replays the night on the board itself ([EndNight]): the
/// sky turns to night, every card turns to the face it was dealt, and each
/// step of the night plays on a tap (a swipe left; a swipe right goes back),
/// its twine tied between the cards and its words on a slip on the board's
/// rail; the scrap becomes the way back, and the settled board comes back
/// exactly as it was. Nothing vibrates and nothing advances by itself.
class EndBoardView extends StatefulWidget {
  const EndBoardView({
    super.key,
    required this.outcome,
    required this.viewerId,
    required this.isHost,
    required this.hostName,
    this.onWhatHappened,
    required this.onEditDeck,
    required this.onPlayAgain,
    required this.onLeave,
    this.busy,
    this.failure,
    this.onTryAgain,
    this.scrollController,
    this.reveal = false,
    this.stepTaught = false,
    this.onStepTaught,
  });

  final GameOutcome outcome;
  final int viewerId;
  final bool isHost;

  /// The host's name, while the host is at the table: a guest's "{host} deals
  /// next." (null: not said).
  final String? hostName;
  final VoidCallback? onWhatHappened;
  final VoidCallback onEditDeck;
  final VoidCallback onPlayAgain;
  final VoidCallback onLeave;

  /// The control whose request is on its way: it shows busy, and the others
  /// take no second request.
  final EndAct? busy;

  /// The last request did not work: its words on one line over the foot's
  /// controls, with "Try again" ([onTryAgain]) when it may be sent again.
  final RequestFailure? failure;
  final VoidCallback? onTryAgain;
  final ScrollController? scrollController;
  final bool reveal;

  /// This device has stepped through What happened before: no cue that the
  /// board goes on ([onStepTaught] is told the first time, to keep it).
  final bool stepTaught;
  final VoidCallback? onStepTaught;

  @override
  State<EndBoardView> createState() => _EndBoardViewState();
}

class _EndBoardViewState extends State<EndBoardView>
    with TickerProviderStateMixin {
  late final _clock = AnimationController(vsync: this);
  late final _driver = EndRevealDriver(_clock);
  late final _night = EndNight(vsync: this)
    ..story = endStoryOf(widget.outcome)
    ..cue = !widget.stepTaught
    ..taught = () => widget.onStepTaught?.call();

  AnimationController? _fade;

  /// The reveal is over (or never was): the board is drawn settled.
  late var _settled = !widget.reveal;

  /// How many of the reveal's knocks have come.
  var _knocked = 0;
  EndBoardPlan? _revealed;

  @override
  void initState() {
    super.initState();
    _clock
      ..addListener(_onTick)
      ..addStatusListener((status) {
        if (status == AnimationStatus.completed) _settle();
      });
  }

  @override
  void didUpdateWidget(EndBoardView old) {
    super.didUpdateWidget(old);
    // By value: the same results fetched again change nothing.
    if (old.outcome != widget.outcome) {
      _night
        ..close()
        ..story = endStoryOf(widget.outcome);
    }
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final media = MediaQuery.of(context);
    _night.cut = media.disableAnimations || media.accessibleNavigation;
    if (_settled || _clock.isAnimating) return;
    if (media.disableAnimations || media.accessibleNavigation) {
      // The settled board, faded in (no motion of anything on it), and the
      // one knock as it shows.
      _fade ??= AnimationController(vsync: this, duration: Motion.quick)
        ..forward();
      _settled = true;
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _knock();
      });
    }
  }

  @override
  void dispose() {
    _clock.dispose();
    _night.dispose();
    _fade?.dispose();
    super.dispose();
  }

  /// A knock as each stamp lands (as the banner unrolls when nobody hangs).
  void _onTick() {
    final r = _driver.reveal;
    if (r == null) return;
    while (_knocked < r.knocks.length && _driver.now >= r.knocks[_knocked]) {
      _knock();
    }
  }

  /// One of the reveal's knocks, through the `Haptics` seam: a thud for a
  /// death, a light one when nobody hangs.
  void _knock() {
    if (!widget.reveal || !mounted) return;
    _knocked++;
    final r = _driver.reveal;
    final thud = r?.thud ?? !deathsOf(endSeatsOf(widget.outcome)).nobody;
    thud ? Haptics.thud(context) : Haptics.light(context);
  }

  /// The board settled before its time (a touch, a turned phone): the one
  /// knock, if none had come yet; the rest of the reveal is not played.
  void _settle() {
    if (_settled || !mounted) return;
    if (_knocked == 0) _knock();
    _clock.stop();
    setState(() => _settled = true);
  }

  /// The board is planned: the reveal's timeline is made once from it and the
  /// clock starts. A board planned again (a turned phone) settles.
  void _planned(EndBoardPlan plan) {
    if (_settled) return;
    if (_revealed != null) {
      if (!identical(plan, _revealed)) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _settle();
        });
      }
      return;
    }
    _revealed = plan;
    final reveal = revealOf(plan);
    _driver.reveal = reveal;
    _clock.duration = reveal.total;
    unawaited(_clock.forward());
  }

  (Object, double, double)? _fit;
  (Object, EndBoardPlan)? _plan;

  @override
  Widget build(BuildContext context) {
    final page = DressScope(
      dress: Dress.paper,
      child: FrameMark(
        child: Builder(
          builder: (context) => Scaffold(
            backgroundColor: context.skin.night.ground,
            body: GroundScope(
              ground: GroundKind.night,
              child: LayoutBuilder(builder: _page),
            ),
          ),
        ),
      ),
    );
    final fade = _fade;
    return EndNightScope(
      night: _night,
      child: EndRevealScope(
        driver: _settled ? null : _driver,
        child: Listener(
          // A touch anywhere settles the reveal; it is no button of its own,
          // and the controls under it take the same touch.
          behavior: HitTestBehavior.translucent,
          onPointerDown: (_) => _settle(),
          child: fade == null
              ? page
              : FadeTransition(opacity: fade, child: page),
        ),
      ),
    );
  }

  /// "What happened": the reveal (if it plays) settles and the night falls;
  /// at night the same scrap goes back to the result.
  void _whatHappened() {
    _settle();
    if (_night.on) {
      _night.close();
    } else {
      _night.open();
      widget.onWhatHappened?.call();
    }
  }

  Widget _page(BuildContext context, BoxConstraints box) {
    final outcome = widget.outcome;
    final type = context.skin.typography;
    final direction = Directionality.of(context);
    final screen = Size(box.maxWidth, box.maxHeight);
    // The banner first: how tall its words are decides where the board starts.
    final banner = endBannerOf(outcome, widget.viewerId);
    final scale = MediaQuery.textScalerOf(context).scale(1);
    // Fitted once for this width and text size, not on every build.
    // Keyed on all it reads: a new payload or viewer is fitted again.
    final fitKey = (
      outcome,
      widget.viewerId,
      screen.width,
      scale,
      direction,
      type.screenTitle,
    );
    double heightOf(List<String> forms, int minLines) => BannerSlice.heightOf(
      BannerSlice.fit(
        forms: forms,
        minLines: minLines,
        room: screen.width - 2 * BannerSlice.margin,
        style: type.screenTitle,
        direction: direction,
        scale: scale,
      ),
      type.screenTitle,
      direction,
    );
    // The banner keeps the room its tallest words need, the result's or a
    // line of the night's, so the board never moves when the words change.
    final (bannerHeight, bannerRoom) = _fit?.$1 == fitKey
        ? (_fit!.$2, _fit!.$3)
        : () {
            final h = heightOf(banner.forms, 2);
            final story = _night.story;
            final room = [
              h,
              if (story != null)
                for (final line in [
                  StoryCopy.dealt,
                  ...story.steps.map((s) => s.line),
                ])
                  heightOf([line], 1),
            ].reduce(math.max);
            _fit = (fitKey, h, room);
            return (h, room);
          }();
    final bannerTop = EndMetrics.bannerTopFor(screen.height);
    final boardTop = EndMetrics.boardTopFor(screen.height, bannerRoom);
    final windowTop = boardTop - EndMetrics.roof;
    final page = Stack(
      children: [
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: boardTop + EndMetrics.roof,
          child: Stack(
            children: [
              Positioned.fill(child: _still(context, const _DawnSky())),
              const Positioned.fill(child: NightSky()),
            ],
          ),
        ),
        Positioned.fill(
          child: Column(
            children: [
              SizedBox(height: windowTop),
              Expanded(
                child: LayoutBuilder(
                  builder: (context, window) => _window(
                    context,
                    screen: screen,
                    boardTop: boardTop,
                    view: window.maxHeight - EndMetrics.roof,
                  ),
                ),
              ),
              _still(
                context,
                EndFootBand(
                  foot: EndFoot(
                    host: widget.isHost,
                    whatHappened: outcome.timeline != null,
                    hostName: widget.hostName,
                  ),
                  centre: outcome.result.centerCards,
                  screenHeight: screen.height,
                  busy: widget.busy,
                  failure: widget.failure,
                  onTryAgain: widget.onTryAgain,
                  onWhatHappened: _whatHappened,
                  onEditDeck: widget.onEditDeck,
                  onPlayAgain: widget.onPlayAgain,
                  onLeave: widget.onLeave,
                ),
              ),
            ],
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: windowTop,
          child: _still(context, BoardRoof(width: screen.width)),
        ),
        // A thread down to a middle card in the foot, over the board's lip.
        Positioned.fill(child: NightFootLinks(boardTop: boardTop)),
        Positioned(
          left: 0,
          right: 0,
          top: bannerTop,
          child: _unrolled(
            context,
            _NightBanner(
              day: BannerSlice.sentences(
                forms: banner.forms,
                minLines: 2,
                red: banner.red,
              ),
            ),
            width: screen.width,
            height: bannerHeight,
            // At rest the roll lies on the roof.
            restDrop: windowTop - bannerTop - FurledScroll.thickness,
          ),
        ),
      ],
    );
    return NotificationListener<ScrollUpdateNotification>(
      onNotification: (n) {
        _night.scrolled.value = n.metrics.pixels;
        return false;
      },
      child: page,
    );
  }

  /// What holds still in the reveal is its own layer, painted once. Settled
  /// it keeps the same layer: settling the board must not rebuild the foot's
  /// controls under a touch, or the touch that settled it is lost.
  Widget _still(BuildContext context, Widget piece) =>
      RepaintBoundary(child: piece);

  /// The banner; in the reveal furled on the roof until its beat.
  Widget _unrolled(
    BuildContext context,
    Widget banner, {
    required double width,
    required double height,
    required double restDrop,
  }) {
    final driver = EndRevealScope.maybeOf(context);
    return driver == null
        ? banner
        : revealUnroll(
            driver,
            banner,
            width: width,
            height: height,
            restDrop: restDrop,
          );
  }

  /// The board in its window, planned for the room the window has.
  Widget _window(
    BuildContext context, {
    required Size screen,
    required double boardTop,
    required double view,
  }) {
    final type = context.skin.typography;
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    TextPainter set(TextStyle style, String text) => TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: direction,
      textScaler: scaler,
      maxLines: 1,
    )..layout();
    double measure(TextStyle style, String text) {
      final p = set(style, text);
      final w = p.width;
      p.dispose();
      return w;
    }

    double lineHeight(TextStyle style) {
      final p = set(style, 'Ag');
      final h = p.height;
      p.dispose();
      return h;
    }

    // Planned once for this room and text size, not on every build; keyed on
    // everything the plan reads, so a changed payload, viewer or host is
    // planned again.
    final key = (
      widget.outcome,
      widget.viewerId,
      widget.isHost,
      widget.hostName,
      screen,
      boardTop,
      view,
      scaler,
      direction,
      type,
    );
    final kept = _plan;
    final plan = kept != null && kept.$1 == key
        ? kept.$2
        : planEndBoard(
            outcome: widget.outcome,
            viewerId: widget.viewerId,
            isHost: widget.isHost,
            hostName: widget.hostName,
            screen: screen,
            boardTop: boardTop,
            viewHeight: view,
            nameLine: lineHeight(type.name),
            roleLine: lineHeight(type.tag),
            measure: (kind, text) => switch (kind) {
              EndText.role => measure(type.tag, text),
              EndText.name ||
              EndText.tag ||
              EndText.slip => measure(type.name, text),
            },
          );
    _plan = (key, plan);
    _planned(plan);
    if (!identical(_night.laidOut.value, plan)) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (mounted) _night.laidOut.value = plan;
      });
    }
    return _still(
      context,
      EndBoardWindow(plan: plan, scrollController: widget.scrollController),
    );
  }
}

/// The square at dawn above the board: the sky plate under a dusk (the
/// skin's), then the gallows and the roofs, so the banner is the bright thing.
class _DawnSky extends StatelessWidget {
  const _DawnSky();

  @override
  Widget build(BuildContext context) => LayeredArt(
    LayeredSceneId.dawnGallows,
    travel: false,
    slots: {
      'sun': (context, geometry, slot, arrival) {
        final parts = context.skin.parts;
        final dusk = IgnorePointer(
          child: Align(
            alignment: Alignment.topCenter,
            child: SizedBox(
              height: parts.duskReach,
              width: double.infinity,
              child: DecoratedBox(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: parts.duskTint,
                    stops: parts.duskStops,
                  ),
                ),
              ),
            ),
          ),
        );
        // At night the moon is up behind the hills and the roofs.
        return Stack(
          children: [
            Positioned.fill(child: dusk),
            const Positioned.fill(child: NightMoon()),
          ],
        );
      },
    },
  );
}

/// The banner: the result by day ([day]); while the night plays, the step's
/// line, read out as each step comes and a screen reader's way on. Bone at
/// night: red is the result's (the Werewolf team won).
class _NightBanner extends StatelessWidget {
  const _NightBanner({required this.day});

  final Widget day;

  @override
  Widget build(BuildContext context) {
    final night = EndNightScope.maybeOf(context);
    if (night == null || !night.on) return day;
    return Semantics(
      liveRegion: true,
      button: true,
      label: night.line,
      onTap: night.next,
      excludeSemantics: true,
      child: BannerSlice.sentences(forms: [night.line]),
    );
  }
}
