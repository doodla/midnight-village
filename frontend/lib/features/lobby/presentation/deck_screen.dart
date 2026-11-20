import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design_system/copy/copy.dart';
import '../../../design_system/layout/space.dart';
import '../../../design_system/models/role.dart';
import '../../../design_system/primitives/art_picture.dart';
import '../../../design_system/primitives/chips.dart';
import '../../../design_system/primitives/fit_line.dart';
import '../../../design_system/primitives/notice.dart';
import '../../../design_system/primitives/panels.dart';
import '../../../design_system/primitives/primary_button.dart';
import '../../../design_system/primitives/role_card.dart';
import '../../../design_system/primitives/role_sheet_body.dart';
import '../../../design_system/primitives/screen_frame.dart';
import '../../../design_system/primitives/secondary_button.dart';
import '../../../design_system/primitives/sheet_scaffold.dart';
import '../../../design_system/primitives/world_timer.dart';
import '../../../design_system/skin/ground.dart';
import '../../../design_system/skin/skin.dart';
import '../../../design_system/skin/skin_tilt.dart';
import '../../game/presentation/table_screen.dart' show localStepsProvider;
import '../domain/lobby_state.dart';
import '../domain/role_config.dart';
import 'at_table_screen.dart' show cardsLabel;
import 'lobby_notifier.dart';
import 'where_am_i_provider.dart';

/// A deck chip's name on screen.
String deckChipLabel(DeckChip chip) => DeckCopy.chips[chip.index];

/// The pace chips, in [Pace] order.
String paceLabel(Pace pace) => DeckCopy.paces[pace.index];

/// The roles in the order the deck builder shows them (S03).
const deckOrder = [
  RoleId.werewolf,
  RoleId.minion,
  RoleId.mason,
  RoleId.seer,
  RoleId.robber,
  RoleId.troublemaker,
  RoleId.drunk,
  RoleId.insomniac,
  RoleId.hunter,
  RoleId.tanner,
  RoleId.doppelganger,
  RoleId.villager,
];

/// 03 Deck, the host's, optional (first-time play spec, section 3): the
/// starter chips do the choosing.
///
/// - The chips ("Simple", "Classic", "Chaos") make the deck automatic: the
///   server builds it at the deal for whoever is at the table, so a host who
///   does nothing has a deck that fits. A tap is sent at once.
/// - "Edit" opens the role grid: a tap on a card adds one (up to the role's
///   most, then back to none; Masons in pairs), a hold opens the role sheet
///   (03b). Edited, the deck is the host's own and no chip is selected; it
///   is sent with "Use this deck", which is amber only while it holds a card
///   for every player and three more (the server refuses any other), else
///   names what is missing. A chip tapped meanwhile drops the edit.
/// - The pace chips ("Quick", "Normal", "Long") set the talk, the vote and a
///   night window to the contract's presets; none is selected while the
///   table's lengths are the server's own.
///
/// "Use this deck", or the system back, returns to 02. A restart lands on
/// 02: opening 03 is a step of this phone's only ([localStepsProvider]).
class DeckScreen extends ConsumerWidget {
  const DeckScreen({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final table = ref.watch(myTableProvider).value;
    final read = table == null
        ? null
        : ref.watch(lobbyProvider(table.lobbyCode));
    final lobby = read?.value;
    if (lobby == null) {
      // Read until it answers; "One moment" while it cannot be.
      return ScreenFrame(
        ground: GroundKind.night,
        body: const SizedBox.shrink(),
        actions: [
          if (read?.error != null) const Notice(message: BannerCopy.offline),
        ],
      );
    }
    final notifier = ref.read(lobbyProvider(lobby.code).notifier);
    void close() => ref.read(localStepsProvider.notifier).closeDeck();
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: (popped, _) {
        if (!popped) close();
      },
      child: DeckView(
        lobby: lobby,
        onChip: (chip) => unawaited(notifier.chooseChip(chip)),
        onPace: (pace) => unawaited(notifier.choosePace(pace)),
        onRetry: () => unawaited(notifier.retry()),
        onUse: (roles) {
          if (roles != null) unawaited(notifier.useCustomDeck(roles));
          close();
        },
      ),
    );
  }
}

/// 03 drawn from the lobby (the component sheet and the gallery draw it
/// too). [onUse] gets the edited deck in the server's names, or null when
/// nothing was edited.
class DeckView extends StatefulWidget {
  const DeckView({
    super.key,
    required this.lobby,
    required this.onChip,
    required this.onPace,
    required this.onUse,
    this.onRetry,
    this.editing,
  });

  final LobbyState lobby;
  final ValueChanged<DeckChip> onChip;
  final ValueChanged<Pace> onPace;
  final ValueChanged<Map<String, int>?> onUse;
  final VoidCallback? onRetry;

  /// Starts with the grid open on this deck (the gallery's state).
  final Map<RoleId, int>? editing;

  @override
  State<DeckView> createState() => _DeckViewState();
}

class _DeckViewState extends State<DeckView> {
  /// The deck being edited; null while the grid is closed.
  late Map<RoleId, int>? _draft = widget.editing ?? (_custom ? _stored : null);

  bool get _custom =>
      !widget.lobby.table.autoDeck && widget.lobby.roleConfig.isNotEmpty;

  Map<RoleId, int> get _stored => {
    for (final MapEntry(:key, :value) in widget.lobby.roleConfig.entries)
      if (RoleId.fromServer(key) case final role? when value > 0) role: value,
  };

  void _chip(DeckChip chip) {
    setState(() => _draft = null);
    widget.onChip(chip);
  }

  void _tap(RoleId role) {
    final draft = {...?_draft};
    final now = draft[role] ?? 0;
    final next = now + RoleConfig.stepSize(role);
    draft[role] = next > RoleConfig.maxCount(role) ? 0 : next;
    setState(() => _draft = draft);
  }

  @override
  Widget build(BuildContext context) {
    final type = context.skin.typography;
    final lobby = widget.lobby;
    final draft = _draft;
    final chip = draft == null && lobby.table.autoDeck
        ? lobby.table.deckChip
        : null;
    return ScreenFrame(
      ground: GroundKind.night,
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: Space.mdPlus,
        children: [
          Align(
            alignment: AlignmentDirectional.centerStart,
            child: Semantics(
              header: true,
              child: FitLine(DeckCopy.headline, style: type.headline),
            ),
          ),
          _Chips(
            labels: DeckCopy.chips,
            selected: chip?.index,
            onTap: (i) => _chip(DeckChip.values[i]),
          ),
          if (draft == null) ...[
            // The chip's cards face up, when the server sends them; a tap
            // or "Edit" starts editing from them.
            if (lobby.chipCards case final cards? when cards.isNotEmpty) ...[
              _Grid(
                deck: cards,
                onTap: (_) => setState(() => _draft = {...cards}),
                onHold: (role) => unawaited(showRoleSheet(context, role)),
              ),
              Align(
                alignment: AlignmentDirectional.centerStart,
                child: SecondaryButton(
                  label: TableCopy.editDeck,
                  size: ButtonSize.compact,
                  onPressed: () => setState(() => _draft = {...cards}),
                ),
              ),
            ] else
              // FALLBACK until `deck_preview` lands: the deck face down;
              // "Edit" starts from the last custom deck, or none.
              _EditPanel(onEdit: () => setState(() => _draft = _stored)),
          ] else
            _Grid(
              deck: draft,
              onTap: _tap,
              onHold: (role) => unawaited(showRoleSheet(context, role)),
            ),
          _Chips(
            labels: DeckCopy.paces,
            selected: lobby.table.pace?.index,
            onTap: (i) => widget.onPace(Pace.values[i]),
          ),
          _PaceTiles(
            settings: lobby.table,
            copy: (draft ?? (_custom ? _stored : const {})).containsKey(
              RoleId.doppelganger,
            ),
          ),
        ],
      ),
      actions: [
        if (lobby.notSent)
          Notice(
            message: BannerCopy.notSent,
            action: BannerCopy.tryAgain,
            onAction: widget.onRetry,
          ),
        _useButton(draft),
      ],
    );
  }

  Widget _useButton(Map<RoleId, int>? draft) {
    if (draft == null) {
      return PrimaryButton(
        label: DeckCopy.useDeck,
        onPressed: () => widget.onUse(null),
      );
    }
    final cards = draft.values.fold(0, (a, b) => a + b);
    // The cards the server's deal needs (`deal.need`); FALLBACK until the
    // server's `deal` lands: players + 3, read from the lobby body. Delete
    // the fallback (and `DealState.centerCards`) then.
    final wanted =
        widget.lobby.serverDeal?.need ??
        widget.lobby.players.length + DealState.centerCards;
    if (cards != wanted) {
      return PrimaryButton(
        label: cardsLabel((wanted - cards).abs(), add: cards < wanted),
        onPressed: null,
      );
    }
    return PrimaryButton(
      label: DeckCopy.useDeck,
      onPressed: () => widget.onUse({
        for (final MapEntry(key: role, value: count) in draft.entries)
          if (count > 0) role.displayName: count,
      }),
    );
  }
}

/// The grid closed (the deck is a chip's): the deck face down, and "Edit".
class _EditPanel extends StatelessWidget {
  const _EditPanel({required this.onEdit});

  final VoidCallback onEdit;

  /// The face-down cards drawn, fanned.
  static const _fan = 4;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final size = RoleCardSize.mini.thumbnail!;
    return OutlinePanel(
      onTap: onEdit,
      semanticLabel: TableCopy.editDeck,
      child: Row(
        children: [
          SizedBox(
            width: size.width * (1 + (_fan - 1) / 2) + Space.sm,
            height: size.height + Space.sm,
            child: Stack(
              children: [
                for (var i = 0; i < _fan; i++)
                  Positioned(
                    left: i * size.width / 2,
                    top: Space.xs,
                    child: Transform.rotate(
                      angle: skin.tilt.angle(Tilt.scatter(i)),
                      child: Container(
                        width: size.width,
                        height: size.height,
                        foregroundDecoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(
                            skin.shape.radiusSmall,
                          ),
                          border: Border.all(
                            color: context.ground.text,
                            width: skin.shape.ring,
                          ),
                        ),
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(
                            skin.shape.radiusSmall,
                          ),
                          child: ArtPicture(skin.art.cardBack),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
          const Spacer(),
          Text(
            TableCopy.editDeck,
            style: skin.typography.action.copyWith(color: context.ground.text),
          ),
        ],
      ),
    );
  }
}

/// The table's lengths under the pace chips, once its settings carry them
/// (a pace chosen): "Talk", "Vote", "Night", and "Copy" while the deck
/// holds the Doppelganger and its window is set.
class _PaceTiles extends StatelessWidget {
  const _PaceTiles({required this.settings, required this.copy});

  final TableSettings settings;
  final bool copy;

  @override
  Widget build(BuildContext context) {
    final tiles = [
      (DeckCopy.talk, settings.talkSeconds),
      (DeckCopy.vote, settings.voteSeconds),
      (DeckCopy.night, settings.nightSeconds),
      if (copy) (DeckCopy.copy, settings.copySeconds),
    ].where((t) => t.$2 != null).toList();
    if (tiles.isEmpty) return const SizedBox.shrink();
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: Space.sm,
        children: [
          for (final (label, seconds) in tiles)
            Expanded(
              child: PaceTile(label: label, value: WorldTimer.format(seconds!)),
            ),
        ],
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

/// Every role, lit with its count when in [deck]: three across, or two
/// where three would set a name ("Doppelganger") under the 14 px caption
/// floor (a 320-wide phone, large text).
class _Grid extends StatelessWidget {
  const _Grid({required this.deck, required this.onTap, required this.onHold});

  final Map<RoleId, int> deck;
  final ValueChanged<RoleId> onTap;
  final ValueChanged<RoleId> onHold;

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

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, room) {
      final name = _widestName(context);
      final columns = room.maxWidth >= 3 * name + 2 * _gap ? 3 : 2;
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
              onTap: () => onTap(role),
              onLongPress: () => onHold(role),
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
          PrimaryButton.quiet(
            label: RoleSheetCopy.close,
            onPressed: () => Navigator.of(sheet).pop(),
            size: ButtonSize.compact,
          ),
        ],
        child: RoleSheetBody(role),
      ),
    );
