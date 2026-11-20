import 'dart:async';
import 'dart:math' as math;

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
import '../../../design_system/primitives/sheet_scaffold.dart';
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

/// 02 Table (first-time play spec, section 3): who is here, and the way to
/// get the others in.
///
/// - Everyone: "Scan to join" over the QR code of the table's link, large and
///   centred, the code under it, Share beside the words (copied, "Copied",
///   only where there is no share sheet); then everyone at the table as a
///   row each, their own outlined, a dropped phone dimmed with no words.
/// - Host: the deck as its chip (and, when the server sends it, the chip's
///   cards face up) or the custom deck's cards, with "Edit" (03); "Deal to
///   {n}", amber, by the server's verdict on dealing ([DealState]); a refused
///   deal says why; a quiet "Leave" that asks first ("Stay" / "Leave"), so
///   one stray tap never hands the table away.
/// - Guest: "{host} deals" over the same code, the rows, and a quiet "Leave"
///   at the end.
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
  var _leaving = false;
  var _leaveFailed = false;
  var _copied = false;

  int? get _viewer => switch (ref.read(authProvider)) {
    AuthAuthenticated(:final user) => user.id,
    _ => null,
  };

  @override
  Widget build(BuildContext context) {
    final table = ref.watch(myTableProvider).value;
    if (table == null) return const _Waiting();
    final code = table.lobbyCode;
    ref.listen(
      lobbyProvider(code),
      (before, now) => _follow(table, before, now),
    );
    final read = ref.watch(lobbyProvider(code));
    final lobby = read.value;
    final viewer = _viewer;
    if (lobby == null || viewer == null) {
      return _Waiting(offline: read.error != null);
    }
    final notifier = ref.read(lobbyProvider(code).notifier);
    // FALLBACK until the server seats members ready (server branch): this
    // phone sets its own flag. Delete with [LobbyNotifier.sitDown].
    if (!lobby.players.any((p) => p.id == viewer && p.isReady)) {
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
      copied: _copied,
      onRetry: () {
        if (_leaveFailed) {
          unawaited(_leave(code));
        } else {
          unawaited(notifier.retry());
        }
      },
      onShare: (link) => unawaited(_share(link)),
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
    // FALLBACK until members are seated ready (server branch).
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

  Future<void> _leave(String code) async {
    setState(() {
      _leaving = true;
      _leaveFailed = false;
      _copied = false;
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

/// Before the table is known: its ground; "One moment" while it cannot be
/// read (it is read again until it answers).
class _Waiting extends StatelessWidget {
  const _Waiting({this.offline = false});

  final bool offline;

  @override
  Widget build(BuildContext context) => ScreenFrame(
    ground: GroundKind.night,
    body: const SizedBox.shrink(),
    actions: [if (offline) const Notice(message: BannerCopy.offline)],
  );
}

/// 02 drawn from the lobby as [viewerId] sees it (the component sheet and
/// the gallery draw it too). [link] is the table's join link (none: the
/// code alone). A member is dimmed when the lobby says their phone dropped,
/// or when in [away] (the component sheet's state).
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
    this.copied = false,
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
  final bool copied;
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
    final refused = lobby.dealRefused;
    return ScreenFrame(
      ground: GroundKind.night,
      topArt: skin.art.table,
      topArtLayout: TopArtLayout.banner,
      body: Builder(
        builder: (context) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: Space.md,
          children: [
            if (!host)
              Semantics(
                header: true,
                child: FitWords(
                  TableCopy.hostDeals.fill({'host': lobby.hostName}),
                  style: skin.typography.screenTitle,
                ),
              ),
            _JoinCard(
              code: lobby.code,
              link: link,
              onShare: onShare,
              headline: host,
            ),
            for (final player in lobby.players)
              PlayerRow(
                token: player.token,
                name: player.displayName,
                own: player.id == viewerId,
                away: player.connected == false || away.contains(player.id),
              ),
            if (host) _DeckPanel(lobby: lobby, onEdit: onEditDeck),
            Align(
              child: SecondaryButton(
                label: CommonCopy.leave,
                size: ButtonSize.compact,
                onPressed: leaving || onLeave == null
                    ? null
                    : host
                    ? () => unawaited(_confirmLeave(context))
                    : onLeave,
              ),
            ),
          ],
        ),
      ),
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
          )
        else if (host && refused != null)
          Notice(message: refused)
        else if (copied)
          const Notice(message: BannerCopy.copied),
        if (host) _dealButton(),
      ],
    );
  }

  /// The host leaves only after saying so again: the table moves to the
  /// next member the moment the host goes.
  Future<void> _confirmLeave(BuildContext context) async {
    final leave = await showSkinSheet<bool>(
      context,
      builder: (sheet) => SheetScaffold(
        actions: [
          Expanded(
            child: SecondaryButton(
              label: TableCopy.stay,
              size: ButtonSize.compact,
              onPressed: () => Navigator.of(sheet).pop(false),
            ),
          ),
          PrimaryButton.quiet(
            label: CommonCopy.leave,
            size: ButtonSize.compact,
            onPressed: () => Navigator.of(sheet).pop(true),
          ),
        ],
        child: const SizedBox.shrink(),
      ),
    );
    if (leave ?? false) onLeave?.call();
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
      label: cardsLabel(count, add: true),
      onPressed: null,
    ),
    RemoveCards(:final count) => PrimaryButton(
      label: cardsLabel(count, add: false),
      onPressed: null,
    ),
  };
}

/// "Add {n} cards" / "Remove {n} cards", one card singular.
String cardsLabel(int count, {required bool add}) => switch ((add, count)) {
  (true, 1) => CommonCopy.addCard,
  (false, 1) => CommonCopy.removeCard,
  (true, _) => CommonCopy.addCards.fill({'n': count}),
  (false, _) => CommonCopy.removeCards.fill({'n': count}),
};

/// The table's paper: "Scan to join" on one line with Share beside it, the
/// QR code of the table's link large and centred (never under
/// [Sizes.qrScannable]), the code under it in the hero face. [headline]:
/// the words are the screen's headline (the host's; a guest's headline is
/// whose table it is). Without a link (no web address known) the code alone.
class _JoinCard extends StatelessWidget {
  const _JoinCard({
    required this.code,
    required this.headline,
    this.link,
    this.onShare,
  });

  final String code;
  final bool headline;
  final Uri? link;
  final ValueChanged<Uri>? onShare;

  @override
  Widget build(BuildContext context) {
    final link = this.link;
    final share = onShare;
    return PaperCard(
      lift: PaperLift.slab,
      padding: const EdgeInsets.fromLTRB(
        Space.lg,
        Space.sm,
        Space.sm,
        Space.md,
      ),
      child: Builder(
        builder: (context) {
          final type = context.skin.typography;
          final ink = context.ground.text;
          return Column(
            spacing: Space.xs,
            children: [
              Row(
                children: [
                  Expanded(
                    child: Semantics(
                      header: headline,
                      child: FitLine(
                        TableCopy.scan,
                        style: type.title.copyWith(color: ink),
                        alignment: AlignmentDirectional.centerStart,
                      ),
                    ),
                  ),
                  if (link != null && share != null)
                    // The skin has no art for sharing: the platform's glyph.
                    IconButton(
                      onPressed: () => share(link),
                      tooltip: TableCopy.share,
                      color: ink,
                      icon: const Icon(Icons.ios_share),
                    ),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(right: Space.sm),
                child: Column(
                  spacing: Space.xs,
                  children: [
                    if (link != null)
                      LayoutBuilder(
                        builder: (context, room) => QrPicture(
                          data: link.toString(),
                          side: math.max(
                            Sizes.qrScannable,
                            math.min(room.maxWidth, Sizes.qrLargest),
                          ),
                          semanticLabel: TableCopy.scan,
                        ),
                      ),
                    FitLine(code, style: type.heroCode.copyWith(color: ink)),
                  ],
                ),
              ),
            ],
          );
        },
      ),
    );
  }
}

/// The host's deck: its chip with "Edit", and the chip's cards face up when
/// the server sends them; or the custom deck's cards with "Edit".
class _DeckPanel extends StatelessWidget {
  const _DeckPanel({required this.lobby, this.onEdit});

  final LobbyState lobby;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final type = context.skin.typography;
    final chip = lobby.table.autoDeck ? lobby.table.deckChip : null;
    final cards =
        lobby.chipCards ??
        (chip != null
            ? const <RoleId, int>{}
            : {
                for (final MapEntry(:key, :value) in lobby.roleConfig.entries)
                  if (RoleId.fromServer(key) case final role? when value > 0)
                    role: value,
              });
    final edit = Text(
      TableCopy.editDeck,
      style: type.action.copyWith(color: context.ground.text),
    );
    return OutlinePanel(
      onTap: onEdit,
      semanticLabel: TableCopy.editDeck,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: Space.smPlus,
        children: [
          if (chip != null)
            Row(
              children: [
                PresetChip(
                  label: deckChipLabel(chip),
                  selected: true,
                  onTap: null,
                ),
                const Spacer(),
                edit,
              ],
            ),
          if (cards.isNotEmpty)
            Row(
              spacing: Space.smPlus,
              children: [
                Expanded(
                  child: Row(
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
                if (chip == null) edit,
              ],
            ),
        ],
      ),
    );
  }
}
