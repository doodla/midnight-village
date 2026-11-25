part of 'night_board.dart';

/// The pieces the night board is put together from (the board itself, its
/// labels and rule, the players' band, the strip, a player's card, a centre
/// card, "You"): the half of [_NightBoardState] that draws. The other half,
/// in night_board.dart, holds the picks, the fidgets and the screen around
/// the board. One class in two files, so each can be read whole.
mixin _NightBoardPieces on ConsumerState<NightBoard> {
  // What this half uses of the other, defined in [_NightBoardState].
  abstract List<NightPick> _picks;
  bool get _opened;
  void _putAway();
  void _tap(NightPick pick);
  Widget _fidget(NightPick pick, Widget card);

  /// The board with, over it while a result is up by itself, the layer that
  /// takes the first touch (and Back) and puts it away. The board keeps its
  /// place in the tree either way, so opening rebuilds nothing of it.
  Widget _withResult(Widget board) => BackHandler(
    open: _opened,
    onBack: _putAway,
    child: Stack(
      fit: StackFit.expand,
      children: [
        board,
        if (_opened)
          Positioned.fill(
            child: UntilTouched(
              child: Semantics(
                button: true,
                label: RoleSheetCopy.close,
                onTap: _putAway,
                child: GestureDetector(
                  behavior: HitTestBehavior.opaque,
                  excludeFromSemantics: true,
                  onTapDown: (_) => _putAway(),
                ),
              ),
            ),
          ),
      ],
    ),
  );

  /// The other seats in [layout]'s rows, then the band in front of the
  /// player; what is to spare (little: the cards grew to the room) goes in
  /// equal shares above the seats, between the rows and between them and
  /// the band, so no one gap is a dead band.
  Widget _board(
    BoardLayout layout,
    Size room,
    Widget Function(Widget card) wave,
  ) {
    final spare = math.max(0.0, room.height - layout.used);
    final share = spare / (layout.rows.length + 1);
    final others = [
      for (final seat in widget.seats)
        if (seat.id != widget.selfId) seat,
    ];
    final me = widget.seats.firstWhere((s) => s.id == widget.selfId);
    var at = 0;
    final rows = [
      for (final count in layout.rows)
        [for (var i = 0; i < count; i++) others[at++]],
    ];
    Widget seat(NightSeat seat) =>
        SizedBox(width: layout.column, child: wave(_player(seat, layout)));
    // Below the board's own DressScope: `context` here is the dressed one (the
    // State's own context is above it and always reads the plain dress).
    return Builder(
      builder: (context) => Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          SizedBox(height: share),
          // Room for the Seer's "1 player", empty on every other board.
          SizedBox(
            height: layout.seatLabelRoom,
            child: widget.prompt.kind.seats == null
                ? null
                : Align(
                    alignment: Alignment.topCenter,
                    child: _label(widget.prompt.kind.seats!),
                  ),
          ),
          for (final (i, row) in rows.indexed) ...[
            if (i > 0) SizedBox(height: BoardLayout.rowGap + share),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: BoardLayout.columnGap,
              children: [for (final s in row) seat(s)],
            ),
          ],
          SizedBox(height: share / 2),
          // The gap above the band: her rule with "or" on it, empty on every
          // other board, in the middle of it.
          SizedBox(
            height: layout.ruleRoom,
            child: widget.prompt.kind.seats == null ? null : _rule(context),
          ),
          SizedBox(height: share / 2),
          _band(context, me, layout, wave),
        ],
      ),
    );
  }

  /// A label on the board: a caption line in full ink, like the captions
  /// under the cards.
  Widget _label(String text) => Builder(
    // Read the ground where the label is drawn (the screen's own scope), for
    // the ink of its plate.
    builder: (context) => TextBacking(
      id: text,
      child: FitWords(
        text,
        textAlign: TextAlign.center,
        maxLines: 1,
        style: context.skin.typography.caption.copyWith(
          color: TextBacking.inkOf(context),
        ),
      ),
    ),
  );

  /// The Seer's thin rule with "or" on it, between her seats and the table's
  /// cards.
  Widget _rule(BuildContext context) {
    // Dressed up the word stands alone on its tag: no line either side.
    if (context.dress.isPaper) return Center(child: _label(NightCopy.seerOr));
    final line = Expanded(
      child: Container(height: 1, color: context.ground.hairline),
    );
    return Row(
      spacing: Space.md,
      children: [
        const SizedBox(width: Space.sm),
        line,
        _label(NightCopy.seerOr),
        line,
        const SizedBox(width: Space.sm),
      ],
    );
  }

  /// In front of the player: their own card on its paper place, and the
  /// table's three cards, dropped at a slant on a strip of the table.
  Widget _band(
    BuildContext context,
    NightSeat me,
    BoardLayout layout,
    Widget Function(Widget card) wave,
  ) {
    final skin = context.skin;
    const padding = EdgeInsets.symmetric(
      horizontal: BoardLayout.bandPaddingSide,
      vertical: BoardLayout.bandPadding,
    );
    return Center(
      child: SizedBox(
        height: layout.bandHeight,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: BoardLayout.placeGap,
          children: [
            _you(me, layout, wave, padding),
            _strip(
              context,
              // No padding under the cards: their cells reach into it
              // (`tapExtra`), so a tap is a thumb's height on a small card.
              padding: padding.copyWith(bottom: 0),
              plain: BoxDecoration(
                color: context.ground.panel,
                borderRadius: BorderRadius.circular(skin.shape.radius),
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  SizedBox(
                    width: 3 * layout.bandCell + 2 * BoardLayout.tableCardGap,
                    height: layout.labelRoom,
                    child: Align(
                      alignment: Alignment.topCenter,
                      child: _label(
                        widget.prompt.kind.strip ?? NightCopy.centerLabel,
                      ),
                    ),
                  ),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.start,
                    spacing: BoardLayout.tableCardGap,
                    children: [
                      for (var i = 0; i < 3; i++)
                        SizedBox(
                          width: layout.bandCell,
                          child: wave(_center(i, layout)),
                        ),
                    ],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  /// The strip of the table the centre cards lie on: plain, a panel colour;
  /// dressed up, a panel of paper (a [PaperPiece]) with its shadow.
  Widget _strip(
    BuildContext context, {
    required EdgeInsets padding,
    required BoxDecoration plain,
    required Widget child,
  }) => context.dress.isPaper
      ? PaperPiece(
          part: PaperPart.panel,
          id: #strip,
          child: Padding(padding: padding, child: child),
        )
      : Container(padding: padding, decoration: plain, child: child);

  /// A card that cannot join the pick being made sits dimmed (a sleeper's
  /// board has no pick to make: nothing dims).
  bool _dims(NightPick pick) =>
      !widget.prompt.sleeps && widget.prompt.rule.dims(pick, _picks);

  /// A dimmed card says to a screen reader that a tap still switches the
  /// pick: dimmed here is not switched off.
  String? _hint(NightPick pick) => _dims(pick) ? NightCopy.switchesPick : null;

  Widget _player(NightSeat seat, BoardLayout layout) {
    final pick = PlayerPick(seat.id);
    return _fidget(
      pick,
      FaceDownCard(
        size: FaceDownSize.board,
        cardWidth: layout.cardWidth,
        nameSize: layout.nameSize,
        nameHeight: layout.nameHeight,
        owner: seat.token,
        ownerName: seat.name,
        selected: _picks.contains(pick),
        dimmed: _dims(pick),
        semanticLabel: seat.name,
        semanticHint: _hint(pick),
        onTap: () => _tap(pick),
      ),
    );
  }

  Widget _center(int index, BoardLayout layout) {
    final pick = CenterPick(index);
    return _fidget(
      pick,
      FaceDownCard(
        size: FaceDownSize.board,
        cardWidth: layout.bandCard,
        caption: centerName(index),
        tilt: Tilt.scatter(index),
        selected: _picks.contains(pick),
        dimmed: _dims(pick),
        tapExtra: BoardLayout.bandPadding,
        semanticLabel: centerName(index),
        semanticHint: _hint(pick),
        onTap: () => _tap(pick),
      ),
    );
  }

  /// The player's own card on its paper place: a tap anywhere on the place
  /// picks it, a hold anywhere on it shows [NightBoard.face].
  Widget _you(
    NightSeat seat,
    BoardLayout layout,
    Widget Function(Widget card) wave,
    EdgeInsets padding,
  ) {
    void pick() => _tap(const SelfPick());
    return TeachingHold(
      target: NightCopy.you,
      face: widget.face,
      open: _opened,
      onRevealChanged: (shown) {
        if (!shown) _putAway();
      },
      cover: (teaching) => GestureDetector(
        onTap: pick,
        behavior: HitTestBehavior.opaque,
        excludeFromSemantics: true,
        child: PaperCard(
          // Level with the strip's cards, which sit under its label.
          padding: padding.copyWith(
            top: padding.top + layout.labelRoom,
            bottom: 0,
          ),
          child: SizedBox(
            width: layout.bandCell,
            child: wave(
              _fidget(
                const SelfPick(),
                FaceDownCard(
                  size: FaceDownSize.board,
                  cardWidth: layout.bandCard,
                  nameSize: layout.nameSize,
                  nameHeight: layout.youNameHeight,
                  tapExtra: BoardLayout.bandPadding,
                  owner: seat.token,
                  ownerName: NightCopy.you,
                  youName: true,
                  selected: _picks.contains(const SelfPick()),
                  semanticLabel: NightCopy.you,
                  // Said after "You": which card it is.
                  semanticHint: widget.dealt.displayName,
                  face: widget.dealt,
                  onTap: pick,
                ),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
