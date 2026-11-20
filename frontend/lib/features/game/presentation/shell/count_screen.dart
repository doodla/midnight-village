import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../../../design_system/copy/copy.dart';
import '../../../../design_system/copy/role_text.dart';
import '../../../../design_system/faces/face_content.dart' show nameList;
import '../../../../design_system/layout/space.dart';
import '../../../../design_system/models/role.dart';
import '../../../../design_system/primitives/art_picture.dart';
import '../../../../design_system/primitives/band.dart';
import '../../../../design_system/primitives/fit_line.dart';
import '../../../../design_system/primitives/notice.dart';
import '../../../../design_system/primitives/paper_card.dart';
import '../../../../design_system/primitives/player_row.dart';
import '../../../../design_system/primitives/player_token.dart';
import '../../../../design_system/primitives/primary_button.dart';
import '../../../../design_system/primitives/role_card.dart';
import '../../../../design_system/primitives/screen_frame.dart';
import '../../../../design_system/primitives/tag_chip.dart';
import '../../../../design_system/skin/ground.dart';
import '../../../../design_system/skin/skin.dart';
import '../../domain/outcome_view.dart';
import '../protocol_two_game.dart';
import '../table_screen.dart';

/// 10 The count (first-time play spec, section 3), wired to the game: the
/// results body ([ProtocolTwoGame.outcome], fetched again until it loads)
/// drawn by [CountView]; "See who won" is this phone's own step to 11
/// ([LocalStepsNotifier.seeWhoWon], kept on this device so a restart lands
/// there again). Until the results arrive: the day's ground and nothing on
/// it, and "One moment" while their fetch is failing.
class CountScreen extends ConsumerWidget {
  const CountScreen({super.key, required this.gameId, required this.game});

  final String gameId;

  /// The game as the shell has it; null while its first `/me/` loads.
  final ProtocolTwoGame? game;

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final outcome = game?.outcome;
    if (outcome == null) {
      return EndWaiting(
        ground: GroundKind.day,
        failing: game?.outcomeFailing ?? false,
      );
    }
    return CountView(
      count: TheCount.of(outcome),
      onSeeWhoWon: () =>
          unawaited(ref.read(localStepsProvider.notifier).seeWhoWon(gameId)),
    );
  }
}

/// 10 and 11 before the results have loaded: the screen's ground, calm,
/// with "One moment" only while the fetch is failing (it is made again by
/// itself until it succeeds).
class EndWaiting extends StatelessWidget {
  const EndWaiting({super.key, required this.ground, required this.failing});

  final GroundKind ground;
  final bool failing;

  @override
  Widget build(BuildContext context) => ScreenFrame(
    ground: ground,
    body: const SizedBox.shrink(),
    actions: [if (failing) const Notice(message: BannerCopy.offline)],
  );
}

/// 10 The count, from the results: who dies (the band), the dead player's
/// card as it ended (face down until the flip), then who voted for whom, by
/// name, most votes first, and who did not vote.
///
/// - The headline: "{name} dies." / "{names} die." / "Nobody dies.", then
///   "{name} dies too." for the Hunter's pick; when nobody dies, "Nobody got
///   2 or more votes.". Who dies is the server's (`is_eliminated`,
///   `elimination_reason`), never counted here.
/// - The card is the one in front of the player at the end (`final_role`),
///   the same the results show, so 10 and 11 cannot disagree (playtest
///   finding 1): "Now", large, with its team as the server says; when it is
///   not the card they were dealt, the dealt one small before it, "Dealt",
///   and an arrow. A Doppelganger's card shows the role she copied, captioned
///   "Doppelganger". With several dead, "Dealt" and "Now" are said on the
///   first card only.
/// - Motion (the same on every phone, from the moment it opens): the rows
///   land 150 ms apart, then after 1.2 s the dead cards turn over (400 ms);
///   "See who won" is locked until they have. Any tap finishes it at once,
///   a tap on the locked button too; with reduce motion it starts finished.
class CountView extends StatefulWidget {
  const CountView({super.key, required this.count, required this.onSeeWhoWon});

  final TheCount count;
  final VoidCallback onSeeWhoWon;

  /// Between two rows landing.
  static const rowStagger = Duration(milliseconds: 150);

  /// After the last row, before the flip.
  static const pause = Duration(milliseconds: 1200);

  /// The flip itself.
  static const flip = Motion.reveal;

  @override
  State<CountView> createState() => _CountViewState();
}

class _CountViewState extends State<CountView>
    with SingleTickerProviderStateMixin {
  late final AnimationController _motion;
  late final Duration _landing;

  @override
  void initState() {
    super.initState();
    final rows = widget.count.accused.length;
    _landing = CountView.rowStagger * math.max(0, rows - 1) + Motion.settle;
    final total = widget.count.dead.isEmpty
        ? _landing
        : _landing + CountView.pause + CountView.flip;
    _motion = AnimationController(vsync: this, duration: total)
      ..addStatusListener((_) {
        if (mounted) setState(() {});
      });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_motion.isAnimating || _motion.isCompleted) return;
    if (MediaQuery.disableAnimationsOf(context)) {
      _motion.value = 1;
    } else {
      unawaited(_motion.forward());
    }
  }

  @override
  void dispose() {
    _motion.dispose();
    super.dispose();
  }

  void _finish() {
    if (!_motion.isCompleted) _motion.value = 1;
  }

  /// 0 to 1 over [from] to [from] + [length] of the whole motion.
  double _phase(Duration from, Duration length) {
    final total = _motion.duration!.inMicroseconds;
    final start = from.inMicroseconds / total;
    final end = (from + length).inMicroseconds / total;
    return ((_motion.value - start) / (end - start)).clamp(0.0, 1.0);
  }

  @override
  Widget build(BuildContext context) {
    final count = widget.count;
    final dead = count.dead;
    final done = _motion.isCompleted;
    return GestureDetector(
      behavior: HitTestBehavior.translucent,
      onTap: _finish,
      child: AnimatedBuilder(
        animation: _motion,
        builder: (context, _) {
          final flip = dead.isEmpty
              ? 1.0
              : Curves.easeInOut.transform(
                  _phase(_landing + CountView.pause, CountView.flip),
                );
          return ScreenFrame(
            ground: GroundKind.day,
            topSlot: Band(child: _Verdict(count: count)),
            body: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                for (final (i, death) in dead.indexed) ...[
                  if (i > 0) const SizedBox(height: Space.md),
                  _DeadCard(
                    death,
                    flip: flip,
                    captions: i == 0,
                    compact: dead.length > 1,
                  ),
                ],
                if (dead.isNotEmpty) const SizedBox(height: Space.xl),
                for (final (i, row) in count.accused.indexed) ...[
                  if (i > 0) const SizedBox(height: Space.md),
                  _Landing(
                    t: _phase(CountView.rowStagger * i, Motion.settle),
                    child: PlayerRow(
                      token: row.player.seat.token,
                      name: row.player.seat.name,
                      size: PlayerRowSize.count,
                      detail: nameList(row.voters.map((v) => v.name)),
                      trailing: Tally(row.votes),
                      picked: row.player.died,
                    ),
                  ),
                ],
                if (count.noVote.isNotEmpty) ...[
                  const SizedBox(height: Space.md),
                  Builder(
                    builder: (context) => Text(
                      CountCopy.noVote.fill({
                        'names': nameList(count.noVote.map((s) => s.name)),
                      }),
                      style: context.skin.typography.body.copyWith(
                        color: context.ground.text,
                      ),
                    ),
                  ),
                ],
              ],
            ),
            actions: [
              if (done)
                PrimaryButton(
                  label: CountCopy.seeWhoWon,
                  onPressed: widget.onSeeWhoWon,
                )
              else
                PrimaryButton.locked(
                  label: CountCopy.seeWhoWon,
                  onLockedTap: _finish,
                ),
            ],
          );
        },
      ),
    );
  }
}

/// A row landing: in from a little below, fading up.
class _Landing extends StatelessWidget {
  const _Landing({required this.t, required this.child});

  final double t;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    final eased = Motion.curve.transform(t);
    return Opacity(
      opacity: eased,
      child: Transform.translate(
        offset: Offset(0, (1 - eased) * Space.md),
        child: child,
      ),
    );
  }
}

/// The band: the dead players' tokens and who dies.
class _Verdict extends StatelessWidget {
  const _Verdict({required this.count});

  final TheCount count;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final type = skin.typography;
    final dead = count.deadByVote;
    final headline = Semantics(
      header: true,
      child: FitWords(count.headline, style: type.heroVerdict),
    );
    final quiet = type.body.copyWith(color: context.ground.text);
    final lines = Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: Space.xs,
      children: [
        headline,
        if (count.diesToo case final line?) Text(line, style: quiet),
        if (count.dead.isEmpty) Text(CountCopy.nobodyGotTwo, style: quiet),
      ],
    );
    final ring = context.ground.dangerLine;
    if (dead.length == 1) {
      return Row(
        spacing: Space.lg,
        children: [
          PlayerToken(
            dead.single.seat.token,
            size: TokenSize.band,
            ringColor: ring,
          ),
          Expanded(child: lines),
        ],
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: Space.md,
      children: [
        if (dead.isNotEmpty)
          Wrap(
            spacing: Space.sm,
            runSpacing: Space.sm,
            children: [
              for (final d in dead)
                PlayerToken(
                  d.seat.token,
                  size: TokenSize.count,
                  ringColor: ring,
                ),
            ],
          ),
        lines,
      ],
    );
  }
}

/// A dead player's card as it ended: the card in front of them at the end
/// ("Now"; for a Doppelganger the role she copied, captioned
/// "Doppelganger"), its name and its team; before it, when the card moved,
/// the dealt card, "Dealt", and an arrow. Face down until [flip] passes half
/// way; nothing of it shows before.
///
/// One death: the card large (the screen's loudest thing), its name beside
/// it; when it moved, dealt and now side by side and the name under them,
/// centred. Several: each card smaller, in one row with the player's token
/// and name, so the rows still show.
class _DeadCard extends StatelessWidget {
  const _DeadCard(
    this.death, {
    required this.flip,
    required this.captions,
    required this.compact,
  });

  final EndSeat death;

  /// 0: face down; 1: turned over.
  final double flip;

  /// Say "Dealt" and "Now" (the first card only).
  final bool captions;

  /// Several die: smaller, and the player named on it.
  final bool compact;

  /// The portraits' widths: the card's own and the dealt one before it,
  /// alone and with others.
  static const _now = 112.0;
  static const _dealt = 72.0;
  static const _nowCompact = 64.0;
  static const _dealtCompact = 40.0;

  @override
  Widget build(BuildContext context) => PaperCard(
    lift: PaperLift.heroSlab,
    padding: const EdgeInsets.all(Space.md),
    child: Builder(
      builder: (context) {
        final type = context.skin.typography;
        final ground = context.ground;
        final shown = ((flip - 0.5) * 2).clamp(0.0, 1.0);
        final quiet = type.caption.copyWith(color: ground.quietText);
        final centred = death.moved && !compact;
        final nowCaption = death.copied != null
            ? RoleId.doppelganger.displayName
            : captions
            ? CountCopy.now
            : null;
        Widget card(Widget picture, String? text) => Column(
          mainAxisSize: MainAxisSize.min,
          spacing: Space.xxs,
          children: [
            picture,
            if (text != null)
              Opacity(
                opacity: shown,
                child: FitWords(text, style: quiet),
              ),
          ],
        );
        final cards = Row(
          mainAxisSize: MainAxisSize.min,
          spacing: Space.sm,
          children: [
            if (death.moved) ...[
              Opacity(
                opacity: shown,
                child: card(
                  RolePortrait(
                    role: death.dealt,
                    width: compact ? _dealtCompact : _dealt,
                  ),
                  captions ? CountCopy.dealt : null,
                ),
              ),
              Opacity(
                opacity: shown,
                child: Icon(Icons.arrow_forward, color: ground.text),
              ),
            ],
            card(
              _Turning(
                role: death.plays,
                width: compact ? _nowCompact : _now,
                flip: flip,
              ),
              nowCaption,
            ),
          ],
        );
        final align = centred ? TextAlign.center : TextAlign.start;
        final words = Opacity(
          opacity: shown,
          child: Column(
            crossAxisAlignment: centred
                ? CrossAxisAlignment.center
                : CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            spacing: Space.sm,
            children: [
              if (compact)
                Row(
                  spacing: Space.sm,
                  children: [
                    PlayerToken(
                      death.seat.token,
                      size: TokenSize.card,
                      ringColor: ground.text,
                    ),
                    Expanded(
                      child: FitWords(
                        death.seat.name,
                        maxLines: 2,
                        style: type.name.copyWith(color: ground.text),
                      ),
                    ),
                  ],
                ),
              FitWords(
                death.plays.displayName,
                maxLines: 2,
                textAlign: align,
                style: (compact ? type.heading : type.display).copyWith(
                  color: ground.text,
                ),
              ),
              death.team == TeamId.werewolf
                  ? TagChip.danger(RoleText.teamTag(death.team))
                  : TagChip(RoleText.teamTag(death.team)),
            ],
          ),
        );
        if (centred) {
          return Column(
            mainAxisSize: MainAxisSize.min,
            spacing: Space.md,
            children: [cards, words],
          );
        }
        return Row(
          spacing: compact ? Space.md : Space.lg,
          children: [
            cards,
            Expanded(child: words),
          ],
        );
      },
    ),
  );
}

/// A role portrait that turns over: the card's back until half way, then
/// its face.
class _Turning extends StatelessWidget {
  const _Turning({required this.role, required this.width, required this.flip});

  final RoleId role;
  final double width;
  final double flip;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final face = flip >= 0.5;
    final angle = face ? (1 - flip) * math.pi : flip * math.pi;
    return Transform(
      alignment: Alignment.center,
      transform: Matrix4.identity()
        ..setEntry(3, 2, 0.001)
        ..rotateY(angle),
      child: face
          ? RolePortrait(role: role, width: width)
          : SizedBox(
              width: width,
              child: AspectRatio(
                aspectRatio: 3 / 4,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(skin.shape.radiusTiny),
                  child: ArtPicture(skin.art.cardBack),
                ),
              ),
            ),
    );
  }
}
