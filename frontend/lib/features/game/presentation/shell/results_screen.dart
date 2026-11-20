import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design_system/copy/copy.dart';
import '../../../../design_system/faces/face_content.dart' show nameList;
import '../../../../design_system/layout/space.dart';
import '../../../../design_system/models/role.dart';
import '../../../../design_system/primitives/band.dart';
import '../../../../design_system/primitives/fit_line.dart';
import '../../../../design_system/primitives/notice.dart';
import '../../../../design_system/primitives/player_token.dart';
import '../../../../design_system/primitives/primary_button.dart';
import '../../../../design_system/primitives/role_card.dart';
import '../../../../design_system/primitives/screen_frame.dart';
import '../../../../design_system/primitives/secondary_button.dart';
import '../../../../design_system/primitives/tag_chip.dart';
import '../../../../design_system/skin/ground.dart';
import '../../../../design_system/skin/skin.dart';
import '../../../lobby/domain/where_am_i.dart';
import '../../../lobby/presentation/where_am_i_provider.dart';
import '../../domain/game_outcome.dart';
import '../../domain/outcome_view.dart';
import '../live_game.dart';
import '../table_screen.dart';
import 'count_screen.dart' show EndWaiting;

/// 11 Results (first-time play spec, section 3), wired to the game: the
/// results body drawn by [ResultsView], for this phone ([GameMe.playerId])
/// and its place at the table (host or not, from `/me/`).
///
/// - Host: "Play again" takes the table back to waiting (every phone then
///   goes to 02, by `/me/table/`); "Edit deck" does that and opens 03 on
///   this phone. Guest: "{host} deals next." and "Leave" (to 01).
/// - A request that fails: "Not sent." with "Try again"; nothing moves until
///   the server says the table did.
/// - Until the results arrive: the night's ground, and "One moment" while
///   their fetch is failing.
class ResultsScreen extends ConsumerStatefulWidget {
  const ResultsScreen({super.key, required this.gameId, required this.game});

  final String gameId;
  final LiveGame? game;

  @override
  ConsumerState<ResultsScreen> createState() => _ResultsScreenState();
}

enum _Act { playAgain, editDeck, leave }

class _ResultsScreenState extends ConsumerState<ResultsScreen> {
  _Act? _busy;
  _Act? _failed;

  LiveGameNotifier get _notifier =>
      ref.read(liveGameProvider(widget.gameId).notifier);

  Future<void> _run(_Act act) async {
    if (_busy != null) return;
    setState(() {
      _busy = act;
      _failed = null;
    });
    try {
      switch (act) {
        case _Act.playAgain:
          await _notifier.playAgain();
        case _Act.editDeck:
          // Read before the table moves on: this screen goes with it.
          final container = ProviderScope.containerOf(context, listen: false);
          await _notifier.playAgain();
          final table = await container.read(myTableProvider.future);
          if (table != null && table.status == TableStatus.waiting) {
            container.read(localStepsProvider.notifier).openDeck(table);
          }
        case _Act.leave:
          await _notifier.leaveTable();
      }
    } catch (_) {
      if (mounted) setState(() => _failed = act);
    } finally {
      if (mounted) setState(() => _busy = null);
    }
  }

  @override
  Widget build(BuildContext context) {
    final game = widget.game;
    final outcome = game?.outcome;
    if (game == null || outcome == null) {
      return EndWaiting(
        ground: GroundKind.night,
        failing: game?.outcomeFailing ?? false,
      );
    }
    final me = game.me;
    return ResultsView(
      outcome: outcome,
      viewerId: me.playerId,
      host: me.isHost,
      // The host's name from the table; none when it is not there (then
      // nothing is said about who deals).
      hostName: me.seats.where((s) => s.id == me.hostId).firstOrNull?.name,
      busy: _busy != null,
      failed: _failed != null,
      onPlayAgain: () => unawaited(_run(_Act.playAgain)),
      onEditDeck: () => unawaited(_run(_Act.editDeck)),
      onLeave: () => unawaited(_run(_Act.leave)),
      onTryAgain: () => unawaited(_run(_failed ?? _Act.playAgain)),
    );
  }
}

/// 11 Results, from the results body: who won (the band: the winners'
/// portrait, the headline, "You won." / "You lost."), then everyone's card at
/// the end (the dealt one before it where it moved) with "Won" or "Died",
/// one line each where they fit, and the center; then the night, open:
/// where each Werewolf card went (the red line, headed by the Werewolf's
/// portrait: "Cara → Bob"; the line that teaches a newcomer the cards
/// move), then a line per step ("Robber: Ben takes Dev's card.", with the
/// cards the step showed), arriving one after another ([Motion.stagger]; a
/// tap finishes them, reduce motion shows them at once), each on a spine
/// that is red where a werewolf card was looked at or moved; a tap on the
/// red line folds the steps away (and opens them again); on a big table it
/// continues under the fade above the buttons. Red is the server's
/// `werewolf` flag on a card, everywhere. Everything is the server's: the winners, each player's
/// outcome, team and cards, the timeline.
///
/// [host]: "Play again" and "Edit deck", side by side, or stacked when a
/// label would not fit on one line. A guest: "{host} deals next." (when the
/// host is at the table) and "Leave".
class ResultsView extends StatefulWidget {
  const ResultsView({
    super.key,
    required this.outcome,
    required this.viewerId,
    required this.host,
    required this.hostName,
    required this.onPlayAgain,
    required this.onEditDeck,
    required this.onLeave,
    required this.onTryAgain,
    this.busy = false,
    this.failed = false,
  });

  final GameOutcome outcome;
  final int viewerId;
  final bool host;
  final String? hostName;
  final VoidCallback onPlayAgain;
  final VoidCallback onEditDeck;
  final VoidCallback onLeave;
  final VoidCallback onTryAgain;

  /// A request is on its way.
  final bool busy;

  /// The last request got no answer.
  final bool failed;

  @override
  State<ResultsView> createState() => _ResultsViewState();
}

class _ResultsViewState extends State<ResultsView>
    with SingleTickerProviderStateMixin {
  late final Winners _winners = Winners.of(widget.outcome.result.winningTeams);
  late final List<EndSeat> _seats = endSeatsOf(widget.outcome);
  late final List<NightLine> _lines = nightLinesOf(widget.outcome);
  late final List<WerewolfPath> _paths = werewolfPathsOf(widget.outcome);
  late final AnimationController _landing;
  var _open = true;

  @override
  void initState() {
    super.initState();
    _landing = AnimationController(
      vsync: this,
      duration: Motion.stagger * _lines.length + Motion.settle,
    );
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_landing.isAnimating || _landing.isCompleted) return;
    _land();
  }

  void _land() {
    if (MediaQuery.disableAnimationsOf(context)) {
      _landing.value = 1;
    } else {
      unawaited(_landing.forward(from: 0));
    }
  }

  @override
  void dispose() {
    _landing.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _open = !_open);
    if (_open) _land();
  }

  void _finish() {
    if (_landing.isAnimating) _landing.value = 1;
  }

  /// 0 to 1 as line [i] lands.
  double _phase(int i) {
    final total = _landing.duration!.inMicroseconds;
    final start = (Motion.stagger * i).inMicroseconds / total;
    final length = Motion.settle.inMicroseconds / total;
    return ((_landing.value - start) / length).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final type = context.skin.typography;
    final you = _seats.where((s) => s.seat.id == widget.viewerId).firstOrNull;
    final center = widget.outcome.result.centerCards;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: _finish,
      child: ScreenFrame(
        ground: GroundKind.night,
        topSlot: Band(
          tone: _winners.werewolvesWon ? BandTone.danger : BandTone.night,
          child: _Winner(winners: _winners, you: you),
        ),
        body: Builder(
          builder: (context) => Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // What everyone looks for first: each player's card at the
              // end, and who won or died.
              for (final seat in _seats)
                _EndRow(seat, own: seat.seat.id == widget.viewerId),
              const SizedBox(height: Space.sm),
              Text(
                ResultsCopy.center.fill({
                  'roles': nameList(center.map((r) => r.displayName)),
                }),
                style: type.body.copyWith(color: context.ground.quietText),
              ),
              if (_lines.isNotEmpty) ...[
                const SizedBox(height: Space.lg),
                _NightHead(
                  paths: _paths,
                  lines: _lines,
                  open: _open,
                  onTap: _toggle,
                ),
                if (_open)
                  AnimatedBuilder(
                    animation: _landing,
                    builder: (context, _) => Column(
                      crossAxisAlignment: CrossAxisAlignment.stretch,
                      children: [
                        for (final (i, line) in _lines.indexed)
                          _LineLanding(t: _phase(i), child: _Line(line)),
                      ],
                    ),
                  ),
              ],
            ],
          ),
        ),
        actions: _actions(context),
      ),
    );
  }

  List<Widget> _actions(BuildContext context) {
    final type = context.skin.typography;
    final hostName = widget.hostName;
    return [
      if (widget.failed)
        Notice(
          message: BannerCopy.notSent,
          action: BannerCopy.tryAgain,
          onAction: widget.onTryAgain,
        ),
      if (widget.host)
        _HostButtons(
          busy: widget.busy,
          onPlayAgain: widget.onPlayAgain,
          onEditDeck: widget.onEditDeck,
        )
      else ...[
        if (hostName != null)
          Text(
            ResultsCopy.hostDealsNext.fill({'host': hostName}),
            textAlign: TextAlign.center,
            style: type.body.copyWith(color: context.ground.text),
          ),
        SecondaryButton(
          label: CommonCopy.leave,
          onPressed: widget.busy ? null : widget.onLeave,
        ),
      ],
    ];
  }
}

/// The host's two buttons: side by side when both labels fit on one line,
/// else "Play again" full width and "Edit deck" under it (a primary label
/// never wraps).
class _HostButtons extends StatelessWidget {
  const _HostButtons({
    required this.busy,
    required this.onPlayAgain,
    required this.onEditDeck,
  });

  final bool busy;
  final VoidCallback onPlayAgain;
  final VoidCallback onEditDeck;

  /// [text]'s one-line width in [style] at this phone's text size.
  static double _width(BuildContext context, String text, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textDirection: Directionality.of(context),
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width;
  }

  @override
  Widget build(BuildContext context) {
    final type = context.skin.typography;
    final play = PrimaryButton(
      label: ResultsCopy.playAgain,
      onPressed: onPlayAgain,
      busy: busy,
      size: ButtonSize.large,
    );
    final edit = SecondaryButton(
      label: ResultsCopy.editDeck,
      onPressed: busy ? null : onEditDeck,
      size: ButtonSize.large,
    );
    return LayoutBuilder(
      builder: (context, room) {
        final half = (room.maxWidth - Space.md) / 2;
        // Each label with its button's own inset and edge.
        final playNeeds =
            _width(
              context,
              ResultsCopy.playAgain,
              ButtonSize.large.label(type),
            ) +
            2 * (Space.xl + context.skin.shape.selectedRing);
        final editNeeds =
            _width(context, ResultsCopy.editDeck, type.action) +
            2 * (Space.lg + context.skin.shape.selectedRing);
        if (playNeeds <= half && editNeeds <= half) {
          return Row(
            spacing: Space.md,
            children: [
              Expanded(child: play),
              Expanded(child: edit),
            ],
          );
        }
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: Space.md,
          children: [play, edit],
        );
      },
    );
  }
}

/// The band: the winners' portrait, who won, and this phone's own result.
class _Winner extends StatelessWidget {
  const _Winner({required this.winners, required this.you});

  final Winners winners;
  final EndSeat? you;

  @override
  Widget build(BuildContext context) {
    final type = context.skin.typography;
    final portrait = winners.portrait;
    final words = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      mainAxisSize: MainAxisSize.min,
      spacing: Space.md,
      children: [
        Semantics(
          header: true,
          child: FitWords(winners.headline, style: type.heroWinner),
        ),
        if (you case final you?)
          Text(
            you.won ? ResultsCopy.youWon : ResultsCopy.youLost,
            style: type.title.copyWith(color: context.ground.text),
          ),
      ],
    );
    if (portrait == null) return words;
    return LayoutBuilder(
      builder: (context, room) => Row(
        crossAxisAlignment: CrossAxisAlignment.end,
        spacing: Space.lg,
        children: [
          RolePortrait.arched(
            role: portrait,
            width: math.min(
              RolePortrait.winner,
              room.maxWidth * RolePortrait.winnerShare,
            ),
          ),
          Expanded(child: words),
        ],
      ),
    );
  }
}

/// One player at the end: token, name, their card (the dealt one before it
/// where it moved), and "Won" / "Died". The viewer's own row sits on a
/// panel.
class _EndRow extends StatelessWidget {
  const _EndRow(this.seat, {required this.own});

  final EndSeat seat;
  final bool own;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final type = skin.typography;
    final ground = context.ground;
    final copied = seat.copied;
    final card = copied == null
        ? seat.now.displayName
        : ResultsCopy.copiedAs.fill({
            'role': seat.now.displayName,
            'copied': copied.displayName,
          });
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: Space.sm,
        vertical: Space.xs,
      ),
      decoration: own
          ? BoxDecoration(
              color: ground.panel,
              borderRadius: BorderRadius.circular(skin.shape.radius),
            )
          : null,
      child: Row(
        spacing: Space.md,
        children: [
          PlayerToken(seat.seat.token, size: TokenSize.card),
          // The name, then the card (the dealt one before it where it
          // moved), on one line where they fit; the card wraps under the
          // name where they do not.
          Expanded(
            child: Wrap(
              spacing: Space.sm,
              runSpacing: Space.xxs,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                FitWords(
                  seat.seat.name,
                  maxLines: 2,
                  style: type.name.copyWith(color: ground.text),
                ),
                Wrap(
                  spacing: Space.xs,
                  runSpacing: Space.xxs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    if (seat.moved) ...[
                      FitWords(
                        seat.dealt.displayName,
                        style: type.body.copyWith(
                          color: seat.werewolfDealt
                              ? ground.dangerText
                              : ground.quietText,
                        ),
                      ),
                      Icon(
                        Icons.arrow_forward,
                        size: type.body.fontSize,
                        color: ground.quietText,
                      ),
                    ],
                    _CardChip(card, werewolf: seat.werewolfNow),
                  ],
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            mainAxisSize: MainAxisSize.min,
            children: [
              if (seat.won)
                Text(
                  ResultsCopy.won,
                  style: type.action.copyWith(color: ground.text),
                ),
              if (seat.died)
                Text(
                  ResultsCopy.died,
                  style: type.action.copyWith(color: ground.dangerText),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

/// A card's role as a chip: red for a werewolf card (the server's flag).
class _CardChip extends StatelessWidget {
  const _CardChip(this.text, {required this.werewolf});

  final String text;
  final bool werewolf;

  @override
  Widget build(BuildContext context) =>
      werewolf ? TagChip.danger(text, small: true) : TagChip(text, small: true);
}

/// The head of the night: where each Werewolf card went, headed by the
/// Werewolf's portrait ("Cara → Bob"; one place: it never moved), or, in a
/// game with no werewolf card, the roles that woke, in order. A tap folds
/// the steps under it away, and opens them again.
class _NightHead extends StatelessWidget {
  const _NightHead({
    required this.paths,
    required this.lines,
    required this.open,
    required this.onTap,
  });

  final List<WerewolfPath> paths;
  final List<NightLine> lines;
  final bool open;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final type = skin.typography;
    final ground = context.ground;
    final arrow = Icon(
      Icons.arrow_forward,
      size: type.body.fontSize,
      color: ground.dangerText,
    );
    final Widget content = paths.isEmpty
        ? Wrap(
            spacing: Space.xs,
            runSpacing: Space.xs,
            children: [
              for (final line in lines)
                RolePortrait(role: line.role, width: RolePortrait.strip),
            ],
          )
        : Wrap(
            spacing: Space.lg,
            runSpacing: Space.sm,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              for (final path in paths)
                Wrap(
                  spacing: Space.xs,
                  runSpacing: Space.xs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    const RolePortrait(
                      role: RoleId.werewolf,
                      width: RolePortrait.strip,
                    ),
                    for (final (i, place) in path.places.indexed) ...[
                      if (i > 0) arrow,
                      TagChip.danger(place, small: true),
                    ],
                  ],
                ),
            ],
          );
    return Semantics(
      button: true,
      expanded: open,
      label: ResultsCopy.nightSpoken,
      excludeSemantics: true,
      child: Material(
        type: MaterialType.transparency,
        child: InkWell(
          onTap: onTap,
          borderRadius: BorderRadius.circular(skin.shape.radius),
          highlightColor: Colors.transparent,
          splashColor: Colors.transparent,
          child: Container(
            padding: const EdgeInsets.all(Space.smPlus),
            decoration: BoxDecoration(
              border: Border.all(
                color: paths.isEmpty ? ground.hairline : ground.dangerLine,
                width: skin.shape.ring,
              ),
              borderRadius: BorderRadius.circular(skin.shape.radius),
            ),
            child: Row(
              spacing: Space.sm,
              children: [
                Expanded(child: content),
                Icon(
                  open ? Icons.expand_less : Icons.expand_more,
                  color: ground.text,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

/// A line of the night landing: in from a little to the side, fading up.
class _LineLanding extends StatelessWidget {
  const _LineLanding({required this.t, required this.child});

  final double t;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final eased = Motion.curve.transform(t);
    return Opacity(
      opacity: eased,
      child: Transform.translate(
        offset: Offset((1 - eased) * Space.md, 0),
        child: child,
      ),
    );
  }
}

/// One step of the night on its spine (red where a werewolf card was looked
/// at or moved): its number, the role's portrait, "Robber: Ben takes Dev's
/// card.", and the cards it showed or moved.
class _Line extends StatelessWidget {
  const _Line(this.line);

  final NightLine line;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final type = skin.typography;
    final ground = context.ground;
    return Container(
      margin: const EdgeInsets.only(left: Space.lg),
      padding: const EdgeInsets.fromLTRB(Space.md, Space.sm, 0, Space.sm),
      decoration: BoxDecoration(
        border: Border(
          left: BorderSide(
            color: line.werewolf ? ground.dangerLine : ground.hairline,
            width: line.werewolf ? skin.shape.selectedRing : skin.shape.ring,
          ),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: Space.smPlus,
        children: [
          SizedBox(
            width: Space.lg,
            child: Text(
              '${line.number}',
              style: type.nameSmall.copyWith(
                color: line.werewolf ? ground.dangerText : ground.quietText,
              ),
            ),
          ),
          RolePortrait(role: line.role, width: RolePortrait.line),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: Space.xs,
              children: [
                // The role steps back, above; what happened leads. Each is
                // set on its own, so neither breaks inside a word.
                FitWords(
                  line.prefix,
                  style: type.action.copyWith(color: ground.quietText),
                ),
                FitWords(
                  line.text,
                  style: type.body.copyWith(color: ground.text),
                ),
                if (line.cards.isNotEmpty)
                  Wrap(
                    spacing: Space.xs,
                    runSpacing: Space.xxs,
                    crossAxisAlignment: WrapCrossAlignment.center,
                    children: [
                      for (final (i, card) in line.cards.indexed) ...[
                        if (i > 0 && line.swap)
                          Icon(
                            Icons.swap_horiz,
                            size: type.body.fontSize,
                            color: ground.quietText,
                          ),
                        _CardChip(
                          card.role.displayName,
                          werewolf: card.werewolf,
                        ),
                      ],
                    ],
                  ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
