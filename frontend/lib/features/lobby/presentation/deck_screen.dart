import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design_system/copy/copy.dart';
import '../../../design_system/layout/space.dart';
import '../../../design_system/models/role.dart';
import '../../../design_system/primitives/chips.dart';
import '../../../design_system/primitives/fit_line.dart';
import '../../../design_system/primitives/notice.dart';
import '../../../design_system/primitives/panels.dart';
import '../../../design_system/primitives/primary_button.dart';
import '../../../design_system/primitives/role_card.dart';
import '../../../design_system/primitives/role_sheet_body.dart';
import '../../../design_system/primitives/screen_frame.dart';
import '../../../design_system/primitives/sheet_scaffold.dart';
import '../../../design_system/primitives/value_stepper.dart';
import '../../../design_system/primitives/world_timer.dart';
import '../../../design_system/skin/ground.dart';
import '../../../design_system/skin/skin.dart';
import '../../game/presentation/table_screen.dart' show localStepsProvider;
import '../domain/lobby_state.dart';
import '../domain/role_config.dart';
import 'lobby_notifier.dart';
import 'seats_line.dart';
import 'where_am_i_provider.dart';

/// A deck chip's name on screen.
String deckChipLabel(DeckChip chip) => DeckCopy.chips[chip.index];

/// A length as the set-up page shows it: "30 s", "5 min", "2:30 min", or
/// "Off" for 0.
String lengthText(int seconds) => switch (seconds) {
  0 => DeckCopy.off,
  < 60 => CommonCopy.seconds.fill({'n': seconds}),
  _ when seconds % 60 == 0 => DeckCopy.minutes.fill({'n': seconds ~/ 60}),
  _ => DeckCopy.minutes.fill({'n': WorldTimer.format(seconds)}),
};

/// A length's name on the set-up page (the Doppelganger's window is named by
/// the role).
String lengthLabel(Length length) => switch (length) {
  Length.look => DeckCopy.look,
  Length.night => DeckCopy.night,
  Length.nightMinimum => DeckCopy.nightMinimum,
  Length.doppelganger => RoleId.doppelganger.displayName,
  Length.talk => DeckCopy.talk,
  Length.vote => DeckCopy.vote,
  Length.droppedPhone => DeckCopy.droppedPhone,
  Length.hostAway => DeckCopy.hostAway,
};

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

/// The fewest and most players a game is for (the server's `seats`).
const minSeats = 3;
const maxSeats = 10;

/// 03 Tonight's game: the set-up page, the host's, editable before anyone
/// comes and until the deal (first-time play spec, section 3). Every change
/// is saved as it is made (shown at once, sent merged, one at a time).
///
/// - Players: how many the game is for (3 to 10), or "Any" (an open table,
///   dealt to whoever is there). At a number, who is here of it ("3 of 8").
/// - The deck, face up, every role: the chips make it automatic (built by
///   the server for the number); a tap on a card puts one in (up to the
///   role's most; Masons in pairs), its minus takes one out, a hold reads
///   it (03b). The first card changed makes the deck the host's own, for the
///   number (an open table takes the players here, at least 3). At a number,
///   the cards picked over the cards needed, the slots drawn as the players
///   and the centre.
/// - Every length the server has, each its own value with its unit, moved by
///   a stepper within the range the server takes now. The Doppelganger's is
///   quiet while the deck holds no Doppelganger.
/// - "Use this deck" returns to 02: one label, live while the deck holds
///   the cards the deal needs.
///
/// A restart lands on 02: opening 03 is a step of this phone's only
/// ([localStepsProvider]); what was set is the server's.
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
        onSeats: (seats) => unawaited(notifier.setSeats(seats)),
        onChip: (chip) => unawaited(notifier.chooseChip(chip)),
        onDeck: (roles, {seats}) => unawaited(
          lobby.table.autoDeck
              ? notifier.startCustomDeck(roles, seats: seats)
              : notifier.setRoles(roles),
        ),
        onLength: (length, seconds) =>
            unawaited(notifier.setLength(length.key, seconds)),
        onRetry: () => unawaited(notifier.retry()),
        onUse: close,
      ),
    );
  }
}

/// The deck as the server's names to counts; [seats] the number a deck
/// started at an open table is for.
typedef DeckChanged = void Function(Map<String, int> roles, {int? seats});

/// 03 drawn from the lobby (the component sheet and the gallery draw it
/// too).
class DeckView extends StatelessWidget {
  const DeckView({
    super.key,
    required this.lobby,
    required this.onSeats,
    required this.onChip,
    required this.onDeck,
    required this.onLength,
    required this.onUse,
    this.onRetry,
  });

  final LobbyState lobby;
  final ValueChanged<int?> onSeats;
  final ValueChanged<DeckChip> onChip;
  final DeckChanged onDeck;
  final void Function(Length length, int seconds) onLength;
  final VoidCallback onUse;
  final VoidCallback? onRetry;

  int get _present => lobby.players.length;

  /// A card in or out: the deck as it now stands, sent whole.
  void _change(RoleId role, int by) {
    final deck = {...lobby.tableCards};
    final next = (deck[role] ?? 0) + by;
    if (next < 0 || next > RoleConfig.maxCount(role)) return;
    deck[role] = next;
    onDeck(
      {
        for (final MapEntry(key: role, value: count) in deck.entries)
          if (count > 0) role.displayName: count,
      },
      // A deck of one's own is for a number: an open table takes who is here.
      seats: lobby.table.seats == null
          ? math.min(maxSeats, math.max(minSeats, _present))
          : null,
    );
  }

  @override
  Widget build(BuildContext context) {
    final type = context.skin.typography;
    final table = lobby.table;
    final seats = table.seats;
    final picked = lobby.pickedCards;
    final need = lobby.deal?.need;
    final fits = table.autoDeck || need == null || picked == need;
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
          _Players(seats: seats, present: _present, onSeats: onSeats),
          _Chips(
            labels: DeckCopy.chips,
            selected: table.autoDeck ? table.deckChip?.index : null,
            onTap: (i) => onChip(DeckChip.values[i]),
          ),
          if (seats != null && need != null)
            DeckCount(picked: picked, need: need, seats: seats),
          _Grid(
            deck: lobby.tableCards,
            onAdd: (role) => _change(role, RoleConfig.stepSize(role)),
            onRemove: (role) => _change(role, -RoleConfig.stepSize(role)),
            onHold: (role) => unawaited(showRoleSheet(context, role)),
          ),
          _Lengths(lobby: lobby, onLength: onLength),
        ],
      ),
      actions: [
        if (lobby.notSent)
          Notice(
            message: BannerCopy.notSent,
            action: BannerCopy.tryAgain,
            onAction: onRetry,
          ),
        // One label: live while the deck holds the cards the deal needs.
        PrimaryButton(label: DeckCopy.useDeck, onPressed: fits ? onUse : null),
      ],
    );
  }
}

/// How many players the game is for: a stepper from 3 to 10, below 3 "Any"
/// (an open table), never below the players already here; at a number, who
/// is here of it.
class _Players extends StatelessWidget {
  const _Players({
    required this.seats,
    required this.present,
    required this.onSeats,
  });

  final int? seats;
  final int present;
  final ValueChanged<int?> onSeats;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final ground = context.ground;
    final seats = this.seats;
    final least = math.max(minSeats, present);
    return OutlinePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: Space.sm,
        children: [
          LabelledStepper(
            label: DeckCopy.players,
            style: skin.typography.title.copyWith(color: ground.text),
            stepper: ValueStepper(
              value: seats == null ? DeckCopy.any : '$seats',
              widest: DeckCopy.any,
              lowerLabel: DeckCopy.lower,
              higherLabel: DeckCopy.higher,
              onLower: switch (seats) {
                null => null,
                // Back to an open table only while it holds no more than
                // the smallest game.
                _ when seats <= least =>
                  present <= minSeats ? () => onSeats(null) : null,
                _ => () => onSeats(seats - 1),
              },
              onHigher: switch (seats) {
                null => () => onSeats(math.min(maxSeats, least)),
                _ when seats >= maxSeats => null,
                _ => () => onSeats(seats + 1),
              },
            ),
          ),
          if (seats != null) SeatsLine(present: present, seats: seats),
        ],
      ),
    );
  }
}

/// The cards picked over the cards the deal needs ("7 / 11"), and a slot
/// for each: as many as the players, a gap, the three in the centre, so the
/// count is tied to the number by sight. Cards past the need are drawn in
/// the danger ink, as is the count while it is not the need.
class DeckCount extends StatelessWidget {
  const DeckCount({
    super.key,
    required this.picked,
    required this.need,
    required this.seats,
  });

  final int picked;
  final int need;
  final int seats;

  static const _slot = Size(12, 16);

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final ground = context.ground;
    final slots = math.max(picked, need);
    Widget slot(int i) {
      final filled = i < picked;
      final ink = i >= need ? ground.dangerText : ground.text;
      return Container(
        width: _slot.width,
        height: _slot.height,
        decoration: BoxDecoration(
          borderRadius: BorderRadius.circular(skin.shape.radiusSmall / 2),
          color: filled ? ink : null,
          border: Border.all(
            color: filled ? ink : ground.outline,
            width: skin.shape.stroke,
          ),
        ),
      );
    }

    return Row(
      spacing: Space.md,
      children: [
        Text(
          '$picked / $need',
          style: skin.typography.heading.copyWith(
            color: picked == need ? ground.text : ground.dangerText,
          ),
        ),
        Expanded(
          child: ExcludeSemantics(
            child: Wrap(
              spacing: Space.xxs,
              runSpacing: Space.xxs,
              children: [
                for (var i = 0; i < slots; i++) ...[
                  // The centre's three after a gap.
                  if (i == seats) const SizedBox(width: Space.sm),
                  slot(i),
                ],
              ],
            ),
          ),
        ),
      ],
    );
  }
}

/// Every length the server has, each a row: its name and a stepper over its
/// value, within the range the server takes now. The Doppelganger's is
/// quiet while the deck holds none. A server that sends no lengths: none.
class _Lengths extends StatelessWidget {
  const _Lengths({required this.lobby, required this.onLength});

  final LobbyState lobby;
  final void Function(Length length, int seconds) onLength;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final ground = context.ground;
    final rows = [
      for (final length in Length.values)
        if (lobby.secondsOf(length) case final seconds?) (length, seconds),
    ];
    if (rows.isEmpty) return const SizedBox.shrink();
    final doppelganger = lobby.tableCards.containsKey(RoleId.doppelganger);
    return OutlinePanel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: Space.sm,
        children: [
          for (final (length, seconds) in rows)
            Builder(
              builder: (context) {
                final (least, most) = lobby.rangeOf(length);
                final quiet = length == Length.doppelganger && !doppelganger;
                return LabelledStepper(
                  label: lengthLabel(length),
                  style: skin.typography.action.copyWith(
                    color: quiet ? ground.quietText : ground.text,
                  ),
                  stepper: ValueStepper(
                    value: lengthText(seconds),
                    widest: DeckCopy.minutes.fill({'n': '14:30'}),
                    lowerLabel: DeckCopy.lower,
                    higherLabel: DeckCopy.higher,
                    quiet: quiet,
                    small: true,
                    onLower: seconds > least
                        ? () => onLength(length, Length.down(seconds, least))
                        : null,
                    onHigher: seconds < most
                        ? () => onLength(length, Length.up(seconds, most))
                        : null,
                  ),
                );
              },
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

/// Every role, face up, lit with its count when in [deck]: a tap puts one
/// in, a lit card's minus takes one out, a hold reads it. Three across, or
/// two where three would set a name ("Doppelganger") under the 14 px
/// caption floor (a 320-wide phone, large text).
class _Grid extends StatelessWidget {
  const _Grid({
    required this.deck,
    required this.onAdd,
    required this.onRemove,
    required this.onHold,
  });

  final Map<RoleId, int> deck;
  final ValueChanged<RoleId> onAdd;
  final ValueChanged<RoleId> onRemove;
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
              onTap: () => onAdd(role),
              onLongPress: () => onHold(role),
              onRemove: () => onRemove(role),
              removeLabel: DeckCopy.takeOut.fill({'role': role.displayName}),
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
