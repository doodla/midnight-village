import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../design_system/copy/copy.dart';
import '../../../design_system/layout/space.dart';
import '../../../design_system/models/role.dart';
import '../../../design_system/primitives/chips.dart';
import '../../../design_system/primitives/fit_line.dart';
import '../../../design_system/primitives/notice.dart';
import '../../../design_system/primitives/panels.dart';
import '../../../design_system/primitives/paper_card.dart';
import '../../../design_system/primitives/player_row.dart';
import '../../../design_system/primitives/primary_button.dart';
import '../../../design_system/primitives/qr_picture.dart';
import '../../../design_system/primitives/role_card.dart';
import '../../../design_system/primitives/screen_frame.dart';
import '../../../design_system/primitives/secondary_button.dart';
import '../../../design_system/skin/ground.dart';
import '../../../design_system/skin/skin.dart';
import '../../auth/domain/auth_state.dart';
import '../../auth/presentation/auth_notifier.dart';
import '../../game/presentation/table_screen.dart' show localStepsProvider;
import '../domain/lobby_state.dart';
import '../domain/where_am_i.dart';
import 'deck_screen.dart' show deckChipLabel;
import 'home_numbers.dart';
import 'lobby_notifier.dart';
import 'where_am_i_provider.dart';

/// 02 Table (first-time play spec, section 3): who is here, and for the
/// host the way to get the others in and to deal.
///
/// - Host: the QR code of the table's link, loudest, the code under it and
///   Share beside it (a glyph: the screen's seven words go to the deck and
///   the deal); everyone at the table as a row each, their own outlined; the
///   deck as its chip ("Simple", or the custom deck's cards) with "Edit",
///   which opens 03; "Deal to {n}", amber, by the server's rules for the
///   deal ([DealState]); a glyph to leave.
/// - Guest: "{host} deals", the code in small type, the rows, quiet
///   "Leave".
/// - A handover makes another phone the host: it switches layout, with no
///   words. A table the server says is gone says so, with "Go home".
///
/// Everything shown is the lobby ([lobbyProvider]: its body, its socket,
/// this phone's own changes merged over it); which screen shows is
/// `/me/table/`'s, read again here whenever the table moves on (the deal,
/// a handover). Each phone sets its own ready flag as it sits down
/// ([LobbyNotifier.sitDown]); there is no ready button.
class AtTableScreen extends ConsumerStatefulWidget {
  const AtTableScreen({super.key});

  @override
  ConsumerState<AtTableScreen> createState() => _AtTableScreenState();
}

class _AtTableScreenState extends ConsumerState<AtTableScreen> {
  var _dealing = false;
  var _leaving = false;
  var _leaveFailed = false;

  int? get _viewer => switch (ref.read(authProvider)) {
    AuthAuthenticated(:final user) => user.id,
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    final table = ref.watch(myTableProvider).value;
    if (table == null) return const _Ground();
    final code = table.lobbyCode;
    ref.listen(
      lobbyProvider(code),
      (before, now) => _follow(table, before, now),
    );
    final lobby = ref.watch(lobbyProvider(code)).value;
    final viewer = _viewer;
    if (lobby == null || viewer == null) return const _Ground();
    final notifier = ref.read(lobbyProvider(code).notifier);
    if (!lobby.players.any((p) => p.id == viewer && p.isReady)) {
      // Opened on a lobby already loaded: no change will come to sit down on.
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => unawaited(notifier.sitDown(viewer)),
      );
    }
    final origin = ref.watch(appOriginProvider);
    return AtTableView(
      lobby: lobby,
      viewerId: viewer,
      link: origin == null ? null : joinLink(origin, code),
      dealing: _dealing,
      leaving: _leaving,
      notSent: lobby.notSent || _leaveFailed,
      onRetry: () {
        if (_leaveFailed) {
          unawaited(_leave(code));
        } else {
          unawaited(notifier.retry());
        }
      },
      onShare: (link) => unawaited(ref.read(shareLinkProvider)(link)),
      onEditDeck: () => ref.read(localStepsProvider.notifier).openDeck(table),
      onDeal: () => unawaited(_deal(notifier)),
      onLeave: () => unawaited(_leave(code)),
      onGoHome: () => ref.invalidate(myTableProvider),
    );
  }

  /// What the lobby's changes mean beyond what it shows: sit down ready; a
  /// deal or a handover moves `/me/table/` on, so it is read again.
  void _follow(
    MyTable table,
    AsyncValue<LobbyState>? before,
    AsyncValue<LobbyState> now,
  ) {
    final lobby = now.value;
    final viewer = _viewer;
    if (lobby == null || viewer == null) return;
    unawaited(
      ref.read(lobbyProvider(table.lobbyCode).notifier).sitDown(viewer),
    );
    final was = before?.value;
    final moved =
        lobby.startedGameId != null &&
        lobby.startedGameId != was?.startedGameId;
    final hostMoved = was != null && was.hostId != lobby.hostId;
    if (moved || hostMoved) ref.invalidate(myTableProvider);
  }

  Future<void> _deal(LobbyNotifier notifier) async {
    setState(() => _dealing = true);
    await notifier.deal();
    if (mounted) setState(() => _dealing = false);
  }

  Future<void> _leave(String code) async {
    setState(() {
      _leaving = true;
      _leaveFailed = false;
    });
    try {
      await ref.read(lobbyProvider(code).notifier).leave();
      ref.invalidate(myTableProvider);
    } catch (_) {
      if (mounted) setState(() => _leaveFailed = true);
    } finally {
      if (mounted) setState(() => _leaving = false);
    }
  }
}

/// Before the table is known: its ground, nothing on it.
class _Ground extends StatelessWidget {
  const _Ground();

  @override
  Widget build(BuildContext context) =>
      const ScreenFrame(ground: GroundKind.night, body: SizedBox.shrink());
}

/// 02 drawn from the lobby as [viewerId] sees it (the component sheet and
/// the gallery draw it too). [link] is the table's join link (none: the
/// code alone); [away] the members whose phones have dropped, dimmed with
/// no words (the lobby body does not say yet; see the README).
class AtTableView extends StatelessWidget {
  const AtTableView({
    super.key,
    required this.lobby,
    required this.viewerId,
    this.link,
    this.away = const {},
    this.dealing = false,
    this.leaving = false,
    this.notSent = false,
    this.onRetry,
    this.onShare,
    this.onEditDeck,
    this.onDeal,
    this.onLeave,
    this.onGoHome,
  });

  final LobbyState lobby;
  final int viewerId;
  final Uri? link;
  final Set<int> away;
  final bool dealing;
  final bool leaving;
  final bool notSent;
  final VoidCallback? onRetry;
  final ValueChanged<Uri>? onShare;
  final VoidCallback? onEditDeck;
  final VoidCallback? onDeal;
  final VoidCallback? onLeave;
  final VoidCallback? onGoHome;

  bool get _host => lobby.hostId == viewerId;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final host = _host;
    final body = Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: Space.md,
      children: [
        if (host)
          _JoinCard(code: lobby.code, link: link, onShare: onShare)
        else
          _GuestHeader(host: lobby.hostName, code: lobby.code),
        for (final player in lobby.players)
          PlayerRow(
            token: player.token,
            name: player.displayName,
            own: player.id == viewerId,
            away: away.contains(player.id),
          ),
        if (host) _DeckPanel(lobby: lobby, onEdit: onEditDeck),
      ],
    );
    return Stack(
      children: [
        ScreenFrame(
          ground: GroundKind.night,
          topArt: skin.art.table,
          topArtLayout: TopArtLayout.banner,
          body: body,
          actions: [
            if (lobby.tableClosed)
              Notice(
                message: BannerCopy.tableClosed,
                action: BannerCopy.goHome,
                onAction: onGoHome,
              )
            else if (notSent)
              Notice(
                message: BannerCopy.notSent,
                action: BannerCopy.tryAgain,
                onAction: onRetry,
              ),
            if (host)
              _dealButton()
            else
              SecondaryButton(
                label: CommonCopy.leave,
                onPressed: leaving ? null : onLeave,
              ),
          ],
        ),
        if (host)
          Positioned(
            top: MediaQuery.paddingOf(context).top + Space.sm,
            left: Space.sm,
            child: _LeaveGlyph(onLeave: leaving ? null : onLeave),
          ),
      ],
    );
  }

  Widget _dealButton() => switch (DealState.of(lobby)) {
    CanDeal(:final players) => PrimaryButton(
      label: TableCopy.deal.fill({'n': players}),
      onPressed: onDeal,
      busy: dealing,
    ),
    NeedPlayers() => const PrimaryButton(
      label: TableCopy.needPlayers,
      onPressed: null,
    ),
    AddCards(:final count) => PrimaryButton(
      label: CommonCopy.addCards.fill({'n': count}),
      onPressed: null,
    ),
    RemoveCards(:final count) => PrimaryButton(
      label: CommonCopy.removeCards.fill({'n': count}),
      onPressed: null,
    ),
  };
}

/// The host's paper, as the mock's code panel: the QR code of the table's
/// link, loudest, on the left; beside it "Scan to join" with Share, and the
/// code in the hero face under them, for whoever types it. Without a link
/// (no web address known) the code alone.
class _JoinCard extends StatelessWidget {
  const _JoinCard({required this.code, this.link, this.onShare});

  final String code;
  final Uri? link;
  final ValueChanged<Uri>? onShare;

  /// The QR code's share of the paper's width.
  static const _qrShare = 0.46;

  @override
  Widget build(BuildContext context) {
    final link = this.link;
    final share = onShare;
    return PaperCard(
      lift: PaperLift.slab,
      padding: const EdgeInsets.all(Space.smPlus),
      child: Builder(
        builder: (context) {
          final type = context.skin.typography;
          final ink = context.ground.text;
          final words = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Expanded(
                    child: Padding(
                      padding: const EdgeInsets.only(top: Space.xs),
                      child: Semantics(
                        header: true,
                        child: FitWords(
                          TableCopy.scan,
                          style: type.title.copyWith(color: ink),
                        ),
                      ),
                    ),
                  ),
                  if (link != null && share != null)
                    IconButton(
                      onPressed: () => share(link),
                      tooltip: TableCopy.share,
                      color: ink,
                      icon: const Icon(Icons.ios_share),
                    ),
                ],
              ),
              const SizedBox(height: Space.sm),
              FitLine(
                code,
                style: type.heroCode.copyWith(color: ink),
                alignment: AlignmentDirectional.centerStart,
              ),
            ],
          );
          if (link == null) return words;
          return LayoutBuilder(
            builder: (context, room) => Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              spacing: Space.md,
              children: [
                QrPicture(
                  data: link.toString(),
                  side: room.maxWidth * _qrShare,
                  semanticLabel: TableCopy.scan,
                ),
                Expanded(child: words),
              ],
            ),
          );
        },
      ),
    );
  }
}

/// A guest's head: whose table it is, and its code in small type.
class _GuestHeader extends StatelessWidget {
  const _GuestHeader({required this.host, required this.code});

  final String host;
  final String code;

  @override
  Widget build(BuildContext context) {
    final type = context.skin.typography;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: Space.xxs,
      children: [
        Semantics(
          header: true,
          child: FitWords(
            TableCopy.hostDeals.fill({'host': host}),
            style: type.screenTitle,
          ),
        ),
        Text(code, style: type.code.copyWith(color: context.ground.text)),
      ],
    );
  }
}

/// The host's deck: its chip, or the custom deck's cards, with "Edit".
class _DeckPanel extends StatelessWidget {
  const _DeckPanel({required this.lobby, this.onEdit});

  final LobbyState lobby;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final type = context.skin.typography;
    final chip = lobby.table.autoDeck ? lobby.table.deckChip : null;
    final cards = {
      for (final MapEntry(:key, :value) in lobby.roleConfig.entries)
        if (RoleId.fromServer(key) case final role? when value > 0) role: value,
    };
    return OutlinePanel(
      onTap: onEdit,
      semanticLabel: TableCopy.editDeck,
      child: Row(
        spacing: Space.smPlus,
        children: [
          Expanded(
            child: chip != null
                ? Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: PresetChip(
                      label: deckChipLabel(chip),
                      selected: true,
                      onTap: null,
                    ),
                  )
                : Row(
                    spacing: Space.sm,
                    children: [
                      for (final MapEntry(key: role, value: count)
                          in cards.entries)
                        Flexible(
                          child: RoleCard(
                            role: role,
                            size: RoleCardSize.thumbSmall,
                            count: count,
                          ),
                        ),
                    ],
                  ),
          ),
          Text(
            TableCopy.editDeck,
            style: type.action.copyWith(color: context.ground.text),
          ),
        ],
      ),
    );
  }
}

/// The host's way out: a glyph over the picture (the screen's words go to
/// the deck and the deal), spoken "Leave".
class _LeaveGlyph extends StatelessWidget {
  const _LeaveGlyph({this.onLeave});

  final VoidCallback? onLeave;

  @override
  Widget build(BuildContext context) {
    final ground = context.ground;
    return Material(
      color: ground.ground,
      shape: const CircleBorder(),
      child: IconButton(
        onPressed: onLeave,
        tooltip: CommonCopy.leave,
        color: ground.text,
        icon: const Icon(Icons.logout),
      ),
    );
  }
}
