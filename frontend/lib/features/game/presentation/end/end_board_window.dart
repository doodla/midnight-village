import 'package:flutter/material.dart';

import '../../../../design_system/copy/copy.dart';
import '../../../../design_system/layout/space.dart';
import '../../../../design_system/primitives/board_pieces.dart';
import '../../../../design_system/primitives/end_lantern.dart';
import '../../../../design_system/primitives/one_light.dart';
import '../../../../design_system/primitives/paper_scrap.dart';
import '../../../../design_system/primitives/sliced_art.dart';
import '../../domain/end_board.dart';
import '../../domain/end_board_metrics.dart';
import '../../domain/end_reveal.dart';
import 'end_cards.dart';
import 'end_reveal.dart';

// The end board's window (split from end_board_view.dart): the board itself,
// between the fixed eave and the fixed foot.

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
        initialScrollOffset:
            _driver?.reveal?.scrollFrom ??
            (_driver == null ? widget.plan.initialScroll : 0),
      ));

  /// The reveal playing, if it is: the board is scrolled on its clock.
  EndRevealDriver? _driver;

  @override
  void initState() {
    super.initState();
    _openWhereTheHangedAre();
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final driver = EndRevealScope.maybeOf(context);
    if (driver == _driver) return;
    _driver?.clock.removeListener(_scrollOnTheClock);
    _driver = driver;
    driver?.clock.addListener(_scrollOnTheClock);
  }

  /// In the reveal the board stands at the top, then scrolls to the hanged in
  /// its beat.
  void _scrollOnTheClock() {
    final driver = _driver, reveal = driver?.reveal;
    if (driver == null || reveal == null || !widget.plan.scrolls) return;
    final c = _controller;
    if (!c.hasClients) return;
    final to =
        reveal.scrollFrom +
        (reveal.scrollTo - reveal.scrollFrom) *
            Motion.curve.transform(driver.at(RevealBeat.scroll));
    if ((c.offset - to).abs() > 0.01) c.jumpTo(to);
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
      // In the reveal the clock scrolls it ([_scrollOnTheClock]).
      if (!mounted || !given.hasClients || _opened || _driver != null) return;
      _opened = true;
      given.jumpTo(widget.plan.initialScroll);
    });
  }

  @override
  void dispose() {
    _driver?.clock.removeListener(_scrollOnTheClock);
    _own?.dispose();
    super.dispose();
  }

  /// The board stands in from the screen's edge by half the margin.
  static const _side = EndMetrics.boardMargin / 2;

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    final driver = EndRevealScope.maybeOf(context);
    // In the reveal what holds still is its own layer, painted once.
    Widget still(Widget piece) =>
        driver == null ? piece : RepaintBoundary(child: piece);
    final frame = Rect.fromLTWH(
      _side,
      EndMetrics.roof,
      plan.boardWidth,
      plan.boardHeight,
    );
    Widget light(List<Rect> pools) => BoardLight(
      size: Size(plan.boardWidth, plan.boardHeight),
      light: plan.light,
      pools: pools,
    );
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
            child: still(const BoardFrame(child: SizedBox.expand())),
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
            child: driver == null
                ? light([for (final c in plan.pool) c.rect])
                : revealPool(
                    driver,
                    light(const []),
                    light([for (final c in plan.pool) c.rect]),
                  ),
          ),
          Positioned(
            left: plan.lantern.left + _side,
            top: plan.lantern.top + EndMetrics.roof,
            child: still(const EndLantern()),
          ),
          if (driver != null) ...[
            Positioned.fromRect(
              rect: frame,
              child: RevealDim(driver: driver),
            ),
            for (final c in plan.cards)
              if (driver.reveal?.big.containsKey(c.id) ?? c.hanged)
                Positioned.fromRect(
                  rect: c.rect.shift(origin),
                  child: RevealHanged(
                    driver: driver,
                    card: c,
                    face: EndCardView.faceOf(
                      c,
                      plan,
                      up: true,
                      litAt: driver.reveal?.big[c.id],
                    ),
                  ),
                ),
          ],
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
                child: still(content),
              )
            : content,
      ),
    );
  }

  Widget _slip(EndPick pick, Offset origin) {
    final r = pick.slip;
    final slip = LitAt(
      rect: r,
      child: PaperSlip(label: EndCopy.picked.fill({'hunter': pick.hunterName})),
    );
    final driver = EndRevealScope.maybeOf(context);
    return Positioned(
      left: r.left + origin.dx,
      top: r.top + origin.dy,
      width: r.width,
      child: driver == null
          ? slip
          : revealPinned(driver, RevealBeat.pick, pick.pickId, slip),
    );
  }
}
