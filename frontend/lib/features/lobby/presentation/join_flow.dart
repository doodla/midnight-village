import 'package:flutter/foundation.dart';
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/logging/app_logger.dart';
import '../../../design_system/copy/copy.dart';
import '../../auth/domain/auth_state.dart';
import '../../auth/presentation/auth_notifier.dart';
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
/// - then a new table (`defaults: "v2"`, always) or a join by code;
/// - then `/me/table/` is read again, and the screen it names (02) follows.
///   Joining a table this player already sits at is no refusal: it is there.
@Riverpod(keepAlive: true)
class JoinFlow extends _$JoinFlow {
  @override
  JoinFlowState build() => const JoinFlowState();

  Future<bool> Function()? _again;

  /// Starts a table as [name]. True when the player is at it.
  Future<bool> start(String name) => _run(
    JoinWay.start,
    name,
    () => ref.read(lobbyServiceProvider).createTable(),
  );

  /// Joins table [code] as [name]. True when the player is at it.
  Future<bool> join(String name, String code) =>
      _run(JoinWay.join, name, () async {
        try {
          await ref.read(lobbyServiceProvider).joinLobby(code);
        } on ValidationException catch (e) {
          // Already at this table: that is where they are going.
          if (e.code != 'already_in_lobby') rethrow;
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
    Future<void> Function() sit,
  ) async {
    if (state.busy != null) return false;
    _again = () => _run(way, name, sit);
    state = JoinFlowState(busy: way);
    try {
      await _account(name.trim());
      await sit();
      ref.invalidate(myTableProvider);
      // The table's screen follows /me/table/; wait for it so the app does
      // not show 01 again in between.
      await ref.read(myTableProvider.future);
      _again = null;
      state = const JoinFlowState();
      return true;
    } catch (e) {
      logger.d('Could not sit down ($e)');
      if (ref.mounted) state = _bannerFor(e);
      return false;
    }
  }

  Future<void> _account(String name) async {
    final auth = ref.read(authProvider);
    if (auth is AuthAuthenticated && auth.user.displayName == name) return;
    final notifier = ref.read(authProvider.notifier);
    await notifier.createGuest(displayName: name);
    final after = ref.read(authProvider);
    if (after is! AuthAuthenticated) throw const _NotSignedIn();
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
