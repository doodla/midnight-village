import 'package:flutter/material.dart';

import '../../../../design_system/copy/copy.dart';
import '../../../../design_system/primitives/board_pieces.dart';
import '../../../../design_system/primitives/end_lantern.dart';
import '../../../../design_system/primitives/layered_art.dart';
import '../../../../design_system/primitives/one_light.dart';
import '../../../../design_system/primitives/paper_scrap.dart';
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
import '../../domain/game_outcome.dart';
import 'end_cards.dart';
import 'end_foot.dart';

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
class EndBoardView extends StatelessWidget {
  const EndBoardView({
    super.key,
    required this.outcome,
    required this.viewerId,
    required this.isHost,
    required this.hostName,
    required this.onWhatHappened,
    required this.onEditDeck,
    required this.onPlayAgain,
    required this.onLeave,
    this.playAgainBusy = false,
    this.scrollController,
  });

  final GameOutcome outcome;
  final int viewerId;
  final bool isHost;

  /// The host's name, while the host is at the table: a guest's "{host} deals
  /// next." (null: not said).
  final String? hostName;
  final VoidCallback onWhatHappened;
  final VoidCallback onEditDeck;
  final VoidCallback onPlayAgain;
  final VoidCallback onLeave;
  final bool playAgainBusy;
  final ScrollController? scrollController;

  @override
  Widget build(BuildContext context) => DressScope(
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

  Widget _page(BuildContext context, BoxConstraints box) {
    final type = context.skin.typography;
    final direction = Directionality.of(context);
    final screen = Size(box.maxWidth, box.maxHeight);
    // The banner first: how tall its words are decides where the board starts.
    final banner = endBannerOf(outcome, viewerId);
    final fit = BannerSlice.fit(
      forms: banner.forms,
      minLines: 2,
      room: screen.width - 2 * BannerSlice.margin,
      style: type.screenTitle,
      direction: direction,
      scale: MediaQuery.textScalerOf(context).scale(1),
    );
    final bannerHeight = BannerSlice.heightOf(fit, type.screenTitle, direction);
    final bannerTop = EndMetrics.bannerTopFor(screen.height);
    final boardTop = EndMetrics.boardTopFor(screen.height, bannerHeight);
    final windowTop = boardTop - EndMetrics.roof;
    return Stack(
      children: [
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: boardTop + EndMetrics.roof,
          child: const _DawnSky(),
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
              EndFootBand(
                foot: EndFoot(
                  host: isHost,
                  whatHappened: outcome.timeline != null,
                  hostName: hostName,
                ),
                centre: outcome.result.centerCards,
                screenHeight: screen.height,
                playAgainBusy: playAgainBusy,
                onWhatHappened: onWhatHappened,
                onEditDeck: onEditDeck,
                onPlayAgain: onPlayAgain,
                onLeave: onLeave,
              ),
            ],
          ),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: windowTop,
          child: BoardRoof(width: screen.width),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: bannerTop,
          child: BannerSlice.sentences(
            forms: banner.forms,
            minLines: 2,
            red: banner.red,
          ),
        ),
      ],
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

    final plan = planEndBoard(
      outcome: outcome,
      viewerId: viewerId,
      isHost: isHost,
      hostName: hostName,
      screen: screen,
      boardTop: boardTop,
      viewHeight: view,
      nameLine: lineHeight(type.name),
      roleLine: lineHeight(type.tag),
      measure: (kind, text) => switch (kind) {
        EndText.role => measure(type.tag, text),
        EndText.name || EndText.tag || EndText.slip => measure(type.name, text),
      },
    );
    return EndBoardWindow(plan: plan, scrollController: scrollController);
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
        return IgnorePointer(
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
      },
    },
  );
}

/// The board's window: the frame, the cards and what hangs on them, the
/// light, the lantern; scrolling when the plan says so, opened where the plan
/// says ([EndBoardPlan.initialScroll]).
class EndBoardWindow extends StatefulWidget {
  const EndBoardWindow({super.key, required this.plan, this.scrollController});

  final EndBoardPlan plan;
  final ScrollController? scrollController;

  @override
  State<EndBoardWindow> createState() => _EndBoardWindowState();
}

class _EndBoardWindowState extends State<EndBoardWindow> {
  ScrollController? _own;
  var _opened = false;

  ScrollController get _controller =>
      widget.scrollController ??
      (_own ??= ScrollController(
        initialScrollOffset: widget.plan.initialScroll,
      ));

  @override
  void initState() {
    super.initState();
    _openWhereTheHangedAre();
  }

  @override
  void didUpdateWidget(EndBoardWindow old) {
    super.didUpdateWidget(old);
    _openWhereTheHangedAre();
  }

  /// A controller from outside starts at 0: it is moved, once, where the
  /// plan opens the board.
  void _openWhereTheHangedAre() {
    final given = widget.scrollController;
    if (given == null || _opened || widget.plan.initialScroll == 0) return;
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || !given.hasClients || _opened) return;
      _opened = true;
      given.jumpTo(widget.plan.initialScroll);
    });
  }

  @override
  void dispose() {
    _own?.dispose();
    super.dispose();
  }

  /// The board stands in from the screen's edge by half the margin.
  static const _side = EndMetrics.boardMargin / 2;

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    // The board's content: the roof's height of air above the frame, for the
    // lantern's hook and the eave.
    const origin = Offset(_side, EndMetrics.roof);
    final content = SizedBox(
      width: plan.screen.width,
      height: plan.boardHeight + EndMetrics.roof,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            left: _side,
            top: EndMetrics.roof,
            width: plan.boardWidth,
            height: plan.boardHeight,
            child: const BoardFrame(child: SizedBox.expand()),
          ),
          StrandTwines(plan: plan, origin: origin),
          for (final pick in plan.picks)
            HunterTwine(plan: plan, pick: pick, origin: origin),
          for (final c in plan.cards)
            EndCardView(card: c, plan: plan, origin: origin),
          for (final c in plan.cards) EndTagsView(card: c, origin: origin),
          for (final pick in plan.picks) _slip(pick, origin),
          Positioned(
            left: _side,
            top: EndMetrics.roof,
            width: plan.boardWidth,
            height: plan.boardHeight,
            child: BoardLight(
              size: Size(plan.boardWidth, plan.boardHeight),
              light: plan.light,
              pools: [for (final c in plan.pool) c.rect],
            ),
          ),
          Positioned(
            left: plan.lantern.left + _side,
            top: plan.lantern.top + EndMetrics.roof,
            child: const EndLantern(),
          ),
        ],
      ),
    );
    return ClipRect(
      child: OneLightScope(
        light: OneLight(plan.light + origin),
        child: plan.scrolls
            ? SingleChildScrollView(
                controller: _controller,
                physics: const ClampingScrollPhysics(),
                child: content,
              )
            : content,
      ),
    );
  }

  Widget _slip(EndPick pick, Offset origin) {
    final r = pick.slip;
    return Positioned(
      left: r.left + origin.dx,
      top: r.top + origin.dy,
      width: r.width,
      child: LitAt(
        rect: r,
        child: PaperSlip(
          label: EndCopy.picked.fill({'hunter': pick.hunterName}),
        ),
      ),
    );
  }
}
