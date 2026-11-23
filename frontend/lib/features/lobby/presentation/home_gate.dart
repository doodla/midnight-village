import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/router/back_policy.dart';
import '../../../design_system/primitives/scene_switcher.dart';
import '../../auth/domain/auth_state.dart';
import '../../auth/presentation/auth_notifier.dart';
import '../../game/domain/screen_table.dart' show AppScreen, backRuleFor;
import '../../game/presentation/shell/table_shell.dart';
import '../../game/presentation/new_build_provider.dart';
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
/// - 01 is this gate's own, wherever it is reached from (signed out, a
///   link, the table's screen naming no table, a way in on its way
///   ([JoinFlow])): one screen in one place, so a request that is busy never
///   tears it down and builds it again (what was typed, the cursor and the
///   refusal that lands stay). It crossfades with what is not 01, as the
///   table's shell crossfades its own screens.
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
    // The app renews itself for a newer build at a safe moment, by what is
    // shown (`mayReloadNow`).
    ref.read(newBuildProvider)?.seen(place);
    return BackPolicy(
      rule: rule,
      place: place,
      child: SceneSwitcher<bool>(
        stage: screen is JoinScreen,
        sceneBetween: _crossfade,
        child: screen,
      ),
    );
  }

  static SceneKind? _crossfade(bool from, bool to) => null;

  /// The screen for where this phone is, which screen it is, and what Back
  /// does on it.
  (BackRule, Object, Widget) _place(WidgetRef ref) {
    final auth = ref.watch(authProvider);
    // Where this phone sits is held for as long as home is shown: while a way
    // in is on its way 01 is shown on its own (the account made first would
    // swap the shell away), and the read of the seat, which is all that
    // follows, must not be dropped between 01 and the table's shell (a second
    // read, and the opening shown for it, between 01 and 02).
    if (auth is AuthAuthenticated) {
      ref.listen(myTableProvider, (_, _) {});
      // 01's last failure ("Not sent.", a refusal) belongs to 01: once the
      // phone is anywhere else, it is gone, so it can never show up later,
      // after a Leave, as a failure of something that worked.
      ref.listen(tableScreenProvider.select((a) => a.value?.screen), (_, at) {
        if (at != null && at != AppScreen.join) {
          ref.read(joinFlowProvider.notifier).clearBanner();
        }
      });
    }
    final busy = ref.watch(joinFlowProvider.select((f) => f.busy != null));
    final seatUnread = ref.watch(joinFlowProvider.select((f) => f.seatUnread));
    final link = code;
    if (busy) {
      return (BackRule.leavesApp, 'join', JoinScreen(code: link));
    }
    // A way in worked and the seat cannot be read yet: the opening says so
    // (never 01 again, whose buttons ask for a second seat).
    if (seatUnread && auth is AuthAuthenticated) {
      return (
        BackRule.leavesApp,
        'opening',
        OpeningWait(
          unanswered: ref.watch(myTableProvider.select((t) => t.hasError)),
          onRetry: () => ref.invalidate(myTableProvider),
        ),
      );
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
  /// At no table, 01: the gate's own (the same element as the 01 a way in
  /// shows while it is busy, never the shell's).
  static (BackRule, Object, Widget) _shell(WidgetRef ref) =>
      switch (ref.watch(tableScreenProvider.select((at) => at.value?.screen))) {
        AppScreen.join => (BackRule.leavesApp, 'join', const JoinScreen()),
        final screen? => (backRuleFor(screen), screen, const TableShell()),
        null => (BackRule.leavesApp, 'opening', const TableShell()),
      };
}
