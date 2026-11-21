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
import '../../../design_system/primitives/text_action.dart';
import '../../../design_system/primitives/world_timer.dart';
import '../../../design_system/skin/ground.dart';
import '../../../design_system/skin/skin.dart';
import '../../auth/domain/auth_state.dart';
import '../../auth/presentation/auth_notifier.dart';
import '../../game/presentation/table_screen.dart' show localStepsProvider;
import '../domain/lobby_state.dart';
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
/// - Host: the deck as its chip with its cards face up (the server's
///   `deck_preview`) or the custom deck's cards, with "Edit" (03); "Deal to
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
  String? _leaveRefused;
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
    ref.listen(lobbyProvider(code), _follow);
    final read = ref.watch(lobbyProvider(code));
    final lobby = read.value;
    final viewer = _viewer;
    if (lobby == null || viewer == null) {
      return _Waiting(offline: read.error != null);
    }
    final notifier = ref.read(lobbyProvider(code).notifier);
    final origin = ref.watch(appOriginProvider);
    return AtTableView(
      lobby: lobby,
      viewerId: viewer,
      link: origin == null ? null : joinLink(origin, code),
      dealing: _dealing,
      leaving: _leaving,
      notSent: lobby.notSent || _leaveFailed,
      leaveRefused: _leaveRefused,
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

  /// What the lobby's changes mean beyond what it shows: a deal or a
  /// handover moves `/me/table/` on, so it is read again.
  void _follow(AsyncValue<LobbyState>? before, AsyncValue<LobbyState> now) {
    final lobby = now.value;
    if (lobby == null) return;
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
      _leaveRefused = null;
      _copied = false;
    });
    try {
      await ref.read(lobbyProvider(code).notifier).leave();
      // Off the table: `/me/table/` says where to go (01 Join).
      ref.invalidate(myTableProvider);
    } on LeaveRefused catch (refusal) {
      if (mounted) setState(() => _leaveRefused = refusal.why);
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
    this.leaveRefused,
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

  /// Why the server refused this phone's leave (its words, from copy).
  final String? leaveRefused;
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
    // A table nearly empty is about getting the others in: the picture and
    // the large code. Past that, who is here, the deck and Deal come first.
    final roomy = lobby.players.length <= Sizes.nearlyEmptyTable;
    return ScreenFrame(
      ground: GroundKind.night,
      topArt: roomy ? skin.art.table : null,
      topArtLayout: TopArtLayout.banner,
      body: Builder(
        builder: (context) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: roomy ? Space.md : Space.sm,
          children: [
            // A guest waits for the host: said by the screen's shape, no
            // sentence (playtest: Leave read as the one thing to do). Who
            // deals is the loudest line; Leave is a quiet word at the foot.
            if (!host)
              Semantics(
                header: true,
                child: FitWords(
                  TableCopy.hostDeals.fill({'host': lobby.hostName}),
                  style: skin.typography.heroTitle,
                ),
              ),
            _JoinCard(
              code: lobby.code,
              link: link,
              onShare: onShare,
              headline: host,
              compact: !roomy,
            ),
            _Rows(
              names: [for (final p in lobby.players) p.displayName],
              rows: [
                for (final player in lobby.players)
                  _Row(
                    player: player,
                    own: player.id == viewerId,
                    // This phone is here: its own row is never dimmed.
                    away:
                        player.id != viewerId &&
                        (!player.connected || away.contains(player.id)),
                  ),
              ],
              spacing: roomy ? Space.md : Space.xs,
            ),
            if (host) ...[
              _DeckPanel(lobby: lobby, onEdit: onEditDeck),
              Align(
                child: SecondaryButton(
                  label: CommonCopy.leave,
                  size: ButtonSize.compact,
                  onPressed: leaving || onLeave == null
                      ? null
                      : () => unawaited(_confirmLeave(context)),
                ),
              ),
            ],
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
        else if (leaveRefused case final why?)
          Notice(message: why)
        else if (notSent)
          Notice(
            message: BannerCopy.notSent,
            action: BannerCopy.tryAgain,
            onAction: onRetry,
          )
        // The button already says it when the table's new verdict agrees.
        else if (host && refused != null && refused != _dealWords())
          Notice(message: refused)
        else if (copied)
          const Notice(message: BannerCopy.copied),
        if (host)
          _dealButton()
        else
          Center(
            child: TextAction(
              label: CommonCopy.leave,
              onPressed: leaving ? null : onLeave,
            ),
          ),
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

  /// The deal button's words, from the server's verdict ([DealState]).
  String _dealWords() => switch (DealState.of(lobby)) {
    CanDeal(:final players) => TableCopy.deal.fill({'n': players}),
    // The same words, locked, until everyone it is set for is here.
    WaitingFor(:final seats) => TableCopy.deal.fill({'n': seats}),
    NeedPlayers() => TableCopy.needPlayers,
    // The deck shows what is wrong; the button keeps its words.
    DeckDoesNotFit() => TableCopy.deal.fill({'n': lobby.players.length}),
    CannotDeal() => BannerCopy.cannotDeal,
  };

  /// "Deal to {n}", amber, only when the server says the deal would go.
  Widget _dealButton() => PrimaryButton(
    label: _dealWords(),
    onPressed: DealState.of(lobby) is CanDeal ? onDeal : null,
    busy: dealing,
  );
}

/// Everyone at the table, a row each; from [Sizes.twoUpPlayers] on, two to
/// a line, so the deck and Deal stay in view, where each half still has
/// [Sizes.playerColumn] and every name ([names]) fits its half at the
/// caption floor (names wrap between words or are set smaller, never cut,
/// never under the floor).
class _Rows extends StatelessWidget {
  const _Rows({required this.names, required this.rows, required this.spacing});

  final List<String> names;
  final List<Widget> rows;
  final double spacing;

  /// The widest word of [names] in the rows' name face at the caption floor.
  double _widestWord(BuildContext context) {
    final style = PlayerRowSize.compact
        .nameStyle(context.skin.typography)
        .copyWith(fontSize: ReadingFloor.caption);
    final scaler = MediaQuery.textScalerOf(context);
    var widest = 0.0;
    for (final word in names.expand((n) => n.split(' '))) {
      final painter = TextPainter(
        text: TextSpan(text: word, style: style),
        textScaler: scaler,
        maxLines: 1,
        textDirection: TextDirection.ltr,
      )..layout();
      if (painter.width > widest) widest = painter.width;
      painter.dispose();
    }
    return widest;
  }

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, room) {
      final half = (room.maxWidth - Space.xs) / 2;
      const size = PlayerRowSize.compact;
      final nameRoom =
          half - Space.sm - size.token.size - size.gap - size.endPadding;
      if (rows.length < Sizes.twoUpPlayers ||
          half < Sizes.playerColumn ||
          _widestWord(context) > nameRoom) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: spacing,
          children: rows,
        );
      }
      return Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: spacing,
        children: [
          for (var i = 0; i < rows.length; i += 2)
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: Space.xs,
              children: [
                Expanded(child: rows[i]),
                Expanded(
                  child: i + 1 < rows.length
                      ? rows[i + 1]
                      : const SizedBox.shrink(),
                ),
              ],
            ),
        ],
      );
    },
  );
}

/// A member's row; a dropped phone's whole row dimmed (its token more),
/// with no words, so it reads at a glance.
class _Row extends StatelessWidget {
  const _Row({required this.player, required this.own, required this.away});

  final LobbyPlayer player;
  final bool own;
  final bool away;

  @override
  Widget build(BuildContext context) {
    final row = PlayerRow(
      token: player.token,
      name: player.displayName,
      own: own,
      away: away,
    );
    if (!away) return row;
    // A sixth of the way from present to the skin's switched-off (its token
    // more): the row reads as away, its name still at the reading contrast.
    return Opacity(opacity: 1 - (1 - context.skin.dimmed) / 6, child: row);
  }
}

/// The table's paper: "Scan to join" with Share beside it, the QR code of
/// the table's link (never under [Sizes.qrScannable]) and the code in the
/// hero face. Nearly empty ([compact] false): the QR code large and centred,
/// the code under it. Past that, the card is as short as it can be: the QR
/// code at its scannable least on the left, the words, Share and the code
/// beside it; where that leaves the code too little room (a narrow phone),
/// stacked, the QR code still at its least. [headline]: the words are the
/// screen's headline (the host's; a guest's headline is whose table it is).
/// Without a link (no web address known) the code alone.
class _JoinCard extends StatelessWidget {
  const _JoinCard({
    required this.code,
    required this.headline,
    required this.compact,
    this.link,
    this.onShare,
  });

  final String code;
  final bool headline;
  final bool compact;
  final Uri? link;
  final ValueChanged<Uri>? onShare;

  @override
  Widget build(BuildContext context) {
    final link = this.link;
    final share = onShare;
    return PaperCard(
      lift: PaperLift.slab,
      padding: compact
          ? const EdgeInsets.fromLTRB(Space.md, Space.sm, Space.xs, Space.sm)
          : const EdgeInsets.fromLTRB(Space.lg, Space.sm, Space.sm, Space.md),
      child: Builder(
        builder: (context) {
          final type = context.skin.typography;
          final ink = context.ground.text;
          final scan = Semantics(
            header: headline,
            child: FitLine(
              TableCopy.scan,
              style: type.title.copyWith(color: ink),
              alignment: AlignmentDirectional.centerStart,
            ),
          );
          final shareButton = link == null || share == null
              ? null
              // The skin has no art for sharing: the platform's glyph.
              : IconButton(
                  onPressed: () => share(link),
                  tooltip: TableCopy.share,
                  color: ink,
                  icon: const Icon(Icons.ios_share),
                );
          // "Scan to join" belongs to the QR code alone: with no link (no
          // web address known) there is nothing to scan, and the six letters
          // are a code to type, labelled as 01 asks for it ("Code").
          final words = Row(
            children: [
              Expanded(child: link == null ? const SizedBox.shrink() : scan),
              ?shareButton,
            ],
          );
          final theCode = _CodeLine(code: code, centred: !compact);
          QrPicture qr(double side) => QrPicture(
            data: link.toString(),
            side: side,
            semanticLabel: TableCopy.scan,
          );
          return LayoutBuilder(
            builder: (context, room) {
              // The words beside the QR code need their room at the
              // player's text size.
              final beside =
                  room.maxWidth - Sizes.qrScannable - Space.md >=
                  MediaQuery.textScalerOf(context).scale(Sizes.joinCodeBeside);
              if (link != null && compact && beside) {
                return Row(
                  spacing: Space.md,
                  children: [
                    qr(Sizes.qrScannable),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        spacing: Space.xs,
                        children: [
                          scan,
                          theCode,
                          if (shareButton != null)
                            Align(
                              alignment: AlignmentDirectional.centerStart,
                              child: shareButton,
                            ),
                        ],
                      ),
                    ),
                  ],
                );
              }
              return Column(
                spacing: Space.xs,
                children: [
                  words,
                  Padding(
                    padding: const EdgeInsets.only(right: Space.sm),
                    child: Column(
                      spacing: Space.xs,
                      children: [
                        if (link != null)
                          qr(
                            compact
                                ? Sizes.qrScannable
                                : math.max(
                                    Sizes.qrScannable,
                                    math.min(room.maxWidth, Sizes.qrLargest),
                                  ),
                          ),
                        theCode,
                      ],
                    ),
                  ),
                ],
              );
            },
          );
        },
      ),
    );
  }
}

/// The table's code to type, after its label ("Code", the word 01's field
/// asks for), in the hero face: centred under a large QR code, else from the
/// start.
class _CodeLine extends StatelessWidget {
  const _CodeLine({required this.code, required this.centred});

  final String code;
  final bool centred;

  @override
  Widget build(BuildContext context) {
    final type = context.skin.typography;
    final ink = context.ground.text;
    final line = Row(
      mainAxisSize: centred ? MainAxisSize.min : MainAxisSize.max,
      crossAxisAlignment: CrossAxisAlignment.baseline,
      textBaseline: TextBaseline.alphabetic,
      spacing: Space.sm,
      children: [
        Text(JoinCopy.codeHint, style: type.caption.copyWith(color: ink)),
        Flexible(
          child: FitLine(
            code,
            style: type.heroCode.copyWith(color: ink),
            alignment: AlignmentDirectional.centerStart,
          ),
        ),
      ],
    );
    return centred ? Center(child: line) : line;
  }
}

/// The host's deck: its chip with "Edit" and the chip's cards face up (none
/// for a count with no automatic deck); or the custom deck's cards with
/// "Edit".
class _DeckPanel extends StatelessWidget {
  const _DeckPanel({required this.lobby, this.onEdit});

  final LobbyState lobby;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final type = context.skin.typography;
    final chip = lobby.table.autoDeck ? lobby.table.deckChip : null;
    final pace = lobby.table.pace;
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
          if (chip != null || pace != null)
            Row(
              spacing: Space.sm,
              children: [
                if (chip != null)
                  PresetChip(
                    label: deckChipLabel(chip),
                    selected: true,
                    onTap: null,
                  ),
                // The pace chosen on 03, by the talk it gives (02 keeps to
                // its 8 words: the length is digits).
                if (pace != null)
                  PresetChip(
                    label: WorldTimer.format(pace.talk),
                    selected: true,
                    onTap: null,
                  ),
                const Spacer(),
                if (chip != null) edit,
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
