import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design_system/primitives/screen_frame.dart';
import '../../../design_system/skin/ground.dart';
import '../../auth/domain/auth_state.dart';
import '../../auth/presentation/auth_notifier.dart';
import '../../game/presentation/shell/count_screen.dart' show EndWaiting;
import '../../game/presentation/shell/table_shell.dart';
import 'join_flow.dart';
import 'join_screen.dart';
import 'where_am_i_provider.dart';

/// The app's home (`/`, and `/join/<code>` from a table's link): signed in,
/// the table's shell, which shows exactly the screen `/me/table/` names
/// (01 at no table, 02 at a waiting table, the game's screens in a game),
/// so a player who comes back to a table they sit at is there without a
/// tap; signed out, 01, whose first tap makes this device's guest account.
/// While the saved account is read back (a try the server does not answer
/// is made again by itself), the night's calm wait, never 01.
///
/// - While a way in is on its way ([JoinFlow]), 01 stays (the account it
///   makes first would otherwise swap the screen mid-way).
/// - From a link ([code]): the table itself for a player at it; 01 with
///   the name and "Join" for one at no table; "You're at another table."
///   with "Go there" for one seated elsewhere (never a second seat).
class HomeGate extends ConsumerWidget {
  const HomeGate({super.key, this.code});

  final String? code;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final busy = ref.watch(joinFlowProvider.select((f) => f.busy != null));
    final link = code;
    if (busy) return JoinScreen(code: link);
    return switch (auth) {
      // The saved account is being read back: the night, calm, and "One
      // moment" while a try got no answer (it is made again by itself).
      // Never 01, whose Join would make a second account and lose a seat.
      AuthInitial(:final unanswered) => EndWaiting(
        ground: GroundKind.night,
        failing: unanswered,
      ),
      AuthLoading() => const ScreenFrame(
        ground: GroundKind.night,
        body: SizedBox.shrink(),
      ),
      AuthAuthenticated() when link != null => switch (ref.watch(
        myTableProvider,
      )) {
        AsyncValue(value: final table?) when table.lobbyCode == link =>
          const TableShell(),
        // Seated elsewhere: say so; never a silent second seat.
        AsyncValue(value: final _?) => JoinScreen(code: link, elsewhere: true),
        AsyncValue(hasValue: true) => JoinScreen(code: link),
        // Not known yet: nothing to tap until it is.
        _ => const ScreenFrame(
          ground: GroundKind.night,
          body: SizedBox.shrink(),
        ),
      },
      AuthAuthenticated() => const TableShell(),
      AuthUnauthenticated() || AuthError() => JoinScreen(code: link),
    };
  }
}
