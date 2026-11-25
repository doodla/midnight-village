part of 'deck_screen.dart';

// The pieces 03 is built from: the players stepper, the count (`DeckCount`, with
// `deckFixWords`, which 02's button uses too), the lengths, the chips and the grid of
// cards; and `showRoleSheet`, 03b: a card's details, which 02 opens too.
// Part of deck_screen.dart.

/// How many players the game is for: a stepper over the server's range
/// ([range]: never below who is here, never above what the table holds);
/// below 3, "Any" (an open table), while [open] (the deck is automatic) and
/// no more than 3 are here; at a number, who is here of it. A hold on the
/// name switches practice players on or off ([onPracticeSwitch]); while on
/// ([practice]), a "Practice" stepper under it sets how many sit at the
/// table, 0 to the most the server says may.
class _Players extends StatelessWidget {
  const _Players({
    required this.seats,
    required this.present,
    required this.range,
    required this.open,
    required this.onSeats,
    this.practice,
    this.onPracticeSwitch,
    this.onPractice,
  });

  final int? seats;
  final int present;
  final (int, int) range;
  final bool open;
  final ValueChanged<int?> onSeats;
  final ({int count, int most})? practice;
  final VoidCallback? onPracticeSwitch;
  final ValueChanged<int>? onPractice;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final ground = context.ground;
    final seats = this.seats;
    final (least, most) = range;
    final practice = this.practice;
    final onPractice = this.onPractice;
    return OutlinePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: Space.sm,
        children: [
          LabelledStepper(
            label: DeckCopy.players,
            style: skin.typography.title.copyWith(color: ground.text),
            onLabelLongPress: onPracticeSwitch,
            stepper: ValueStepper(
              value: seats == null ? DeckCopy.any : '$seats',
              widest: DeckCopy.any,
              lowerLabel: SpokenCopy.lower,
              higherLabel: SpokenCopy.higher,
              onLower: switch (seats) {
                null => null,
                _ when seats > least => () => onSeats(seats - 1),
                _ when open && least <= minSeats => () => onSeats(null),
                _ => null,
              },
              onHigher: switch (seats) {
                null => () => onSeats(least),
                _ when seats < most => () => onSeats(seats + 1),
                _ => null,
              },
            ),
          ),
          if (seats != null) SeatsLine(present: present, seats: seats),
          if (practice != null)
            LabelledStepper(
              label: DeckCopy.practice,
              style: skin.typography.action.copyWith(color: ground.text),
              stepper: ValueStepper(
                value: '${practice.count}',
                widest: '${math.max(practice.most, 10)}',
                lowerLabel: SpokenCopy.lower,
                higherLabel: SpokenCopy.higher,
                small: true,
                onLower: practice.count > 0 && onPractice != null
                    ? () => onPractice(practice.count - 1)
                    : null,
                onHigher: practice.count < practice.most && onPractice != null
                    ? () => onPractice(practice.count + 1)
                    : null,
              ),
            ),
        ],
      ),
    );
  }
}

/// What to do about [off] cards over (above 0) or under (below 0) what the
/// deal needs, in the player's words ("Remove 2 cards", "Add 1 card"): the
/// count's instruction on 03 and 02's one button.
Words deckFixWords(int off) => off > 0
    ? (off == 1 ? DeckCopy.removeCard : DeckCopy.removeCards.fill({'n': off}))
    : (off == -1 ? DeckCopy.addCard : DeckCopy.addCards.fill({'n': -off}));

/// The cards picked of the cards the deal needs, said in the player's words
/// on one line in one face ("14 of 12 · Remove 2 cards", "10 of 11 · Add 1
/// card", "11 of 11"), and a pip for each: one per card needed, filled for a
/// card picked, empty for one still to add, and the cards over the need in the
/// danger ink, so a deck too big reads at a glance. No gap between them: the
/// count is what is said, the pips only show it.
class DeckCount extends StatelessWidget {
  const DeckCount({super.key, required this.picked, required this.need});

  final int picked;
  final int need;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final ground = context.ground;
    final slots = math.max(picked, need);
    const size = Sizes.deckSlot;
    Widget slot(int i) {
      final filled = i < picked;
      final ink = i >= need ? ground.dangerText : ground.text;
      return SlotMark(
        filled: filled,
        size: size,
        ink: ink,
        outline: ground.outline,
      );
    }

    final off = picked - need;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: Space.xs,
      children: [
        Semantics(
          liveRegion: true,
          child: FitLine(
            off == 0
                ? DeckCopy.count.fill({'picked': picked, 'need': need})
                : DeckCopy.countFix.fill({
                    'picked': picked,
                    'need': need,
                    'fix': deckFixWords(off),
                  }),
            alignment: AlignmentDirectional.centerStart,
            style: skin.typography.title.copyWith(
              color: off == 0 ? ground.text : ground.dangerText,
            ),
          ),
        ),
        ExcludeSemantics(
          child: Wrap(
            spacing: Space.xxs,
            runSpacing: Space.xxs,
            children: [for (var i = 0; i < slots; i++) slot(i)],
          ),
        ),
      ],
    );
  }
}

/// Every length the server has, each a row: its name and a stepper over its
/// value, within the range the server takes now, in [Length] order; the
/// Doppelganger's only while the deck holds one. The rows stay even: every
/// stepper as wide as the widest value any row can show (each row's own
/// range, not the most any length could be), so the glyphs line up, and
/// every name beside its stepper, or every name over it. A server that
/// sends no lengths: none.
class _Lengths extends StatelessWidget {
  const _Lengths({required this.lobby, required this.onLength});

  final LobbyState lobby;
  final void Function(Length length, int seconds) onLength;

  /// The widest text a length shows anywhere in its range (by characters:
  /// the steps from [least] to [most]).
  static String _widest(Length length, int least, int most) {
    var widest = lengthText(least, length);
    for (var v = least; v < most;) {
      v = Length.up(v, most);
      final text = lengthText(v, length);
      if (text.length >= widest.length) widest = text;
    }
    return widest;
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final ground = context.ground;
    final doppelganger = lobby.tableCards.containsKey(RoleId.doppelganger);
    final shown = [
      for (final length in Length.values)
        if (length != Length.doppelganger || doppelganger)
          if (lobby.secondsOf(length) case final seconds?) (length, seconds),
    ];
    if (shown.isEmpty) return const SizedBox.shrink();
    final style = skin.typography.action;
    final scaler = MediaQuery.textScalerOf(context);
    double width(String text) {
      final painter = TextPainter(
        text: TextSpan(text: text, style: style),
        textScaler: scaler,
        maxLines: 1,
        textDirection: TextDirection.ltr,
      )..layout();
      final w = painter.width;
      painter.dispose();
      return w;
    }

    var widest = '';
    for (final (length, _) in shown) {
      final (least, most) = lobby.rangeOf(length);
      final own = _widest(length, least, most);
      if (width(own) > width(widest)) widest = own;
    }
    final rows = [
      for (final (length, seconds) in shown)
        _row(length, seconds, widest, style, ground.text),
    ];
    return OutlinePanel(
      child: LayoutBuilder(
        builder: (context, room) {
          final beside = rows.every(
            (row) => row.fitsBeside(context, room.maxWidth),
          );
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: Space.sm,
            children: [
              for (final row in rows)
                LabelledStepper(
                  label: row.label,
                  caption: row.caption,
                  style: row.style,
                  stepper: row.stepper,
                  beside: beside,
                ),
            ],
          );
        },
      ),
    );
  }

  LabelledStepper _row(
    Length length,
    int seconds,
    String widest,
    TextStyle type,
    Color ink,
  ) {
    final (least, most) = lobby.rangeOf(length);
    return LabelledStepper(
      label: lengthLabel(length),
      caption: lengthCaption(length),
      style: type.copyWith(color: ink),
      stepper: ValueStepper(
        value: lengthText(seconds, length),
        widest: widest,
        lowerLabel: SpokenCopy.lower,
        higherLabel: SpokenCopy.higher,
        small: true,
        onLower: seconds > least
            ? () => onLength(length, Length.down(seconds, least))
            : null,
        onHigher: seconds < most
            ? () => onLength(length, Length.up(seconds, most))
            : null,
      ),
    );
  }
}

/// A row of preset chips; [selected] lifted and outlined.
class _Chips extends StatelessWidget {
  const _Chips({required this.labels, this.selected, required this.onTap});

  final List<String> labels;
  final int? selected;
  final ValueChanged<int> onTap;

  @override
  Widget build(BuildContext context) => Wrap(
    spacing: Space.sm,
    runSpacing: Space.sm,
    children: [
      for (final (i, label) in labels.indexed)
        PresetChip(
          label: label,
          selected: i == selected,
          onTap: () => onTap(i),
        ),
    ],
  );
}

/// The art 03 draws on a phone like [context]'s, as it decodes it: every
/// role's portrait at its grid card's box. Decoded ahead while 02 shows
/// (`ArtAhead`), so 03 opens on pictures already decoded.
List<ImageProvider> deckArt(BuildContext context) {
  final width = MediaQuery.sizeOf(
    context,
  ).width.clamp(0, ScreenFrame.maxWidth).toDouble();
  final box = _Grid._portraitBox(context, width - 2 * Space.gutter);
  final ratio = MediaQuery.devicePixelRatioOf(context);
  return [
    for (final role in deckOrder) context.roleArt(role).decodedFor(box, ratio),
  ];
}

/// Every role, face up, lit with its count when in [deck]: a tap puts one
/// in, a lit card's minus takes one out, a hold reads it. Three across, or
/// two where three would set a name ("Doppelganger") under the 14 px
/// caption floor (a 320-wide phone, large text).
class _Grid extends StatelessWidget {
  const _Grid({
    required this.deck,
    required this.onAdd,
    required this.onRemove,
  });

  final Map<RoleId, int> deck;
  final ValueChanged<RoleId> onAdd;
  final ValueChanged<RoleId> onRemove;

  static const _gap = Space.md;

  /// The widest role name as the grid sets it.
  static double _widestName(BuildContext context) {
    final style = context.skin.typography.badge;
    final scaler = MediaQuery.textScalerOf(context);
    var widest = 0.0;
    for (final role in deckOrder) {
      final painter = TextPainter(
        text: TextSpan(text: role.displayName, style: style),
        textScaler: scaler,
        maxLines: 1,
        textDirection: TextDirection.ltr,
      )..layout();
      if (painter.width > widest) widest = painter.width;
      painter.dispose();
    }
    return widest;
  }

  /// How many cards across, in a grid [room] wide.
  static int _columns(BuildContext context, double room) =>
      room >= 3 * _widestName(context) + 2 * _gap ? 3 : 2;

  /// The box each card's portrait is drawn in, in a grid [room] wide.
  static Size _portraitBox(BuildContext context, double room) {
    final columns = _columns(context, room);
    return RoleCard.gridPortraitBox((room - (columns - 1) * _gap) / columns);
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, room) {
      final columns = _columns(context, room.maxWidth);
      return GridView.count(
        crossAxisCount: columns,
        shrinkWrap: true,
        physics: const NeverScrollableScrollPhysics(),
        mainAxisSpacing: Space.mdPlus,
        crossAxisSpacing: _gap,
        childAspectRatio: RoleCard.gridCellAspect,
        children: [
          for (final role in deckOrder)
            RoleCard(
              role: role,
              count: deck[role] ?? 0,
              lit: (deck[role] ?? 0) > 0,
              onTap: () => onAdd(role),
              // From this widget's own context: under the page's frame, so the
              // sheet is lit and dressed as the page is.
              onLongPress: () => unawaited(showRoleSheet(context, role)),
              onRemove: () => onRemove(role),
              removeLabel: SpokenCopy.takeOut.fill({'role': role.displayName}),
            ),
        ],
      );
    },
  );
}

/// 03b: the role text over the screen it was held on, and "Close" (never
/// beside an action that changes the deck).
Future<void> showRoleSheet(BuildContext context, RoleId role) =>
    showSkinSheet<void>(
      context,
      builder: (sheet) => SheetScaffold(
        actions: [
          const Spacer(),
          // Quiet: the screen under the sheet keeps the one amber.
          SheetClose(
            label: RoleSheetCopy.close,
            onPressed: () => Navigator.of(sheet).pop(),
          ),
        ],
        child: RoleSheetBody(role),
      ),
    );
