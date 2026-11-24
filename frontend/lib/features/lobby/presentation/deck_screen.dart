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

part 'deck_view.dart';
part 'deck_parts.dart';

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
    final table = ref.watch(myTableProvider.select((t) => t.value));
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
        onRetry: () => unawaited(notifier.retryChanges()),
        onUse: close,
      ),
    );
  }
}
