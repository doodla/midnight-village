part of 'deck_screen.dart';

// 03's view (`DeckView`): the set-up page as drawn, with no providers.
// Part of deck_screen.dart.

/// The deck as the server's names to counts; [seats] the number a deck
/// started at an open table is for.
typedef DeckChanged = void Function(Map<String, int> roles, {int? seats});

/// 03 drawn from the lobby (the component sheet and the gallery draw it
/// too).
class DeckView extends StatefulWidget {
  const DeckView({
    super.key,
    required this.lobby,
    required this.onSeats,
    required this.onChip,
    required this.onDeck,
    required this.onLength,
    required this.onUse,
    this.onPracticeSwitch,
    this.onPractice,
    this.onRetry,
    this.dress,
  });

  /// How the screen is dressed (null: as the live screen, [defaultDress]).
  final Dress? dress;

  /// The dress the live screen has: the host steps from the table (paper) to
  /// here, so it is paper too (the owner, 23 November 2026: "some are paper,
  /// some are not").
  static const defaultDress = Dress.paper;

  final LobbyState lobby;
  final ValueChanged<int?> onSeats;
  final ValueChanged<DeckChip> onChip;
  final DeckChanged onDeck;
  final void Function(Length length, int seconds) onLength;
  final VoidCallback onUse;

  /// A hold on "Players": practice players on or off for this table (the
  /// hidden switch; nothing on screen offers it).
  final VoidCallback? onPracticeSwitch;

  /// How many practice players sit at the table.
  final ValueChanged<int>? onPractice;
  final VoidCallback? onRetry;

  @override
  State<DeckView> createState() => DeckViewState();
}

/// 03's state: the count's place and nudge, for the leave that shows it.
class DeckViewState extends State<DeckView> {
  final _count = GlobalKey();
  final _nudge = GlobalKey<NudgeState>();

  /// The wrong count the host has been shown (by "Done" or Back): leaving
  /// with that same count again goes. Null while the count is right.
  int? _shownAt;

  @override
  void didUpdateWidget(DeckView oldWidget) {
    super.didUpdateWidget(oldWidget);
    if ((lobby.deckOff ?? 0) == 0) _shownAt = null;
  }

  LobbyState get lobby => widget.lobby;
  DeckChanged get onDeck => widget.onDeck;

  /// "Done", and Back: with the right number of cards it leaves. With the
  /// wrong number the first one stays, brings the count into view and nudges
  /// it (the count says what to add or remove); the second leaves, so the
  /// host is never trapped (the table's code, to let friends in, is on 02,
  /// and 02's button is the way back here).
  void leave() {
    final off = lobby.deckOff;
    if (off == null || off == 0 || _shownAt == off) {
      widget.onUse();
      return;
    }
    _shownAt = off;
    final at = _count.currentContext;
    if (at != null) {
      unawaited(
        Scrollable.ensureVisible(
          at,
          alignment: 0.2,
          duration: Motion.within(context, Motion.quick),
          curve: Motion.curve,
        ),
      );
    }
    _nudge.currentState?.nudge();
  }

  /// Who sits at the table as this phone shows it (practice changes on
  /// their way included).
  int get _present => lobby.seatedCount;

  /// The number of players the table may be set to now (the server's;
  /// before a server that sends none: who is here, at least 3, to 10).
  (int, int) get _seatsRange => switch (lobby.seatsRange) {
    [final least, final most] => (least, most),
    _ => (math.max(minSeats, _present), 10),
  };

  /// A card in or out: the deck as it now stands, sent whole.
  void _change(RoleId role, int by) {
    final deck = {...lobby.tableCards};
    final next = (deck[role] ?? 0) + by;
    if (next < 0 || next > RoleConfig.maxCount(role)) return;
    deck[role] = next;
    onDeck(
      {
        for (final role in deckOrder)
          if ((deck[role] ?? 0) case final count when count > 0)
            role.displayName: count,
      },
      // A deck of one's own is for a number: an open table takes who is here.
      seats: lobby.table.seats == null ? _seatsRange.$1 : null,
    );
  }

  @override
  Widget build(BuildContext context) => DressScope(
    dress: widget.dress ?? DeckView.defaultDress,
    // Everything the page reads or opens (the type, a card's sheet) is read
    // from a context UNDER the dress: this State's own is above it.
    child: Builder(builder: _page),
  );

  Widget _page(BuildContext context) {
    final type = context.skin.typography;
    final table = lobby.table;
    final seats = table.seats;
    final picked = lobby.pickedCards;
    final need = lobby.cardsNeeded;
    return ScreenFrame(
      ground: GroundKind.night,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: Space.lg,
        children: [
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Semantics(
              header: true,
              child: FitLine(DeckCopy.headline, style: type.headline),
            ),
          ),
          _Players(
            seats: seats,
            present: _present,
            range: _seatsRange,
            // "Any" never quietly drops a deck of the host's own.
            open: table.autoDeck,
            onSeats: widget.onSeats,
            practice: lobby.practiceOn
                ? (count: lobby.practiceCount, most: lobby.practiceLimit)
                : null,
            onPracticeSwitch: widget.onPracticeSwitch,
            onPractice: widget.onPractice,
          ),
          _Chips(
            labels: DeckCopy.chips,
            selected: table.autoDeck ? table.deckChip?.index : null,
            onTap: (i) => widget.onChip(DeckChip.values[i]),
          ),
          if (need != null)
            Nudge(
              key: _nudge,
              child: DeckCount(key: _count, picked: picked, need: need),
            ),
          _Grid(
            deck: lobby.tableCards,
            onAdd: (role) => _change(role, RoleConfig.stepSize(role)),
            onRemove: (role) => _change(role, -RoleConfig.stepSize(role)),
          ),
          _Lengths(lobby: lobby, onLength: widget.onLength),
        ],
      ),
      actions: [
        if (lobby.changesNotSent)
          Notice(
            message: BannerCopy.notSent,
            action: BannerCopy.tryAgain,
            onAction: widget.onRetry,
          ),
        // An action, always "Done": a host who only changed a timer leaves
        // at once. With the wrong number of cards the first tap shows the
        // count (the page is not left to a table that cannot start by
        // accident), the second leaves.
        PrimaryButton(label: DeckCopy.done, onPressed: leave),
      ],
    );
  }
}
