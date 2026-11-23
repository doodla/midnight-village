part of 'at_table_screen.dart';

// The pieces 02 is built from: the card that invites friends in, the set-up panel and
// the strip of the deck. Part of at_table_screen.dart.

/// The table's paper, two blocks: the QR code of the table's link with
/// "Scan to join" on it (its label, nothing else's), and the code to type
/// with its own label ("Code", 01's word) and Share. Nearly empty ([compact]
/// false): the QR code large and centred over the code. Past that, as short as
/// it can be: the QR code at its scannable least beside the code, or over it
/// where the code would have too little room (a narrow phone). [headline]:
/// "Scan to join" is the screen's headline (the host's). Without a link (no
/// web address known): the code alone.
class _JoinCard extends StatelessWidget {
  const _JoinCard({
    required this.code,
    required this.headline,
    required this.compact,
    this.link,
    this.onShare,
  });

  final String code;
  final bool headline;
  final bool compact;
  final Uri? link;
  final ValueChanged<Uri>? onShare;

  @override
  Widget build(BuildContext context) {
    final link = this.link;
    final share = onShare;
    return PaperCard(
      pinned: true,
      id: #join,
      lift: PaperLift.slab,
      padding: const EdgeInsets.symmetric(
        horizontal: Space.md,
        vertical: Space.sm,
      ),
      child: Builder(
        builder: (context) {
          final type = context.skin.typography;
          final ink = context.ground.text;
          final shareButton = link == null || share == null
              ? null
              // The skin has no art for sharing: the platform's glyph.
              : IconAction(
                  onPressed: () => share(link),
                  label: TableCopy.share,
                  icon: Icons.ios_share,
                );
          final codeOnly = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(JoinCopy.codeHint, style: type.caption.copyWith(color: ink)),
              FitLine(
                code,
                style: type.heroCode.copyWith(color: ink),
                alignment: AlignmentDirectional.centerStart,
              ),
            ],
          );
          final codeBlock = Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(child: codeOnly),
              ?shareButton,
            ],
          );
          if (link == null) return codeBlock;
          // Wraps between words beside a small QR code, never set small.
          final scan = Semantics(
            header: headline,
            child: FitWords(
              TableCopy.scan,
              style: type.action.copyWith(color: ink),
            ),
          );
          Widget qrBlock(double side) => SizedBox(
            width: side,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              spacing: Space.xs,
              children: [
                QrPicture(
                  data: link.toString(),
                  side: side,
                  semanticLabel: TableCopy.scan,
                ),
                Semantics(
                  header: headline,
                  child: FitLine(
                    TableCopy.scan,
                    style: type.action.copyWith(color: ink),
                  ),
                ),
              ],
            ),
          );
          const divider = Rule();
          return LayoutBuilder(
            builder: (context, room) {
              final beside =
                  room.maxWidth - Sizes.qrScannable - Space.md >=
                  MediaQuery.textScalerOf(context).scale(Sizes.joinCodeBeside);
              if (compact && beside) {
                // Short: "Scan to join" at the QR code's edge, beside it; a
                // hairline, then the code block.
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: Space.md,
                  children: [
                    QrPicture(
                      data: link.toString(),
                      side: Sizes.qrScannable,
                      semanticLabel: TableCopy.scan,
                    ),
                    Expanded(
                      child: SizedBox(
                        height: Sizes.qrScannable,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          // "Scan to join" has the column's whole width (beside
                          // Share it left one word alone on a second line);
                          // Share ends the hairline under it, and the code has
                          // the width below.
                          children: [
                            scan,
                            Row(
                              spacing: Space.xs,
                              children: [
                                Expanded(child: divider),
                                ?shareButton,
                              ],
                            ),
                            codeOnly,
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              }
              final side = compact
                  ? Sizes.qrScannable
                  : math.max(
                      Sizes.qrScannable,
                      math.min(room.maxWidth, Sizes.qrLargest),
                    );
              return Column(
                spacing: Space.md,
                children: [qrBlock(side), divider, codeBlock],
              );
            },
          );
        },
      ),
    );
  }
}

/// The game as set up, the same for everyone at the table: the chip (an
/// automatic deck) and the talk's length, then every role in the deck face
/// up with its count, in [deckOrder] (a tap or a hold reads it, 03b). The
/// host's opens 03 ("Edit") unless the deck is wrong, when the main button
/// is the way in.
class _SetupPanel extends StatelessWidget {
  const _SetupPanel({required this.lobby, required this.host, this.onEdit});

  final LobbyState lobby;
  final bool host;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final type = context.skin.typography;
    final ink = context.ground.text;
    final chip = lobby.table.autoDeck ? lobby.table.deckChip : null;
    final talk = lobby.secondsOf(Length.talk);
    final cards = lobby.tableCards;
    // One way in: while the button says what to fix, the button is it.
    final edit = host && DealState.of(lobby) is! DeckDoesNotFit ? onEdit : null;
    void read(RoleId role) => unawaited(showRoleSheet(context, role));
    return OutlinePanel(
      onTap: edit,
      semanticLabel: edit == null ? null : TableCopy.editDeck,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: Space.smPlus,
        children: [
          Row(
            spacing: Space.sm,
            children: [
              if (chip != null)
                PresetChip(
                  label: deckChipLabel(chip),
                  selected: true,
                  onTap: null,
                ),
              // The talk's length: the room left, wrapping between words.
              Expanded(
                child: talk == null
                    ? const SizedBox.shrink()
                    : FitWords(
                        '${DeckCopy.talk} ${lengthText(talk, Length.talk)}',
                        style: type.action.copyWith(color: ink),
                      ),
              ),
              if (edit != null) const ScrapLabel(TableCopy.editDeck),
            ],
          ),
          if (cards.isNotEmpty) _DeckStrip(cards: cards, onRead: read),
        ],
      ),
    );
  }
}

/// The deck's cards face up as thumbnails, in balanced lines: one line
/// while the cards fit it at [Sizes.thumbLeast] of their size (they shrink to
/// share it), else as few lines as fit, the cards shared evenly, so no card
/// sits alone on a line of its own.
class _DeckStrip extends StatelessWidget {
  const _DeckStrip({required this.cards, required this.onRead});

  final Map<RoleId, int> cards;
  final ValueChanged<RoleId> onRead;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, room) {
      const gap = Space.sm;
      final least = RoleCardSize.thumbSmall.thumbnail!.width * Sizes.thumbLeast;
      final entries = cards.entries.toList();
      final fit = math.max(1, ((room.maxWidth + gap) / (least + gap)).floor());
      final lines = (entries.length / fit).ceil();
      final perLine = (entries.length / lines).ceil();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: gap,
        children: [
          for (var i = 0; i < entries.length; i += perLine)
            Row(
              spacing: gap,
              children: [
                for (final (k, MapEntry(key: role, value: count))
                    in entries
                        .sublist(i, math.min(i + perLine, entries.length))
                        .indexed)
                  Flexible(
                    // Dressed up the cards are a fan (paint only: the tap
                    // targets are the row's cells).
                    child: Fanned(
                      gap: gap,
                      index: k,
                      count: math.min(perLine, entries.length - i),
                      child: RoleCard(
                        role: role,
                        size: RoleCardSize.thumbSmall,
                        count: count,
                        onTap: () => onRead(role),
                        onLongPress: () => onRead(role),
                      ),
                    ),
                  ),
              ],
            ),
        ],
      );
    },
  );
}
