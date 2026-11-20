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
import '../protocol_two_game.dart';
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
  final ProtocolTwoGame? game;

  @override
  ConsumerState<ResultsScreen> createState() => _ResultsScreenState();
}

enum _Act { playAgain, editDeck, leave }

class _ResultsScreenState extends ConsumerState<ResultsScreen> {
  _Act? _busy;
  _Act? _failed;

  ProtocolTwoGameNotifier get _notifier =>
      ref.read(protocolTwoGameProvider(widget.gameId).notifier);

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
    final host = me.seats.where((s) => s.id == me.hostId).firstOrNull;
    return ResultsView(
      outcome: outcome,
      viewerId: me.playerId,
      hostName: me.isHost ? null : host?.name ?? '',
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
/// the center, and the night folded into a strip of the roles that woke, in
/// order; a tap opens it into a line per step ("Robber: Ben takes Dev's
/// card.", with the cards the step showed), landing one by one (600 ms each,
/// a tap finishes them; instant with reduce motion). Werewolf cards are red
/// wherever they appear. Everything is the server's: the winners, each
/// player's outcome, team and cards, the timeline.
///
/// [hostName] null: this phone is the host ("Play again", "Edit deck");
/// otherwise "{host} deals next." and "Leave".
class ResultsView extends StatefulWidget {
  const ResultsView({
    super.key,
    required this.outcome,
    required this.viewerId,
    required this.hostName,
    required this.onPlayAgain,
    required this.onEditDeck,
    required this.onLeave,
    required this.onTryAgain,
    this.busy = false,
    this.failed = false,
    this.nightOpen = false,
  });

  final GameOutcome outcome;
  final int viewerId;
  final String? hostName;
  final VoidCallback onPlayAgain;
  final VoidCallback onEditDeck;
  final VoidCallback onLeave;
  final VoidCallback onTryAgain;

  /// A request is on its way.
  final bool busy;

  /// The last request got no answer.
  final bool failed;

  /// Opens with the night unfolded (the gallery's picture of it).
  final bool nightOpen;

  /// How long each line of the night takes to land.
  static const lineLands = Duration(milliseconds: 600);

  @override
  State<ResultsView> createState() => _ResultsViewState();
}

class _ResultsViewState extends State<ResultsView>
    with SingleTickerProviderStateMixin {
  late final Winners _winners = Winners.of(widget.outcome.result.winningTeams);
  late final List<EndSeat> _seats = endSeatsOf(widget.outcome);
  late final List<NightLine> _lines = nightLinesOf(widget.outcome);
  late final AnimationController _landing;
  late bool _open = widget.nightOpen;

  @override
  void initState() {
    super.initState();
    _landing = AnimationController(
      vsync: this,
      duration: ResultsView.lineLands * math.max(1, _lines.length),
      value: _open ? 1 : 0,
    );
  }

  @override
  void dispose() {
    _landing.dispose();
    super.dispose();
  }

  void _toggle() {
    setState(() => _open = !_open);
    if (!_open) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _landing.value = 1;
    } else {
      unawaited(_landing.forward(from: 0));
    }
  }

  void _finish() {
    if (_landing.isAnimating) _landing.value = 1;
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
              for (final seat in _seats)
                _EndRow(seat, own: seat.seat.id == widget.viewerId),
              const SizedBox(height: Space.md),
              Text(
                ResultsCopy.center.fill({
                  'roles': nameList(center.map((r) => r.displayName)),
                }),
                style: type.body.copyWith(color: context.ground.quietText),
              ),
              if (_lines.isNotEmpty) ...[
                const SizedBox(height: Space.xl),
                _NightStrip(lines: _lines, open: _open, onTap: _toggle),
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

  /// 0 to 1 as line [i] lands.
  double _phase(int i) {
    final n = math.max(1, _lines.length);
    return ((_landing.value * n) - i).clamp(0.0, 1.0);
  }

  List<Widget> _actions(BuildContext context) {
    final type = context.skin.typography;
    final host = widget.hostName;
    return [
      if (widget.failed)
        Notice(
          message: BannerCopy.notSent,
          action: BannerCopy.tryAgain,
          onAction: widget.onTryAgain,
        ),
      if (host == null)
        Row(
          spacing: Space.md,
          children: [
            Expanded(
              child: PrimaryButton(
                label: ResultsCopy.playAgain,
                onPressed: widget.onPlayAgain,
                busy: widget.busy,
                size: ButtonSize.large,
              ),
            ),
            Expanded(
              child: SecondaryButton(
                label: ResultsCopy.editDeck,
                onPressed: widget.busy ? null : widget.onEditDeck,
                size: ButtonSize.large,
              ),
            ),
          ],
        )
      else ...[
        Text(
          ResultsCopy.hostDealsNext.fill({'host': host}),
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
      builder: (context, room) {
        // The portrait takes about a third of the band, as in the picture,
        // and never more than its own width.
        final width = math.min(RolePortrait.winner, room.maxWidth * 0.36);
        return Row(
          crossAxisAlignment: CrossAxisAlignment.end,
          spacing: Space.lg,
          children: [
            RolePortrait.arched(role: portrait, width: width),
            Expanded(child: words),
          ],
        );
      },
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
    final quiet = type.body.copyWith(color: ground.quietText);
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
        vertical: Space.sm,
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
          PlayerToken(seat.seat.token, size: TokenSize.row),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: Space.xxs,
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
                      FitWords(seat.dealt.displayName, style: quiet),
                      Icon(
                        Icons.arrow_forward,
                        size: type.body.fontSize,
                        color: ground.quietText,
                      ),
                    ],
                    _cardChip(card, werewolf: seat.team == TeamId.werewolf),
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

/// A role's name as a chip: red for a werewolf card.
Widget _cardChip(String text, {required bool werewolf}) =>
    werewolf ? TagChip.danger(text, small: true) : TagChip(text, small: true);

/// The night folded: the roles that woke, in order, as small portraits with
/// their step numbers; a tap opens (and closes) the lines.
class _NightStrip extends StatelessWidget {
  const _NightStrip({
    required this.lines,
    required this.open,
    required this.onTap,
  });

  final List<NightLine> lines;
  final bool open;
  final VoidCallback onTap;

  static const _portrait = 30.0;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final ground = context.ground;
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
                color: ground.hairline,
                width: skin.shape.ring,
              ),
              borderRadius: BorderRadius.circular(skin.shape.radius),
            ),
            child: Row(
              spacing: Space.sm,
              children: [
                Expanded(
                  child: Wrap(
                    spacing: Space.xs,
                    runSpacing: Space.xs,
                    children: [
                      for (final line in lines)
                        RolePortrait(role: line.role, width: _portrait),
                    ],
                  ),
                ),
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

/// One step of the night: its number, the role's portrait, "Robber: Ben
/// takes Dev's card.", and the cards it showed or moved.
class _Line extends StatelessWidget {
  const _Line(this.line);

  final NightLine line;

  static const _portrait = 36.0;

  @override
  Widget build(BuildContext context) {
    final type = context.skin.typography;
    final ground = context.ground;
    return Padding(
      padding: const EdgeInsets.only(top: Space.md),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: Space.smPlus,
        children: [
          SizedBox(
            width: Space.lg,
            child: Text(
              '${line.number}',
              style: type.nameSmall.copyWith(color: ground.quietText),
            ),
          ),
          RolePortrait(role: line.role, width: _portrait),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: Space.xs,
              children: [
                Text.rich(
                  TextSpan(
                    children: [
                      // The role steps back; what happened leads.
                      TextSpan(
                        text: '${line.prefix} ',
                        style: type.action.copyWith(color: ground.quietText),
                      ),
                      TextSpan(
                        text: line.text,
                        style: type.body.copyWith(color: ground.text),
                      ),
                    ],
                  ),
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
                        _cardChip(
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
