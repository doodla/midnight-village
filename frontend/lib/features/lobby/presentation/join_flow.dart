import 'dart:async';
import 'dart:convert';

import 'package:flutter/foundation.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart'
    show Notifier, NotifierProvider, ProviderSubscription;
import 'package:riverpod_annotation/riverpod_annotation.dart';

import '../../../core/api/api_exception.dart';
import '../../../core/logging/app_logger.dart';
import '../../../core/requests/player_request.dart';
import '../../../core/storage/tab_storage_provider.dart';
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
    this.seatUnread = false,
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

  /// The way in worked (the phone has a seat) but `/me/table/` could not be
  /// read after it: the app says "One moment" (the opening) until it is,
  /// never 01 again, whose buttons would ask for a second seat.
  final bool seatUnread;
}

enum JoinWay { start, join }

/// What 01's form holds, kept outside the screen, so a 01 built again (the
/// page reloaded for a newer build) has the typed name and code and the open
/// code field. Cleared once the phone sits at a table (the next 01 is a clean
/// one).
@immutable
class JoinDraft {
  const JoinDraft({this.name, this.code = '', this.codeOpen = false});

  /// Null: not typed over (the field shows this device's own account's name).
  final String? name;
  final String code;
  final bool codeOpen;

  /// Something the player typed: a name over their own, or a code.
  bool get isTyped => (name?.isNotEmpty ?? false) || code.isNotEmpty;

  String toJson() =>
      jsonEncode({'name': name, 'code': code, 'codeOpen': codeOpen});

  /// The draft [toJson] wrote; nothing (an empty draft) for anything else.
  static JoinDraft fromJson(String? text) {
    if (text == null) return const JoinDraft();
    try {
      final map = jsonDecode(text) as Map<String, dynamic>;
      return JoinDraft(
        name: map['name'] as String?,
        code: map['code'] as String? ?? '',
        codeOpen: map['codeOpen'] as bool? ?? false,
      );
    } catch (_) {
      return const JoinDraft();
    }
  }
}

/// Where this tab keeps 01's form across the page's own reload (the app
/// renewing itself for a newer build): the same key for write and read.
const joinDraftKey = 'mv.joinDraft.v1';

class JoinDraftNotifier extends Notifier<JoinDraft> {
  /// What the tab kept before this page was reloaded (`TabStorage`), so the
  /// reload shows 01 as it was.
  @override
  JoinDraft build() =>
      JoinDraft.fromJson(ref.read(tabStorageProvider).read(joinDraftKey));

  void keep(JoinDraft draft) {
    state = draft;
    final storage = ref.read(tabStorageProvider);
    draft.isTyped || draft.codeOpen
        ? storage.write(joinDraftKey, draft.toJson())
        : storage.remove(joinDraftKey);
  }

  void clear() {
    state = const JoinDraft();
    ref.read(tabStorageProvider).remove(joinDraftKey);
  }
}

final joinDraftProvider = NotifierProvider<JoinDraftNotifier, JoinDraft>(
  JoinDraftNotifier.new,
);

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
  Future<bool> start(String name) => _run(JoinWay.start, name, (door) async {
    final lobby = await ref.read(lobbyServiceProvider).createTable(door);
    ref.read(lobbySeedProvider).put(lobby, settled: true);
    return lobby;
  });

  /// Joins table [code] as [name]. True when the player is at it. The answer
  /// is the table's lobby: 02 shows it at once (and reads it again once its
  /// socket listens, for a join said meanwhile).
  Future<bool> join(String name, String code) => _run(JoinWay.join, name, (
    door,
  ) async {
    try {
      final lobby = await ref.read(lobbyServiceProvider).joinLobby(door, code);
      ref.read(lobbySeedProvider).put(lobby, settled: false);
      return lobby;
    } on ValidationException catch (e) {
      // Already at this table: that is where they are going (no answer
      // names the seat: `/me/table/` is read to say so).
      if (e.code != 'already_in_lobby') rethrow;
      return null;
    }
  });

  /// Until `/me/table/` is read after a way in whose read failed: then the
  /// app goes on to the table.
  Future<void> _untilRead() async {
    await readSucceeded(ref, myTableProvider);
    if (ref.mounted && state.seatUnread && state.busy == null) {
      state = const JoinFlowState();
    }
  }

  /// "Try again" on the last banner.
  Future<bool> retry() async {
    final again = _again;
    if (again == null) return false;
    return again();
  }

  /// Forgets the banner (the player is typing again).
  void clearBanner() {
    if (state.banner != null) {
      state = JoinFlowState(busy: state.busy, seatUnread: state.seatUnread);
    }
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
    Future<LobbyState?> Function(Door door) sit,
  ) async {
    if (state.busy != null) return false;
    _again = () => _run(way, name, sit);
    state = JoinFlowState(busy: way);
    ref.read(lobbySeedProvider).clear();
    ref.read(seatSeedProvider).clear();
    try {
      final (user, lobby) = await playerRequest((door) async {
        final user = await _account(door, name.trim());
        return (user, await sit(door));
      });
      // The answer is where the player sits now: /me/table/ takes it
      // without asking (with no answer naming it, it is asked). Held from
      // here: nothing else may be listening yet (01 shows while this runs).
      final seat = lobby == null
          ? null
          : MyTable.seatedAt(lobby, viewerId: user);
      final held = holdSeatFromAnswer(ref, user, seat);
      // The table's screen follows /me/table/; wait for it so the app does
      // not show 01 again in between. A read that is failing frees 01's
      // button all the same: the seat is taken, and the app's opening says
      // "One moment" with "Try again" until it is read (`OpeningWait`),
      // instead of 01 spinning for as long as the phone is out of reach.
      final bool read;
      try {
        read = await readAnswered(ref, myTableProvider);
      } catch (_) {
        held.close();
        rethrow;
      }
      _again = null;
      ref.read(joinDraftProvider.notifier).clear();
      state = JoinFlowState(seatUnread: !read);
      if (!read) unawaited(_untilRead());
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
  Future<int> _account(Door door, String name) async {
    final auth = ref.read(authProvider);
    if (auth is AuthAuthenticated && auth.user.displayName == name) {
      return auth.user.id;
    }
    final notifier = ref.read(authProvider.notifier);
    // Nothing sent (the saved account is still being read back, or one was
    // found): no banner, nothing to try again; the screen follows the account.
    if (!await notifier.createGuest(door, displayName: name)) {
      throw const _NotAsked();
    }
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
