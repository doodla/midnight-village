import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/router/back_policy.dart';
import '../../auth/domain/auth_state.dart';
import '../../auth/presentation/auth_notifier.dart';
import '../../game/domain/screen_table.dart' show backRuleFor;
import '../../game/presentation/shell/table_shell.dart';
import '../../game/presentation/table_screen.dart' show tableScreenProvider;
import 'join_flow.dart';
import 'join_screen.dart';
import 'where_am_i_provider.dart';

/// The app's home (`/`, and `/join/<code>` from a table's link): signed in,
/// the table's shell, which shows exactly the screen `/me/table/` names
/// (01 at no table, 02 at a waiting table, the game's screens in a game),
/// so a player who comes back to a table they sit at is there without a
/// tap; signed out, 01, whose first tap makes this device's guest account.
/// While the saved account is read back (a try the server does not answer
/// is made again by itself), the game opening (`OpeningWait`), never 01.
///
/// - While a way in is on its way ([JoinFlow]), 01 stays (the account it
///   makes first would otherwise swap the screen mid-way).
/// - From a link ([code]): the table itself for a player at it; 01 with
///   the name and "Join" for one at no table; "You're at another table."
///   with "Go there" for one seated elsewhere (never a second seat).
/// - Back goes through the one [BackPolicy] here, by the rule of what is
///   shown: 01 and the opening waits leave the app (the seat is kept;
///   reopening restores it), "You're at another table." goes there, the
///   table's shell takes the rule of its screen ([backRuleFor]). A sheet
///   open on one of them closes when another is shown.
class HomeGate extends ConsumerWidget {
  const HomeGate({super.key, this.code});

  final String? code;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final (rule, place, screen) = _place(ref);
    return BackPolicy(rule: rule, place: place, child: screen);
  }

  /// The screen for where this phone is, which screen it is, and what Back
  /// does on it.
  (BackRule, Object, Widget) _place(WidgetRef ref) {
    final auth = ref.watch(authProvider);
    final busy = ref.watch(joinFlowProvider.select((f) => f.busy != null));
    final link = code;
    if (busy) {
      return (BackRule.leavesApp, 'join', JoinScreen(code: link));
    }
    return switch (auth) {
      // The saved account is being read back: 01's village and title, and
      // "One moment" while a try got no answer (it is made again by itself).
      // Never 01's form, whose Join would make a second account. Back leaves:
      // the seat is the server's, and reopening reads it back.
      AuthInitial(:final unanswered) => (
        BackRule.leavesApp,
        'opening',
        OpeningWait(
          unanswered: unanswered,
          onRetry: () => ref.invalidate(authProvider),
        ),
      ),
      AuthLoading() => (BackRule.leavesApp, 'opening', const OpeningWait()),
      AuthAuthenticated() when link != null => switch (ref.watch(
        myTableProvider,
      )) {
        AsyncValue(value: final table?) when table.lobbyCode == link => _shell(
          ref,
        ),
        // Seated elsewhere: say so; never a silent second seat. Back goes
        // there ("Go there"), never out of the app with a seat.
        AsyncValue(value: final _?) => (
          BackRule.staysPut,
          'elsewhere',
          JoinScreen(code: link, elsewhere: true),
        ),
        AsyncValue(hasValue: true) => (
          BackRule.leavesApp,
          'join',
          JoinScreen(code: link),
        ),
        // Not known yet: the opening, as before; nothing to tap until it is;
        // Back leaves, as on 01.
        final table => (
          BackRule.leavesApp,
          'opening',
          OpeningWait(
            unanswered: table.hasError,
            onRetry: () => ref.invalidate(myTableProvider),
          ),
        ),
      },
      AuthAuthenticated() => _shell(ref),
      AuthUnauthenticated() ||
      AuthError() => (BackRule.leavesApp, 'join', JoinScreen(code: link)),
    };
  }

  /// The table's shell, by the rule of the screen it shows ([backRuleFor]);
  /// before the first answer names one, Back leaves, as on the opening wait.
  static (BackRule, Object, Widget) _shell(WidgetRef ref) =>
      switch (ref.watch(tableScreenProvider.select((at) => at.value?.screen))) {
        final screen? => (backRuleFor(screen), screen, const TableShell()),
        null => (BackRule.leavesApp, 'opening', const TableShell()),
      };
}
