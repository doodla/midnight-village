import 'dart:async';

import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/healing/healing.dart';
import '../../../design_system/skin/skin_choice.dart'
    show devicePreferencesProvider;
import '../../auth/domain/auth_state.dart';
import '../../auth/presentation/auth_notifier.dart';
import '../../game/domain/game_me.dart' show GamePhase;
import '../domain/where_am_i.dart';
import 'last_seat.dart';
import 'lobby_notifier.dart';

part 'where_am_i_provider.g.dart';

/// Where this player sits (`GET /me/table/`): the first fetch of a cold
/// start, fetched again (invalidated) when the table may have moved on (a
/// phase change, play again, a host change, leave, reconnect, resume). A
/// failed fetch is retried until it succeeds ([retryForever]). At a waiting
/// table or a finished game, where only an event would say the table moved
/// on, it is also polled slowly ([HealTiming.tablePoll]). Null: at no table.
/// Every answer is kept on the device as the last seat ([LastSeat]).
@Riverpod(retry: retryForever)
Future<MyTable?> myTable(Ref ref) async {
  final table = await ref.watch(lobbyServiceProvider).fetchMyTable();
  if (ref.read(authProvider) case AuthAuthenticated(:final user)) {
    LastSeat.keep(ref.read(devicePreferencesProvider), user.id, table);
  }
  if (table != null &&
      (table.status == TableStatus.waiting ||
          table.status == TableStatus.finished ||
          table.gamePhase == GamePhase.results)) {
    final poll = Timer(ref.read(healTimingProvider).tablePoll, () {
      if (ref.mounted) ref.invalidateSelf();
    });
    ref.onDispose(poll.cancel);
  }
  return table;
}
