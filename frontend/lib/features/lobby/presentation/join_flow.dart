import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'
    show ProviderSubscription;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/logging/app_logger.dart';
import '../../../design_system/copy/copy.dart';
import '../../auth/domain/auth_state.dart';
import '../../auth/presentation/auth_notifier.dart';
import '../domain/lobby_state.dart';
import '../domain/where_am_i.dart';
import 'lobby_notifier.dart';
import 'where_am_i_provider.dart';

part 'join_flow.g.dart';

/// What 01 is doing: nothing, starting a table, or joining one; and the
/// banner of the last attempt that did not work (first-time play spec,
/// "Banners and errors").
@immutable
class JoinFlowState {
  const JoinFlowState({
    this.busy,
    this.banner,
    this.retry = false,
    this.goThere = false,
  });

  /// The way in on its way ([JoinWay.start] or [JoinWay.join]).
  final JoinWay? busy;

  /// The last attempt's banner ("No table with that code.", "Not sent.").
  final String? banner;

  /// The banner offers "Try again" (nothing the player typed was wrong).
  final bool retry;

  /// The banner offers "Go there": the player sits at another table, and the
  /// server will not seat them twice.
  final bool goThere;
}

enum JoinWay { start, join }

/// The ways in from 01, outside any widget so a screen that is swapped
/// mid-way (the sign-in that comes first puts the app in the table's shell)
/// loses nothing:
/// - the name: this device's own guest account when it has that name, else
///   a new guest account with it (the server has no rename);
/// - then a new table (`defaults: "v2"`, always) or a join by code, whose
///   answer is the table's lobby ([LobbySeed]: 02 draws it, no second read);
/// - then the screen `/me/table/` names (02) follows, the answer being where
///   the player sits ([SeatSeed]: nothing is asked after it). Joining a
///   table this player already sits at is no refusal: it is there, and
///   `/me/table/` is read to say so.
/// The account step never makes a second account over a saved one the
/// server has not refused (`AuthNotifier.createGuest`).
@Riverpod(keepAlive: true)
class JoinFlow extends _$JoinFlow {
  @override
  JoinFlowState build() => const JoinFlowState();

  Future<bool> Function()? _again;

  /// Starts a table as [name]. True when the player is at it. The answer is
  /// the new table's lobby: 02 shows it without reading it again (nobody
  /// else knows the code yet, so nothing can have changed).
  Future<bool> start(String name) => _run(JoinWay.start, name, () async {
    final lobby = await ref.read(lobbyServiceProvider).createTable();
    ref.read(lobbySeedProvider).put(lobby, settled: true);
    return lobby;
  });

  /// Joins table [code] as [name]. True when the player is at it. The answer
  /// is the table's lobby: 02 shows it at once (and reads it again once its
  /// socket listens, for a join said meanwhile).
  Future<bool> join(String name, String code) =>
      _run(JoinWay.join, name, () async {
        try {
          final lobby = await ref.read(lobbyServiceProvider).joinLobby(code);
          ref.read(lobbySeedProvider).put(lobby, settled: false);
          return lobby;
        } on ValidationException catch (e) {
          // Already at this table: that is where they are going (no answer
          // names the seat: `/me/table/` is read to say so).
          if (e.code != 'already_in_lobby') rethrow;
          return null;
        }
      });

  /// "Try again" on the last banner.
  Future<bool> retry() async {
    final again = _again;
    if (again == null) return false;
    return again();
  }

  /// Forgets the banner (the player is typing again).
  void clearBanner() {
    if (state.banner != null) state = JoinFlowState(busy: state.busy);
  }

  /// The game this phone was in is gone (its table closed: the server
  /// answered 404): 01, where it lands, says so until the next edit.
  void tableClosed() {
    if (state.busy == null) {
      state = const JoinFlowState(banner: BannerCopy.tableClosed);
    }
  }

  /// "Go there": `/me/table/` is read again, and its table shows.
  void goThere() {
    clearBanner();
    ref.invalidate(myTableProvider);
  }

  Future<bool> _run(
    JoinWay way,
    String name,
    Future<LobbyState?> Function() sit,
  ) async {
    if (state.busy != null) return false;
    _again = () => _run(way, name, sit);
    state = JoinFlowState(busy: way);
    ref.read(lobbySeedProvider).clear();
    ref.read(seatSeedProvider).clear();
    try {
      final user = await _account(name.trim());
      final lobby = await sit();
      // The answer is where the player sits now: /me/table/ takes it
      // without asking (with no answer naming it, it is asked).
      final seat = lobby == null
          ? null
          : MyTable.seatedAt(lobby, viewerId: user);
      // The table's screen follows /me/table/; wait for it so the app does
      // not show 01 again in between. Held while waited for: nothing else
      // may be listening yet (01 shows while this runs), and a read nobody
      // holds is disposed mid-fetch, which failed a seat that was taken
      // ("Not sent." kept, and shown on 01 after the player left).
      final held = holdSeatFromAnswer(ref, user, seat);
      try {
        await ref.read(myTableProvider.future);
      } catch (_) {
        held.close();
        rethrow;
      }
      _again = null;
      state = const JoinFlowState();
      // Held until the table's screen holds it (the frame that shows it):
      // let go now, it would be disposed before that frame and read again.
      _releaseAfterFrame(held);
      return true;
    } on _NotAsked {
      _again = null;
      if (ref.mounted) state = const JoinFlowState();
      return false;
    } catch (e) {
      logger.d('Could not sit down ($e)');
      if (ref.mounted) state = _bannerFor(e);
      return false;
    }
  }

  /// The account to sit down with (its id): this device's own when it has
  /// [name], else a new guest account.
  Future<int> _account(String name) async {
    final auth = ref.read(authProvider);
    if (auth is AuthAuthenticated && auth.user.displayName == name) {
      return auth.user.id;
    }
    final notifier = ref.read(authProvider.notifier);
    // Nothing sent (the saved account is still being read back, or one was
    // found): no banner, nothing to try again; the screen follows the account.
    if (!await notifier.createGuest(displayName: name)) throw const _NotAsked();
    final after = ref.read(authProvider);
    if (after is! AuthAuthenticated) throw const _NotSignedIn();
    return after.user.id;
  }

  /// Lets go of [held] once the next frame is drawn: by then the screen the
  /// new state shows holds what it reads.
  static void _releaseAfterFrame(ProviderSubscription<Object?> held) {
    SchedulerBinding.instance
      ..addPostFrameCallback((_) => held.close())
      ..ensureVisualUpdate();
  }

  static JoinFlowState _bannerFor(Object error) {
    final code = switch (error) {
      ValidationException(:final code) => code,
      UnhandledHttpException(:final code) => code,
      NotFoundException() => 'lobby_not_found',
      _ => null,
    };
    return switch (code) {
      'lobby_not_found' => const JoinFlowState(
        banner: BannerCopy.lobbyNotFound,
      ),
      'lobby_full' => const JoinFlowState(banner: BannerCopy.lobbyFull),
      'lobby_closed' => const JoinFlowState(banner: BannerCopy.lobbyClosed),
      // The server's coming refusal (409, with that table's code): the
      // player is seated elsewhere; "Go there" opens it.
      'already_at_table' => const JoinFlowState(
        banner: BannerCopy.alreadyInLobby,
        goThere: true,
      ),
      _ => const JoinFlowState(banner: BannerCopy.notSent, retry: true),
    };
  }
}

class _NotSignedIn implements Exception {
  const _NotSignedIn();
}

/// Nothing was sent: no account was asked for (see [JoinFlow._account]).
class _NotAsked implements Exception {
  const _NotAsked();
}
