import 'dart:async';

import 'package:flutter/material.dart';

import '../../../../design_system/layout/space.dart';

import '../../../../design_system/copy/copy.dart';
import '../../../../design_system/primitives/board_pieces.dart';
import '../../../../design_system/primitives/end_lantern.dart';
import '../../../../design_system/primitives/one_light.dart';
import '../../../../design_system/primitives/paper_scrap.dart';
import '../../../../design_system/primitives/sliced_art.dart';
import '../../domain/end_board.dart';
import '../../domain/end_board_metrics.dart';
import '../../domain/end_reveal.dart';
import '../../domain/night_timeline.dart';
import 'end_cards.dart';
import 'end_foot.dart' show middleCardsAt;
import 'end_night.dart';
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
  EndNight? _night;
  int? _shown;
  double? _dayOffset;

  // The board opens where the hanged are in view, in the reveal from its
  // first frame too: the seats never move while it plays.
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
  void didChangeDependencies() {
    super.didChangeDependencies();
    final night = EndNightScope.read(context);
    if (night == _night) return;
    _night?.removeListener(_stepped);
    _night = night?..addListener(_stepped);
  }

  @override
  void dispose() {
    _night?.removeListener(_stepped);
    _own?.dispose();
    super.dispose();
  }

  /// A step of the night shown: on a board that scrolls, its cards are
  /// brought into view as it plays (above the caption on the rail), the
  /// middle's at the board's foot.
  void _stepped() {
    final night = _night;
    final step = night?.current;
    final shown = night?.step;
    if (shown == _shown) return;
    final c = _controller;
    final scrolled = widget.plan.scrolls && c.hasClients;
    // The board goes back to where it stood by day, exactly.
    if (_shown == null && scrolled) _dayOffset = c.offset;
    _shown = shown;
    if (shown == null) {
      if (scrolled && _dayOffset != null) c.jumpTo(_dayOffset!);
      _dayOffset = null;
      return;
    }
    if (step == null || !scrolled) return;
    final plan = widget.plan;
    final position = c.position;
    var top = double.infinity, bottom = 0.0;
    // The players' cards: a twine to the middle runs down off the board
    // from wherever its card is.
    for (final place in step.places.whereType<PlayerPlace>()) {
      final r = plan
          .card(place.playerId)
          .reach
          .shift(const Offset(_side, EndMetrics.roof));
      top = top < r.top ? top : r.top;
      bottom = bottom > r.bottom ? bottom : r.bottom;
    }
    final view = position.viewportDimension - nightCaptionRoom;
    var to = position.pixels;
    if (bottom > to + view) to = bottom - view;
    if (top - Space.md < to) to = top - Space.md;
    to = to.clamp(position.minScrollExtent, position.maxScrollExtent);
    if (to == position.pixels) return;
    if (night!.cut) {
      c.jumpTo(to);
    } else {
      unawaited(c.animateTo(to, duration: Motion.settle, curve: Motion.curve));
    }
  }

  /// The board stands in from the screen's edge by half the margin.
  static const _side = EndMetrics.boardMargin / 2;

  @override
  Widget build(BuildContext context) {
    final plan = widget.plan;
    final driver = EndRevealScope.maybeOf(context);
    // What holds still in the reveal is its own layer, painted once; the
    // settled board keeps the same layers, so settling changes no element
    // above a control (a touch that settles the board is still the control's).
    Widget still(Widget piece) => RepaintBoundary(child: piece);
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
          // The settled board, hidden as it is while the night plays.
          Positioned.fill(
            child: NightHides(
              child: Stack(
                clipBehavior: Clip.none,
                children: _settled(plan, driver, frame, origin, light),
              ),
            ),
          ),
          Positioned.fill(
            child: NightBoard(
              plan: plan,
              origin: origin,
              centre: [
                for (final r in middleCardsAt(
                  context,
                  plan.centre,
                  plan.screen.width,
                ))
                  r.translate(-_side, plan.boardHeight + Space.xl),
              ],
            ),
          ),
        ],
      ),
    );
    final night = EndNightScope.read(context);
    final window = ClipRect(
      child: OneLightScope(
        light: OneLight(plan.light + origin),
        child: plan.scrolls
            ? SingleChildScrollView(
                controller: _controller,
                physics: const ClampingScrollPhysics(),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [still(content), const _NightRoom()],
                ),
              )
            : content,
      ),
    );
    if (night == null) return window;
    // At night a tap is the next step (or finishes the one playing), a swipe
    // to the left the next and to the right the one before.
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      excludeFromSemantics: true,
      onTap: night.next,
      onHorizontalDragEnd: (d) {
        final v = d.primaryVelocity ?? 0;
        if (v < 0) night.next();
        if (v > 0) night.back();
      },
      child: Stack(
        children: [
          Positioned.fill(child: window),
          Positioned(
            left: 0,
            right: 0,
            bottom: EndMetrics.lip + Space.sm,
            child: Center(child: NightCaption(width: plan.boardWidth)),
          ),
        ],
      ),
    );
  }

  /// The settled board's pieces over its frame: what hangs on the cards, the
  /// cards, the light and the lantern, and the reveal's moments.
  List<Widget> _settled(
    EndBoardPlan plan,
    EndRevealDriver? driver,
    Rect frame,
    Offset origin,
    Widget Function(List<Rect> pools) light,
  ) {
    Widget still(Widget piece) => RepaintBoundary(child: piece);
    return [
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
      if (driver?.reveal case final reveal?) ...[
        Positioned.fromRect(
          rect: frame,
          child: RevealDim(driver: driver!),
        ),
        for (final id in reveal.dead)
          Positioned.fromRect(
            rect: reveal.up[id]!.shift(origin),
            child: RevealHanged(
              driver: driver,
              card: plan.card(id),
              face: EndCardView.faceOf(
                plan.card(id),
                plan,
                up: reveal.up[id],
                litAt: reveal.big[id],
              ),
            ),
          ),
        for (final id in reveal.dead)
          Positioned.fromRect(
            rect: reveal.big[id]!.shift(origin),
            child: RevealStamp(driver: driver, card: plan.card(id)),
          ),
      ],
    ];
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

/// At night, room under a board that scrolls: its lowest cards can be brought
/// up above the caption on the rail. Nothing by day.
class _NightRoom extends StatelessWidget {
  const _NightRoom();

  @override
  Widget build(BuildContext context) => SizedBox(
    height: EndNightScope.maybeOf(context)?.on ?? false ? nightCaptionRoom : 0,
  );
}
