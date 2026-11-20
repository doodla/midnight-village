import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design_system/primitives/screen_frame.dart';
import '../../../design_system/skin/ground.dart';
import '../../auth/domain/auth_state.dart';
import '../../auth/presentation/auth_notifier.dart';
import '../../game/presentation/shell/table_shell.dart';
import 'join_flow.dart';
import 'join_screen.dart';
import 'where_am_i_provider.dart';

/// The app's home (`/`, and `/join/<code>` from a table's link): signed in,
/// the table's shell, which shows exactly the screen `/me/table/` names
/// (01 at no table, 02 at a waiting table, the game's screens in a game),
/// so a player who comes back to a table they sit at is there without a
/// tap; signed out, 01, whose first tap makes this device's guest account.
///
/// - While a way in is on its way ([JoinFlow]), 01 stays (the account it
///   makes first would otherwise swap the screen mid-way).
/// - From a link ([code]) to a table the player does not sit at: 01 with
///   the name and "Join".
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
      AuthInitial() || AuthLoading() => const ScreenFrame(
        ground: GroundKind.night,
        body: SizedBox.shrink(),
      ),
      AuthAuthenticated() when link != null => switch (ref
          .watch(myTableProvider)
          .value) {
        final table? when table.lobbyCode == link => const TableShell(),
        _ => JoinScreen(code: link),
      },
      AuthAuthenticated() => const TableShell(),
      AuthUnauthenticated() || AuthError() => JoinScreen(code: link),
    };
  }
}
