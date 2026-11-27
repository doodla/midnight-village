import 'dart:async';

import 'package:flutter_riverpod/flutter_riverpod.dart'
    show ProviderContainer, ProviderSubscription;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/healing/healing.dart';
import '../../../core/websocket/socket_health.dart';
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
/// start, fetched again (invalidated) when the seat may have changed (play
/// again, a host change, leave, a refused game, reconnect, a lobby that
/// says its table is in a game this phone was not told of; a stage change
/// moves it from what `/me/` says, `MyTable.inGameAt`). Coming back to
/// the app reads it again at once, whatever the screen: an event missed
/// while the phone slept is healed by that one read. A failed fetch is
/// retried until it succeeds ([retryForever]). At a waiting table or a
/// finished game, where only an event would say the table moved on, it is
/// also polled slowly ([HealTiming.tablePoll]) while the socket that would
/// hear its news is down ([SocketHealth]): the backstop, never the way
/// a missed event heals; a poll that brings the same answer is not a new
/// state (nothing is told, so nothing is drawn). Null: at no table. Every answer is kept on the
/// device as the last seat ([LastSeat]).
///
/// A read asked for right after the server said where this player sits (an
/// answer: a table started or joined, a deal, play again; or an event:
/// `game_started`, `play_again`) takes that seat ([SeatSeed]) and sends
/// nothing: the server has said it already.
@Riverpod(retry: retryForever)
Future<MyTable?> myTable(Ref ref) async {
  final service = ref.watch(lobbyServiceProvider);
  var landed = false;
  ref.listen(appResumesProvider, (_, next) {
    // Joins a read already out: a game asks again plainly as it comes back,
    // 02's lobby read asks again (judged) if the table moved on.
    if (next.hasValue && ref.mounted && landed) ref.invalidateSelf();
  });
  // This read is dropped when a newer one is asked for (a seat put, an
  // event, the poll): its answer, if it still comes, arms nothing.
  var current = true;
  Timer? poll;
  ref.onDispose(() {
    current = false;
    poll?.cancel();
  });
  final seeded = ref.read(seatSeedProvider).take(_userId(ref));
  final table = seeded ?? await service.fetchMyTable();
  landed = true;
  if (!current) return table;
  if (_userId(ref) case final user?) {
    LastSeat.keep(ref.read(devicePreferencesProvider), user, table);
  }
  if (table != null &&
      (table.status == TableStatus.waiting ||
          table.status == TableStatus.finished ||
          table.gamePhase == GamePhase.results)) {
    void armPoll() {
      poll = Timer(ref.read(healTimingProvider).tablePoll, () async {
        if (!ref.mounted || !current) return;
        // A socket that is up hears the deal or play again itself: the poll
        // heals only one that is down ([SocketHealth]).
        final socket = table.status == TableStatus.waiting
            ? SocketHealth.lobby(table.lobbyCode)
            : SocketHealth.game(table.gameId ?? '');
        if (ref.read(socketHealthProvider).isUp(socket)) return armPoll();
        final MyTable? read;
        try {
          read = await service.fetchMyTable();
        } catch (_) {
          // Not answered: read again the usual way (retried until it lands).
          if (ref.mounted && current) ref.invalidateSelf();
          return;
        }
        if (!ref.mounted || !current) return;
        // The same answer tells nobody (no frame is drawn for it); one that
        // moved is the next read, with no second request.
        if (read == table) return armPoll();
        if ((_userId(ref), read) case (final user?, final seat?)) {
          ref.read(seatSeedProvider)._put(user, seat);
        }
        ref.invalidateSelf();
      });
    }

    armPoll();
  }
  return table;
}

/// Where the server just said this player sits (`MyTable.seatedAt`, `MyTable
/// .backToWaiting`: an answer, a table started or joined, a deal, play
/// again; or an event, `game_started`, `play_again`), so `/me/table/`'s next
/// read takes it instead of asking ([myTableProvider]): the screen it names
/// follows the answer or the event with no request after it. One slot, put
/// and asked for together ([seatFromServer]) and taken by that read; a read
/// for another account drops it. Every read after that asks the server as
/// before (the slow poll, reconnect, resume, a phase one of them is behind
/// on). A read still out when the seat is put is dropped with it (the seat
/// asks for a new read, and Riverpod keeps only the newest), so an older
/// answer never moves the screen back.
class SeatSeed {
  ({int userId, MyTable seat})? _seed;

  void _put(int userId, MyTable seat) => _seed = (userId: userId, seat: seat);

  /// The seed, once, if it is account [userId]'s.
  MyTable? take(int? userId) {
    final seed = _seed;
    _seed = null;
    return seed != null && seed.userId == userId ? seed.seat : null;
  }

  void clear() => _seed = null;
}

@Riverpod(keepAlive: true)
SeatSeed seatSeed(Ref ref) => SeatSeed();

/// The server said where account [userId] sits now ([seat]), in an answer
/// or an event: `/me/table/` is read again at once, and that read is the
/// seat (no request).
/// Only while `/me/table/` is mounted (a screen holds it), so the read that
/// takes the seed is the one asked for here: a seed never waits for a later
/// read and goes stale. Nothing mounted: nothing is put, and the next read
/// asks the server. A seat from an event is checked behind the screen
/// that moved: the new screen's socket opening reads `/me/table/`
/// ([askWhere]), and a game that refuses this player reads it too.
void seatFromServer(Ref ref, int userId, MyTable seat) {
  if (!ref.exists(myTableProvider)) return;
  ref.read(seatSeedProvider)._put(userId, seat);
  ref.invalidate(myTableProvider);
}

/// THE way to ask where this player sits again, because something says the
/// table may have moved on: every place that asks goes through it (resume,
/// a socket opening or coming back, a lobby ahead of the phone, a host
/// change, a game that is refused or behind, a seat to check), so one
/// heal costs one `/me/table/` request before the screen moves, in
/// whichever order its asks come. It never restarts a read that already
/// answers the question:
/// - [settledBy] (a lobby saying the table is in a game): the answer
///   held, or the read out when it lands (it is no slower than a new one),
///   is judged; asked again only when it does not settle it (a read that
///   names the game is enough, an older poll that says "waiting" is not).
/// Otherwise (the end board, a game: nothing else covers a missed event)
/// the read out is replaced by a new one (Riverpod keeps only the newest).
/// Nothing holds `/me/table/`: nothing is asked.
void askWhere(Ref ref, {bool Function(MyTable? table)? settledBy}) {
  if (!ref.exists(myTableProvider)) return;
  final now = ref.read(myTableProvider);
  if (now.isLoading && settledBy != null) {
    late final ProviderSubscription<AsyncValue<MyTable?>> out;
    out = ref.listen(myTableProvider, (_, next) {
      if (next.isLoading) return;
      out.close();
      if (next.hasValue && !settledBy(next.value)) {
        ref.invalidate(myTableProvider);
      }
    });
    return;
  }
  if (settledBy != null && now.hasValue && settledBy(now.value)) return;
  ref.invalidate(myTableProvider);
}

/// [askWhere] from a widget (no question to compare with: a host change).
void askWhereIn(ProviderContainer container) {
  if (container.exists(myTableProvider)) {
    container.invalidate(myTableProvider);
  }
}

/// [seatFromServer] where nothing may hold `/me/table/` yet (01 signed out,
/// before the first account): reads it again now, from [seat] when one is
/// given (else from the server), and holds it (the subscription returned) so
/// that read is the one the seed is for.
ProviderSubscription<AsyncValue<MyTable?>> holdSeatFromAnswer(
  Ref ref,
  int userId,
  MyTable? seat,
) {
  final seeds = ref.read(seatSeedProvider);
  if (seat != null) {
    seeds._put(userId, seat);
  } else {
    seeds.clear();
  }
  ref.invalidate(myTableProvider);
  return ref.listen(myTableProvider, (_, _) {});
}

int? _userId(Ref ref) => switch (ref.read(authProvider)) {
  AuthAuthenticated(:final user) => user.id,
  _ => null,
};
