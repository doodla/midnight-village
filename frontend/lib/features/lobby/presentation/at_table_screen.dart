import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../core/router/back_policy.dart';
import '../../../core/requests/player_request.dart';
import '../../../design_system/primitives/waiting_sign.dart';
import '../../../design_system/primitives/pending.dart';
import '../../../design_system/copy/copy.dart';
import '../../../design_system/layout/space.dart';
import '../../../design_system/models/role.dart';
import '../../../design_system/primitives/chips.dart';
import '../../../design_system/primitives/fanned.dart';
import '../../../design_system/primitives/fit_line.dart';
import '../../../design_system/primitives/mood.dart';
import '../../../design_system/primitives/notice.dart';
import '../../../design_system/primitives/panels.dart';
import '../../../design_system/primitives/paper_card.dart';
import '../../../design_system/primitives/player_row.dart';
import '../../../design_system/primitives/primary_button.dart';
import '../../../design_system/primitives/qr_picture.dart';
import '../../../design_system/primitives/role_card.dart';
import '../../../design_system/primitives/screen_frame.dart';
import '../../../design_system/primitives/secondary_button.dart';
import '../../../design_system/primitives/sheet_scaffold.dart';
import '../../../design_system/primitives/text_action.dart';
import '../../../design_system/skin/dress.dart';
import '../../../design_system/skin/ground.dart';
import '../../../design_system/skin/skin.dart';
import '../../auth/domain/auth_state.dart';
import '../../auth/presentation/auth_notifier.dart';
import '../../game/presentation/live_game.dart' show liveGameProvider;
import '../../game/presentation/table_screen.dart' show localStepsProvider;
import '../domain/lobby_state.dart';
import 'deck_screen.dart'
    show deckChipLabel, deckFixWords, lengthText, minSeats, showRoleSheet;
import 'seats_line.dart';
import 'home_numbers.dart';
import 'lobby_notifier.dart';
import 'where_am_i_provider.dart';
import '../../../design_system/primitives/icon_action.dart';
import '../../../design_system/primitives/rule.dart';
import '../../../design_system/primitives/scrap_label.dart';

part 'at_table_view.dart';
part 'at_table_parts.dart';

/// 02 Table (first-time play spec, section 3): who is here, and the way to
/// get the others in.
///
/// - Everyone: "Scan to join" over the QR code of the table's link, large and
///   centred, the code under it, Share beside the words (copied, "Copied",
///   only where there is no share sheet); then everyone at the table as a
///   row each, their own outlined, a dropped phone dimmed with no words.
/// - Host: the deck as its chip with its cards face up (the server's
///   `deck_preview`) or the custom deck's cards, with "Edit" (03); "Start
///   the game", amber, by the server's verdict on dealing ([DealState]), else
///   what to do and a tap does it: the friends first ("Need 3 players", "Need
///   {n} more": shares the link), then the deck ("Add 1 card", "Remove 2 cards":
///   opens 03, and "Edit" is hidden: one way in); a refused deal says why; a
///   quiet "Leave" under the button that asks first ("Stay" / "Leave"), so one
///   stray tap never hands the table away.
/// - Guest: "{host} deals" over the same code, the rows, and a quiet "Leave"
///   at the end.
/// - Back asks first, host or guest, with the host's "Stay" / "Leave".
/// - A handover makes another phone the host: it switches layout, with no
///   words. A table the server says is gone says so, with "Go home".
///
/// Everything shown is the lobby ([lobbyProvider]: its body, its socket,
/// this phone's own changes merged over it), read until it answers ("One
/// moment" meanwhile); which screen shows is `/me/table/`'s, read again here
/// whenever the table moves on (the deal, a handover).
class AtTableScreen extends ConsumerStatefulWidget {
  const AtTableScreen({super.key});

  @override
  ConsumerState<AtTableScreen> createState() => _AtTableScreenState();
}

class _AtTableScreenState extends ConsumerState<AtTableScreen> {
  var _dealing = false;

  /// 02's Leave: busy in the frame of the tap and until the phone is off the
  /// table (01 is named), its failure its own (`Pending`).
  final _leave = Pending();
  var _copied = false;

  @override
  void initState() {
    super.initState();
    _leave.addListener(_leaveChanged);
  }

  void _leaveChanged() {
    if (mounted) setState(() {});
  }

  @override
  void dispose() {
    _dealt?.close();
    _leave.dispose();
    super.dispose();
  }

  int? get _viewer => switch (ref.read(authProvider)) {
    AuthAuthenticated(:final user) => user.id,
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    final table = ref.watch(myTableProvider).value;
    if (table == null) {
      return _Waiting(
        offline: ref.watch(myTableProvider.select((t) => t.hasError)),
        onRetry: () => ref.invalidate(myTableProvider),
      );
    }
    final code = table.lobbyCode;
    ref.listen(lobbyProvider(code), _follow);
    final read = ref.watch(lobbyProvider(code));
    final lobby = read.value;
    final viewer = _viewer;
    if (lobby == null || viewer == null) {
      return _Waiting(
        offline: read.error != null,
        onRetry: () => ref.invalidate(lobbyProvider(code)),
      );
    }
    final notifier = ref.read(lobbyProvider(code).notifier);
    final origin = ref.watch(appOriginProvider);
    return AtTableView(
      lobby: lobby,
      viewerId: viewer,
      link: origin == null ? null : joinLink(origin, code),
      dealing: _dealing,
      leaving: _leave.busy,
      notSent: lobby.notSent,
      leaveFailure: _leave.failure,
      copied: _copied,
      onRetry: () {
        if (_leave.failed) {
          unawaited(_leave.retry());
        } else {
          unawaited(notifier.retry());
        }
      },
      onShare: (link) => unawaited(_share(link)),
      onEditDeck: () => ref.read(localStepsProvider.notifier).openDeck(table),
      onPlayWith: (players) {
        unawaited(notifier.setSeats(players));
        // A deck of the host's own was built for more: 03, its count
        // showing, so the host fixes it (never thrown away).
        if (!lobby.table.autoDeck) {
          ref.read(localStepsProvider.notifier).openDeck(table);
        }
      },
      onDeal: () => unawaited(_deal(notifier)),
      onLeave: () => _leaveTable(code),
      onGoHome: () => ref.invalidate(myTableProvider),
    );
  }

  /// What the lobby's changes mean beyond what it shows: a deal or a
  /// handover moves `/me/table/` on, so it is read again. A deal names its
  /// game (the deal's answer, or `game_started`): that game's `/me/` is read
  /// at the same time, not after `/me/table/`, and the game's screen finds
  /// it on its way.
  void _follow(AsyncValue<LobbyState>? before, AsyncValue<LobbyState> now) {
    final lobby = now.value;
    if (lobby == null) return;
    final was = before?.value;
    final started = lobby.startedGameId;
    final moved = started != null && started != was?.startedGameId;
    final hostMoved = was != null && was.hostId != lobby.hostId;
    if (moved || hostMoved) ref.invalidate(myTableProvider);
    if (moved) {
      _dealt?.close();
      _dealt = ref.listenManual(liveGameProvider(started), (_, _) {});
    }
  }

  /// The dealt game, read from the moment it is named until this screen
  /// gives way to it.
  ProviderSubscription<Object?>? _dealt;

  Future<void> _share(Uri link) async {
    setState(() => _copied = false);
    final copied = await ref.read(shareLinkProvider)(link);
    if (mounted) setState(() => _copied = copied);
  }

  Future<void> _deal(LobbyNotifier notifier) async {
    setState(() {
      _dealing = true;
      _copied = false;
    });
    await notifier.deal();
    if (mounted) setState(() => _dealing = false);
  }

  void _leaveTable(String code) {
    // A question answered after the table gave way (the sheet closes with
    // its screen, but never leave from a screen that is gone).
    if (!mounted || _leave.busy) return;
    setState(() => _copied = false);
    final container = ProviderScope.containerOf(context, listen: false);
    final lobby = ref.read(lobbyProvider(code).notifier);
    unawaited(
      _leave.run(
        lobby.leave,
        // Off the table: `/me/table/` says where to go (01 Join). Busy until
        // it does; a read that fails frees the button and says "One moment".
        settle: (again) async {
          container.invalidate(myTableProvider);
          return readAnsweredIn(container, myTableProvider);
        },
      ),
    );
  }
}

/// Before the table is known: its ground; "One moment" while it cannot be
/// read (it is read again until it answers).
class _Waiting extends StatelessWidget {
  const _Waiting({this.offline = false, this.onRetry});

  final bool offline;
  final VoidCallback? onRetry;

  @override
  Widget build(BuildContext context) => ScreenFrame(
    ground: GroundKind.night,
    body: Align(
      alignment: Alignment.topCenter,
      child: Waiting(failing: offline, onRetry: onRetry, centred: true),
    ),
  );
}
