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
/// dawn, lit by one lantern. The banner says who was hanged and what that
/// means for this phone's player; every player's card is pinned on the board
/// (winners larger and in the light, the hanged with a black ribbon, the votes
/// as name tags under the card they chose); at the foot are the scraps and the
/// one amber plaque. The board is the plan `planEndBoard` made: this only draws
/// it. With ten players it scrolls between the fixed banner (the roof its eave)
/// and the fixed foot. No motion: the reveal and "What happened" are other
/// pieces.
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
            child: LayoutBuilder(builder: _board),
          ),
        ),
      ),
    ),
  );

  Widget _board(BuildContext context, BoxConstraints box) {
    final skin = context.skin;
    final type = skin.typography;
    final scaler = MediaQuery.textScalerOf(context);
    final direction = Directionality.of(context);
    double measure(TextStyle style, String text) {
      final p = TextPainter(
        text: TextSpan(text: text, style: style),
        textDirection: direction,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      final w = p.width;
      p.dispose();
      return w;
    }

    double lineHeight(TextStyle style) {
      final p = TextPainter(
        text: TextSpan(text: 'Ag', style: style),
        textDirection: direction,
        textScaler: scaler,
        maxLines: 1,
      )..layout();
      final h = p.height;
      p.dispose();
      return h;
    }

    final screen = Size(box.maxWidth, box.maxHeight);
    // The banner first: how many lines it takes decides where the board starts.
    final forms = endBannerOf(outcome, viewerId);
    final fit = BannerSlice.fit(
      forms: forms.forms,
      minLines: 2,
      room: screen.width - 2 * BannerSlice.margin,
      style: type.screenTitle,
      direction: direction,
      scale: scaler.scale(1),
    );
    final plan = planEndBoard(
      outcome: outcome,
      viewerId: viewerId,
      isHost: isHost,
      hostName: hostName,
      screen: screen,
      bannerLines: fit.lines.length,
      nameLine: lineHeight(type.name),
      roleLine: lineHeight(type.tag),
      measure: (kind, text) => switch (kind) {
        EndText.role => measure(type.tag, text),
        EndText.name || EndText.tag || EndText.slip => measure(type.name, text),
      },
    );
    return EndBoardLayout(
      plan: plan,
      forms: forms.forms,
      red: forms.red,
      isHost: isHost,
      playAgainBusy: playAgainBusy,
      onWhatHappened: onWhatHappened,
      onEditDeck: onEditDeck,
      onPlayAgain: onPlayAgain,
      onLeave: onLeave,
      scrollController: scrollController,
    );
  }
}

/// The plan drawn on a page: sky, board (scrolling when the plan says so),
/// roof, banner, the foot.
class EndBoardLayout extends StatelessWidget {
  const EndBoardLayout({
    super.key,
    required this.plan,
    required this.forms,
    required this.red,
    required this.isHost,
    required this.playAgainBusy,
    required this.onWhatHappened,
    required this.onEditDeck,
    required this.onPlayAgain,
    required this.onLeave,
    this.scrollController,
  });

  final EndBoardPlan plan;
  final List<String> forms;
  final bool red;
  final bool isHost;
  final bool playAgainBusy;
  final VoidCallback onWhatHappened;
  final VoidCallback onEditDeck;
  final VoidCallback onPlayAgain;
  final VoidCallback onLeave;
  final ScrollController? scrollController;

  /// The board stands in from the screen's edge by half the margin.
  static const _side = EndMetrics.boardMargin / 2;

  @override
  Widget build(BuildContext context) {
    final screen = plan.screen;
    final footTop = screen.height - EndMetrics.foot;
    final windowTop = plan.boardTop - EndMetrics.roof;
    // The board's content: the roof's height of air above the frame, for the
    // lantern's hook and the eave.
    const origin = Offset(_side, EndMetrics.roof);
    final contentHeight = plan.boardHeight + EndMetrics.roof;
    final content = SizedBox(
      width: screen.width,
      height: contentHeight,
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
          HunterTwine(plan: plan, origin: origin),
          for (final c in plan.cards)
            EndCardView(card: c, plan: plan, origin: origin),
          for (final c in plan.cards) EndTagsView(card: c, origin: origin),
          if (plan.pick case final pick?) _slip(context, pick, origin),
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
    final window = ClipRect(
      child: OneLightScope(
        light: OneLight(plan.light + origin),
        child: plan.scrolls
            ? SingleChildScrollView(
                controller: scrollController,
                physics: const ClampingScrollPhysics(),
                child: content,
              )
            : content,
      ),
    );
    return Stack(
      children: [
        Positioned(
          left: 0,
          right: 0,
          top: 0,
          height: plan.boardTop + EndMetrics.roof,
          child: LayeredArt(LayeredSceneId.dawnGallows, travel: false),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: windowTop,
          height: footTop - windowTop,
          child: window,
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
          top: 36,
          child: BannerSlice.sentences(forms: forms, minLines: 2, red: red),
        ),
        Positioned(
          left: 0,
          right: 0,
          top: footTop - EndMetrics.lip,
          bottom: 0,
          child: const BoardFoot(height: double.infinity),
        ),
        ...endFootPieces(
          context,
          plan: plan,
          top: footTop,
          playAgainBusy: playAgainBusy,
          onWhatHappened: onWhatHappened,
          onEditDeck: onEditDeck,
          onPlayAgain: onPlayAgain,
          onLeave: onLeave,
        ),
      ],
    );
  }

  Widget _slip(BuildContext context, EndPick pick, Offset origin) {
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
