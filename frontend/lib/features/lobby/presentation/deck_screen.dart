import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/router/back_policy.dart';
import '../../../design_system/copy/copy.dart';
import '../../../design_system/layout/space.dart';
import '../../../design_system/models/role.dart';
import '../../../design_system/primitives/chips.dart';
import '../../../design_system/primitives/fit_line.dart';
import '../../../design_system/primitives/notice.dart';
import '../../../design_system/primitives/nudge.dart';
import '../../../design_system/primitives/panels.dart';
import '../../../design_system/primitives/primary_button.dart';
import '../../../design_system/primitives/role_card.dart';
import '../../../design_system/primitives/role_sheet_body.dart';
import '../../../design_system/primitives/screen_frame.dart';
import '../../../design_system/primitives/waiting_sign.dart';
import '../../../design_system/primitives/sheet_scaffold.dart';
import '../../../design_system/primitives/value_stepper.dart';
import '../../../design_system/primitives/world_timer.dart';
import '../../../design_system/skin/dress.dart';
import '../../../design_system/skin/ground.dart';
import '../../../design_system/skin/skin.dart';
import '../../game/presentation/table_screen.dart' show localStepsProvider;
import '../domain/lobby_state.dart';
import '../domain/role_config.dart';
import 'lobby_notifier.dart';
import 'seats_line.dart';
import 'where_am_i_provider.dart';
import '../../../design_system/primitives/dots.dart';

/// A deck chip's name on screen.
String deckChipLabel(DeckChip chip) => DeckCopy.chips[chip.index];

/// A length as the set-up page shows it: "30 s", "5 min", "2:30 min"; 0 is
/// "No clock" for the talk and the vote, "Off" for the rest.
String lengthText(int seconds, [Length? length]) => switch (seconds) {
  0 => length?.zeroIsNoClock ?? false ? DeckCopy.noClock : DeckCopy.off,
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

/// What a length is, in a few words under its name; the talk and the vote
/// say it themselves.
String? lengthCaption(Length length) => switch (length) {
  Length.look => DeckCopy.lookCaption,
  Length.night => DeckCopy.nightCaption,
  Length.nightMinimum => DeckCopy.nightMinimumCaption,
  Length.doppelganger => DeckCopy.doppelgangerCaption,
  Length.droppedPhone => DeckCopy.droppedPhoneCaption,
  Length.hostAway => DeckCopy.hostAwayCaption,
  Length.talk || Length.vote => null,
};

/// The fewest players a game is for (the server's `seats`).
const minSeats = 3;

/// 03 Tonight's game: the set-up page, the host's, editable before anyone
/// comes and until the deal (first-time play spec, section 3). Every change
/// is saved as it is made (shown at once, sent merged, one at a time).
///
/// - Players: how many the game is for, within the server's `seats_range`,
///   or "Any" (an open table, dealt to whoever is there; offered only with an
///   automatic deck). At a number, who is here of it ("3 of 8").
/// - The deck, face up, every role: the chips make it automatic (built by
///   the server for the number); a tap on a card puts one in (up to the
///   role's most; Masons in pairs), its minus takes one out, a hold reads
///   it (03b). The first card changed makes the deck the host's own, for the
///   number (an open table takes the players here, at least 3). At a number,
///   the cards picked over the cards needed, the slots drawn as the players
///   and the centre.
/// - Every length the server has, each its own value with its unit, moved by
///   a stepper within the range the server takes now; the Doppelganger's only
///   while the deck holds one.
/// - "Done" returns to 02, always live; so does Back. With a deck that does
///   not fit the first one stays and nudges the count, the second leaves (02's
///   one button then says what to add or remove).
///
/// A restart lands on 02: opening 03 is a step of this phone's only
/// ([localStepsProvider]); what was set is the server's.
class DeckScreen extends ConsumerStatefulWidget {
  const DeckScreen({super.key});

  @override
  ConsumerState<DeckScreen> createState() => _DeckScreenState();
}

class _DeckScreenState extends ConsumerState<DeckScreen> {
  final _view = GlobalKey<DeckViewState>();

  @override
  Widget build(BuildContext context) {
    final table = ref.watch(myTableProvider).value;
    final read = table == null
        ? null
        : ref.watch(lobbyProvider(table.lobbyCode));
    final lobby = read?.value;
    void close() => ref.read(localStepsProvider.notifier).closeDeck();
    // Back returns to 02, as "Done" does (also while the lobby is read).
    if (lobby == null) {
      // Read until it answers; "One moment" while it cannot be.
      return BackHandler(
        onBack: close,
        child: DressScope(
          dress: DeckView.defaultDress,
          child: ScreenFrame(
            ground: GroundKind.night,
            body: Align(
              alignment: Alignment.topCenter,
              child: Waiting(
                failing: read?.hasError ?? false,
                onRetry: table == null
                    ? () => ref.invalidate(myTableProvider)
                    : () => ref.invalidate(lobbyProvider(table.lobbyCode)),
                centred: true,
              ),
            ),
          ),
        ),
      );
    }
    final notifier = ref.read(lobbyProvider(lobby.code).notifier);
    // Back leaves as "Done" does: with the wrong number of cards it shows the
    // count instead (never a silent exit to a table that cannot start).
    return BackHandler(
      onBack: () {
        final view = _view.currentState;
        view == null ? close() : view.leave();
      },
      child: DeckView(
        key: _view,
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
        onPracticeSwitch: () => unawaited(notifier.togglePractice()),
        onPractice: (count) => unawaited(notifier.setPracticeCount(count)),
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
  Widget build(BuildContext context) {
    final type = context.skin.typography;
    final table = lobby.table;
    final seats = table.seats;
    final picked = lobby.pickedCards;
    final need = lobby.cardsNeeded;
    return DressScope(
      dress: widget.dress ?? DeckView.defaultDress,
      child: ScreenFrame(
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
              onHold: (role) => unawaited(showRoleSheet(context, role)),
            ),
            _Lengths(lobby: lobby, onLength: widget.onLength),
          ],
        ),
        actions: [
          if (lobby.notSent)
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
      ),
    );
  }
}

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
String deckFixWords(int off) => off > 0
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
          PrimaryButton.quiet(
            label: RoleSheetCopy.close,
            onPressed: () => Navigator.of(sheet).pop(),
            size: ButtonSize.compact,
          ),
        ],
        child: RoleSheetBody(role),
      ),
    );
