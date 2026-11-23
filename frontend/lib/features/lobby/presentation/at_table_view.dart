part of 'at_table_screen.dart';

// 02's view (`AtTableView`) and its rows of players: what is drawn, with no providers.
// Part of at_table_screen.dart.

/// 02 drawn from the lobby as [viewerId] sees it (the component sheet and
/// the gallery draw it too). [link] is the table's join link (none: the
/// code alone). A member is dimmed when the lobby says their phone dropped,
/// or when in [away] (the component sheet's state).
class AtTableView extends StatelessWidget {
  const AtTableView({
    super.key,
    required this.lobby,
    required this.viewerId,
    this.link,
    this.away = const {},
    this.dealing = false,
    this.leaving = false,
    this.notSent = false,
    this.leaveFailure,
    this.copied = false,
    this.onRetry,
    this.onShare,
    this.onEditDeck,
    this.onPlayWith,
    this.onDeal,
    this.onLeave,
    this.onGoHome,
    this.dress,
  });

  /// How the screen is dressed (`ScreenFrame.dress`; null: as the screen
  /// above it).
  final Dress? dress;

  /// The dress the live screen has (`dress` null): the one source the test
  /// pages and their sweeps read, never a second constant.
  static const defaultDress = Dress.paper;

  final LobbyState lobby;
  final int viewerId;
  final Uri? link;
  final Set<int> away;
  final bool dealing;
  final bool leaving;
  final bool notSent;

  /// Why the server refused this phone's leave (its words, from copy).
  final RequestFailure? leaveFailure;
  final bool copied;
  final VoidCallback? onRetry;
  final ValueChanged<Uri>? onShare;
  final VoidCallback? onEditDeck;

  /// Fewer came: the host plays with who is here ("Play with {n}").
  final ValueChanged<int>? onPlayWith;
  final VoidCallback? onDeal;
  final VoidCallback? onLeave;
  final VoidCallback? onGoHome;

  bool get _host => lobby.hostId == viewerId;

  @override
  Widget build(BuildContext context) => DressScope(
    dress: dress ?? AtTableView.defaultDress,
    child: Builder(builder: _view),
  );

  Widget _view(BuildContext context) {
    final skin = context.skin;
    final host = _host;
    final refused = lobby.dealRefused;
    // A table nearly empty is about getting the others in: the picture and
    // the large code. Past that, who is here, the deck and Deal come first.
    final roomy = lobby.players.length <= Sizes.nearlyEmptyTable;
    // Who sits, practice changes of the host's on their way included.
    final present = lobby.seatedCount;
    final seats = lobby.table.seats;
    // Back at the table asks first, for host and guest alike, with the
    // host's own "Stay" / "Leave"; a table that is gone goes home. Nothing
    // is asked while a deal or a leave is on its way.
    return ScreenFrame(
      ground: GroundKind.night,
      // Dressed up the village is the mood behind the whole screen, a
      // lantern lighting the table.
      mood: MoodKind.lantern,
      moodLight: MoodLight.high,
      topArt: roomy && !context.dress.isPaper ? skin.art.table : null,
      topArtLayout: TopArtLayout.banner,
      body: Builder(
        // Back asks from a context UNDER the frame (the sheet is lit as the
        // table is: `showSkinSheet` asserts it).
        builder: (context) => BackHandler(
          onBack: () {
            if (lobby.tableClosed) {
              onGoHome?.call();
            } else if (!leaving &&
                !dealing &&
                lobby.startedGameId == null &&
                onLeave != null) {
              unawaited(_confirmLeave(context));
            }
          },
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: roomy ? Space.md : Space.sm,
            children: [
              // A guest waits for the host: said by the screen's shape, no
              // sentence (playtest: Leave read as the one thing to do). Who
              // deals is the loudest line; Leave is a quiet word at the foot.
              if (!host)
                Semantics(
                  header: true,
                  child: FitWords(
                    TableCopy.hostDeals.fill({'host': lobby.hostName}),
                    style: skin.typography.headline,
                  ),
                ),
              _JoinCard(
                code: lobby.code,
                link: link,
                onShare: onShare,
                headline: host,
                // Set for a number there is more to show (the places, the
                // deck): the QR code at its scannable least.
                compact: !roomy || seats != null,
              ),
              // At a number: who is here of it, an empty circle for each place
              // not taken (compact, so the deck and Leave stay in view).
              if (seats != null)
                Padding(
                  padding: const EdgeInsets.only(top: Space.sm),
                  child: SeatsLine(
                    present: present,
                    seats: seats,
                    dots: SeatDots.empty,
                  ),
                ),
              _Rows(
                names: [for (final p in lobby.players) p.displayName],
                rows: [
                  for (final player in lobby.players)
                    _Row(
                      player: player,
                      own: player.id == viewerId,
                      // This phone is here: its own row is never dimmed.
                      away:
                          player.id != viewerId &&
                          (!player.connected || away.contains(player.id)),
                    ),
                ],
                spacing: roomy ? Space.md : Space.sm,
              ),
              // Fewer came: one tap sets the number to who is here.
              if (host &&
                  seats != null &&
                  present >= minSeats &&
                  present < seats)
                Align(
                  child: SecondaryButton(
                    label: TableCopy.playWith.fill({'n': present}),
                    size: ButtonSize.compact,
                    onPressed: () => onPlayWith?.call(present),
                  ),
                ),
              // The game as set up, face up for everyone; the host's opens 03.
              _SetupPanel(lobby: lobby, host: host, onEdit: onEditDeck),
              // A guest has no main button: Leave is a quiet word right under
              // what there is to see, not alone at the foot of an empty screen.
              if (!host)
                Center(
                  child: TextAction(
                    label: CommonCopy.leave,
                    busy: leaving,
                    onPressed: onLeave,
                  ),
                ),
            ],
          ),
        ),
      ),
      actions: [
        if (lobby.tableClosed)
          Notice(
            message: BannerCopy.tableClosed,
            action: BannerCopy.goHome,
            onAction: onGoHome,
          )
        else if (leaveFailure case final failure?)
          Notice(
            message: failure.words,
            action: failure.canRetry ? BannerCopy.tryAgain : null,
            onAction: failure.canRetry ? onRetry : null,
          )
        else if (notSent)
          Notice(
            message: BannerCopy.notSent,
            action: BannerCopy.tryAgain,
            onAction: onRetry,
          )
        // The button already says it when the table's new verdict agrees.
        else if (host &&
            refused != null &&
            refused != _dealWords() &&
            DealState.of(lobby) is! DeckDoesNotFit)
          Notice(message: refused)
        else if (copied)
          const Notice(message: BannerCopy.copied),
        // The host's Leave is a quiet word at the main button's side (it
        // asks first), so it never floats alone in the empty middle of the
        // screen.
        if (host)
          Builder(
            builder: (context) => Row(
              spacing: Space.md,
              children: [
                TextAction(
                  label: CommonCopy.leave,
                  busy: leaving,
                  onPressed: onLeave == null
                      ? null
                      : () => unawaited(_confirmLeave(context)),
                ),
                Expanded(child: _dealButton()),
              ],
            ),
          ),
      ],
    );
  }

  /// The host leaves only after saying so again: the table moves to the
  /// next member the moment the host goes. Back asks it of anyone.
  Future<void> _confirmLeave(BuildContext context) async {
    final leave = await showSkinSheet<bool>(
      context,
      builder: (sheet) => SheetScaffold(
        actions: [
          Expanded(
            child: SecondaryButton(
              label: TableCopy.stay,
              size: ButtonSize.compact,
              onPressed: () => Navigator.of(sheet).pop(false),
            ),
          ),
          PrimaryButton.quiet(
            label: CommonCopy.leave,
            size: ButtonSize.compact,
            onPressed: () => Navigator.of(sheet).pop(true),
          ),
        ],
        child: const SizedBox.shrink(),
      ),
    );
    if ((leave ?? false) && context.mounted) onLeave?.call();
  }

  /// The deal button's words, from the server's verdict ([DealState]): a
  /// button that cannot be taken says what to do, in place.
  String _dealWords() => switch (DealState.of(lobby)) {
    CanDeal() || CanDealSoon() || CannotDeal() => TableCopy.start,
    NeedPlayers() => TableCopy.needPlayers,
    WaitingFor(:final missing) => TableCopy.needMore.fill({'n': missing}),
    DeckDoesNotFit(:final off) => deckFixWords(off),
  };

  /// "Start the game", amber, only when the server says the deal would go.
  /// Never silently disabled (the app's rule): it says what to do and a tap
  /// does it. "Need 3 players" and "Need {n} more" share the table's link (the
  /// code is above; the places are drawn there); "Add 1 card" and "Remove 2
  /// cards" are the fix itself, a tap away: they open 03 where the count shows.
  /// A refusal this phone cannot name leaves it live: the deal's own answer
  /// says why.
  Widget _dealButton() {
    final label = _dealWords();
    void deal() => onDeal?.call();
    if (dealing) {
      return PrimaryButton(label: label, onPressed: deal, busy: true);
    }
    final link = this.link;
    final share = onShare;
    return switch (DealState.of(lobby)) {
      CanDeal() || CannotDeal() => PrimaryButton(label: label, onPressed: deal),
      DeckDoesNotFit() => PrimaryButton(
        label: label,
        onPressed: () => onEditDeck?.call(),
      ),
      // A change of this phone's on its way: the words wait for its answer.
      CanDealSoon() => PrimaryButton.waiting(
        label: label,
        reason: SpokenCopy.working,
      ),
      NeedPlayers() || WaitingFor() =>
        link != null && share != null
            ? PrimaryButton.locked(label: label, onLockedTap: () => share(link))
            : PrimaryButton.waiting(label: label, reason: SpokenCopy.working),
    };
  }
}

/// Everyone at the table, a row each; from [Sizes.twoUpPlayers] on, two to
/// a line, so the deck and Deal stay in view, where each half still has
/// [Sizes.playerColumn] and every name ([names]) fits its half at the
/// reading floor (names wrap between words or are set smaller, never cut,
/// never under the floor).
class _Rows extends StatelessWidget {
  const _Rows({required this.names, required this.rows, required this.spacing});

  final List<String> names;
  final List<Widget> rows;
  final double spacing;

  /// The least a name is set at in two-up rows: the reading floor, so the
  /// names stay readable and one size (past that, one row each).
  static const _least = ReadingFloor.act;

  /// The widest word of [names] in the rows' name face at [size].
  double _widestWord(BuildContext context, double size) {
    final style = PlayerRowSize.lobby
        .nameStyle(context.skin.typography)
        .copyWith(fontSize: size);
    final scaler = MediaQuery.textScalerOf(context);
    var widest = 0.0;
    for (final word in names.expand((n) => n.split(' '))) {
      final painter = TextPainter(
        text: TextSpan(text: word, style: style),
        textScaler: scaler,
        maxLines: 1,
        textDirection: TextDirection.ltr,
      )..layout();
      if (painter.width > widest) widest = painter.width;
      painter.dispose();
    }
    return widest;
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, room) {
      final half = (room.maxWidth - Space.xs) / 2;
      const size = PlayerRowSize.lobby;
      final nameRoom =
          half - Space.sm - size.token.size - size.gap - size.endPadding;
      // The size every name is set at: the role's own, or smaller where the
      // longest word needs it (a word's width is in step with the size).
      final own = size.nameStyle(context.skin.typography).fontSize!;
      final widest = _widestWord(context, own);
      final fitted = widest > nameRoom ? own * nameRoom / widest * 0.99 : own;
      if (rows.length < Sizes.twoUpPlayers ||
          half < Sizes.playerColumn ||
          fitted < _least) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: spacing,
          children: rows,
        );
      }
      return PlayerNameSize(
        size: fitted,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: spacing,
          children: [
            for (var i = 0; i < rows.length; i += 2)
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: Space.xs,
                children: [
                  Expanded(child: rows[i]),
                  Expanded(
                    child: i + 1 < rows.length
                        ? rows[i + 1]
                        : const SizedBox.shrink(),
                  ),
                ],
              ),
          ],
        ),
      );
    },
  );
}

/// A member's row; a dropped phone's whole row dimmed (its token more),
/// with no words, so it reads at a glance; a practice player's tagged
/// "Practice" (never dimmed: it has no phone to drop).
class _Row extends StatelessWidget {
  const _Row({required this.player, required this.own, required this.away});

  final LobbyPlayer player;
  final bool own;
  final bool away;

  @override
  Widget build(BuildContext context) {
    final row = PlayerRow(
      token: player.token,
      name: player.displayName,
      size: PlayerRowSize.lobby,
      own: own,
      practice: player.practice,
      away: away,
    );
    if (!away) return row;
    // A sixth of the way from present to the skin's switched-off (its token
    // more): the row reads as away, its name still at the reading contrast.
    return Opacity(opacity: 1 - (1 - context.skin.dimmed) / 6, child: row);
  }
}
