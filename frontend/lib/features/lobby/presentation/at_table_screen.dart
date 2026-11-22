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
import '../../../design_system/skin/ground.dart';
import '../../../design_system/skin/skin.dart';
import '../../auth/domain/auth_state.dart';
import '../../auth/presentation/auth_notifier.dart';
import '../../game/presentation/live_game.dart' show liveGameProvider;
import '../../game/presentation/table_screen.dart' show localStepsProvider;
import '../domain/lobby_state.dart';
import 'deck_screen.dart'
    show DeckCount, deckChipLabel, lengthText, minSeats, showRoleSheet;
import 'seats_line.dart';
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
      onPlayWith: (players) {
        unawaited(notifier.setSeats(players));
        // A deck of the host's own was built for more: 03, its count
        // showing, so the host fixes it (never thrown away).
        if (!lobby.table.autoDeck) {
          ref.read(localStepsProvider.notifier).openDeck(table);
        }
      },
      onDeal: () => unawaited(_deal(notifier)),
      onLeave: () => unawaited(_leave(code)),
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
    this.onPlayWith,
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

  /// Fewer came: the host plays with who is here ("Play with {n}").
  final ValueChanged<int>? onPlayWith;
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
    final present = lobby.players.length;
    final seats = lobby.table.seats;
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
                  style: skin.typography.headline,
                ),
              ),
            _JoinCard(
              code: lobby.code,
              link: link,
              onShare: onShare,
              headline: host,
              // Set for a number there is more to show (the places, the
              // deck): the QR code at its scannable least.
              compact: !roomy || seats != null,
            ),
            // At a number: who is here of it, an empty circle for each place
            // not taken (compact, so the deck and Leave stay in view).
            if (seats != null)
              Padding(
                padding: const EdgeInsets.only(top: Space.sm),
                child: SeatsLine(
                  present: present,
                  seats: seats,
                  dots: SeatDots.empty,
                ),
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
              spacing: roomy ? Space.md : Space.sm,
            ),
            // Fewer came: one tap sets the number to who is here.
            if (host && seats != null && present >= minSeats && present < seats)
              Align(
                child: SecondaryButton(
                  label: TableCopy.playWith.fill({'n': present}),
                  size: ButtonSize.compact,
                  onPressed: onPlayWith == null
                      ? null
                      : () => onPlayWith!(present),
                ),
              ),
            // The game as set up, face up for everyone; the host's opens 03.
            _SetupPanel(lobby: lobby, host: host, onEdit: onEditDeck),
            if (host)
              Align(
                child: SecondaryButton(
                  label: CommonCopy.leave,
                  size: ButtonSize.compact,
                  busy: leaving,
                  onPressed: onLeave == null
                      ? null
                      : () => unawaited(_confirmLeave(context)),
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
              busy: leaving,
              onPressed: onLeave,
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
/// reading floor (names wrap between words or are set smaller, never cut,
/// never under the floor).
class _Rows extends StatelessWidget {
  const _Rows({required this.names, required this.rows, required this.spacing});

  final List<String> names;
  final List<Widget> rows;
  final double spacing;

  /// The least a name is set at in two-up rows: the reading floor, so the
  /// names stay readable and one size (past that, one row each).
  static const _least = ReadingFloor.act;

  /// The widest word of [names] in the rows' name face at [size].
  double _widestWord(BuildContext context, double size) {
    final style = PlayerRowSize.lobby
        .nameStyle(context.skin.typography)
        .copyWith(fontSize: size);
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
      const size = PlayerRowSize.lobby;
      final nameRoom =
          half - Space.sm - size.token.size - size.gap - size.endPadding;
      // The size every name is set at: the role's own, or smaller where the
      // longest word needs it (a word's width is in step with the size).
      final own = size.nameSize!;
      final widest = _widestWord(context, own);
      final fitted = widest > nameRoom ? own * nameRoom / widest * 0.99 : own;
      if (rows.length < Sizes.twoUpPlayers ||
          half < Sizes.playerColumn ||
          fitted < _least) {
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: spacing,
          children: rows,
        );
      }
      return PlayerNameSize(
        size: fitted,
        child: Column(
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
        ),
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
      size: PlayerRowSize.lobby,
      own: own,
      away: away,
    );
    if (!away) return row;
    // A sixth of the way from present to the skin's switched-off (its token
    // more): the row reads as away, its name still at the reading contrast.
    return Opacity(opacity: 1 - (1 - context.skin.dimmed) / 6, child: row);
  }
}

/// The table's paper, two blocks: the QR code of the table's link with
/// "Scan to join" on it (its label, nothing else's), and the code to type
/// with its own label ("Code", 01's word) and Share. Nearly empty ([compact]
/// false): the QR code large and centred over the code. Past that, as short as
/// it can be: the QR code at its scannable least beside the code, or over it
/// where the code would have too little room (a narrow phone). [headline]:
/// "Scan to join" is the screen's headline (the host's). Without a link (no
/// web address known): the code alone.
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
      padding: const EdgeInsets.symmetric(
        horizontal: Space.md,
        vertical: Space.sm,
      ),
      child: Builder(
        builder: (context) {
          final type = context.skin.typography;
          final ink = context.ground.text;
          final shareButton = link == null || share == null
              ? null
              // The skin has no art for sharing: the platform's glyph.
              : IconButton(
                  onPressed: () => share(link),
                  tooltip: TableCopy.share,
                  color: ink,
                  icon: const Icon(Icons.ios_share),
                );
          final codeOnly = Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(JoinCopy.codeHint, style: type.caption.copyWith(color: ink)),
              FitLine(
                code,
                style: type.heroCode.copyWith(color: ink),
                alignment: AlignmentDirectional.centerStart,
              ),
            ],
          );
          final codeBlock = Row(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Expanded(child: codeOnly),
              ?shareButton,
            ],
          );
          if (link == null) return codeBlock;
          // Wraps between words beside a small QR code, never set small.
          final scan = Semantics(
            header: headline,
            child: FitWords(
              TableCopy.scan,
              style: type.action.copyWith(color: ink),
            ),
          );
          Widget qrBlock(double side) => SizedBox(
            width: side,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              spacing: Space.xs,
              children: [
                QrPicture(
                  data: link.toString(),
                  side: side,
                  semanticLabel: TableCopy.scan,
                ),
                Semantics(
                  header: headline,
                  child: FitLine(
                    TableCopy.scan,
                    style: type.action.copyWith(color: ink),
                  ),
                ),
              ],
            ),
          );
          final divider = Container(
            height: context.skin.shape.stroke,
            color: context.ground.hairline,
          );
          return LayoutBuilder(
            builder: (context, room) {
              final beside =
                  room.maxWidth - Sizes.qrScannable - Space.md >=
                  MediaQuery.textScalerOf(context).scale(Sizes.joinCodeBeside);
              if (compact && beside) {
                // Short: "Scan to join" at the QR code's edge, beside it; a
                // hairline, then the code block.
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  spacing: Space.md,
                  children: [
                    QrPicture(
                      data: link.toString(),
                      side: Sizes.qrScannable,
                      semanticLabel: TableCopy.scan,
                    ),
                    Expanded(
                      child: SizedBox(
                        height: Sizes.qrScannable,
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.stretch,
                          mainAxisAlignment: MainAxisAlignment.spaceBetween,
                          // Share beside the words of the link it shares, so
                          // the code has the column's whole width.
                          children: [
                            Row(
                              children: [
                                Expanded(child: scan),
                                ?shareButton,
                              ],
                            ),
                            divider,
                            codeOnly,
                          ],
                        ),
                      ),
                    ),
                  ],
                );
              }
              final side = compact
                  ? Sizes.qrScannable
                  : math.max(
                      Sizes.qrScannable,
                      math.min(room.maxWidth, Sizes.qrLargest),
                    );
              return Column(
                spacing: Space.md,
                children: [qrBlock(side), divider, codeBlock],
              );
            },
          );
        },
      ),
    );
  }
}

/// The game as set up, the same for everyone at the table: the chip (an
/// automatic deck) and the talk's length, then every role in the deck face
/// up with its count, in [deckOrder] (a tap or a hold reads it, 03b). The
/// host's opens 03 ("Edit"), and shows a deck that does not hold the cards
/// the deal needs ([DeckCount]; a guest never sees it).
class _SetupPanel extends StatelessWidget {
  const _SetupPanel({required this.lobby, required this.host, this.onEdit});

  final LobbyState lobby;
  final bool host;
  final VoidCallback? onEdit;

  @override
  Widget build(BuildContext context) {
    final type = context.skin.typography;
    final ink = context.ground.text;
    final chip = lobby.table.autoDeck ? lobby.table.deckChip : null;
    final talk = lobby.secondsOf(Length.talk);
    final cards = lobby.tableCards;
    final seats = lobby.table.seats;
    final need = lobby.cardsNeeded;
    final picked = lobby.pickedCards;
    final edit = host ? onEdit : null;
    void read(RoleId role) => unawaited(showRoleSheet(context, role));
    return OutlinePanel(
      onTap: edit,
      semanticLabel: edit == null ? null : TableCopy.editDeck,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: Space.smPlus,
        children: [
          Row(
            spacing: Space.sm,
            children: [
              if (chip != null)
                PresetChip(
                  label: deckChipLabel(chip),
                  selected: true,
                  onTap: null,
                ),
              // The talk's length: the room left, wrapping between words.
              Expanded(
                child: talk == null
                    ? const SizedBox.shrink()
                    : FitWords(
                        '${DeckCopy.talk} ${lengthText(talk, Length.talk)}',
                        style: type.action.copyWith(color: ink),
                      ),
              ),
              if (edit != null)
                Text(
                  TableCopy.editDeck,
                  style: type.action.copyWith(color: ink),
                ),
            ],
          ),
          if (host && seats != null && need != null && picked != need)
            DeckCount(picked: picked, need: need, seats: seats),
          if (cards.isNotEmpty) _DeckStrip(cards: cards, onRead: read),
        ],
      ),
    );
  }
}

/// The deck's cards face up as thumbnails, in balanced lines: one line
/// while the cards fit it at [Sizes.thumbLeast] of their size (they shrink to
/// share it), else as few lines as fit, the cards shared evenly, so no card
/// sits alone on a line of its own.
class _DeckStrip extends StatelessWidget {
  const _DeckStrip({required this.cards, required this.onRead});

  final Map<RoleId, int> cards;
  final ValueChanged<RoleId> onRead;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, room) {
      const gap = Space.sm;
      final least = RoleCardSize.thumbSmall.thumbnail!.width * Sizes.thumbLeast;
      final entries = cards.entries.toList();
      final fit = math.max(1, ((room.maxWidth + gap) / (least + gap)).floor());
      final lines = (entries.length / fit).ceil();
      final perLine = (entries.length / lines).ceil();
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: gap,
        children: [
          for (var i = 0; i < entries.length; i += perLine)
            Row(
              spacing: gap,
              children: [
                for (final MapEntry(key: role, value: count) in entries.sublist(
                  i,
                  math.min(i + perLine, entries.length),
                ))
                  Flexible(
                    child: RoleCard(
                      role: role,
                      size: RoleCardSize.thumbSmall,
                      count: count,
                      onTap: () => onRead(role),
                      onLongPress: () => onRead(role),
                    ),
                  ),
              ],
            ),
        ],
      );
    },
  );
}
