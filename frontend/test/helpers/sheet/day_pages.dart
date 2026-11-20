import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:midnight_village/design_system/copy/copy.dart';
import 'package:midnight_village/design_system/copy/role_text.dart';
import 'package:midnight_village/design_system/faces/face_content.dart';
import 'package:midnight_village/design_system/layout/space.dart';
import 'package:midnight_village/design_system/models/role.dart';
import 'package:midnight_village/design_system/night/night_pick.dart';
import 'package:midnight_village/design_system/primitives/band.dart';
import 'package:midnight_village/design_system/primitives/fit_line.dart';
import 'package:midnight_village/design_system/primitives/panels.dart';
import 'package:midnight_village/design_system/primitives/paper_card.dart';
import 'package:midnight_village/design_system/primitives/player_row.dart';
import 'package:midnight_village/design_system/primitives/player_token.dart';
import 'package:midnight_village/design_system/primitives/primary_button.dart';
import 'package:midnight_village/design_system/primitives/progress_pips.dart';
import 'package:midnight_village/design_system/primitives/role_card.dart';
import 'package:midnight_village/design_system/primitives/screen_frame.dart';
import 'package:midnight_village/design_system/primitives/secondary_button.dart';
import 'package:midnight_village/design_system/primitives/tag_chip.dart';
import 'package:midnight_village/design_system/skin/ground.dart';
import 'package:midnight_village/design_system/skin/skin.dart';
import 'package:midnight_village/design_system/teach/cue_wave.dart';
import 'package:midnight_village/design_system/teach/learned_store.dart';
import 'package:midnight_village/design_system/teach/teach_once.dart';
import 'package:midnight_village/design_system/teach/teaching_hold.dart';

import 'sheet_data.dart';
import 'table_pages.dart';

// 08 Talk, 09 Vote, 10 The count and 11 Results, to the first-time play
// spec.

/// 08: the talk. The sun is loudest, then My night (the hold cue on it in
/// a first game); "Ready to vote" is outlined and never locked.
class TalkPage extends StatefulWidget {
  const TalkPage({super.key, required this.viewer});

  final Viewer viewer;

  @override
  State<TalkPage> createState() => _TalkPageState();
}

class _TalkPageState extends State<TalkPage> {
  var _ready = false;

  @override
  Widget build(BuildContext context) {
    final me = widget.viewer.talkMe;
    final progress = me['progress'] as Map<String, dynamic>;
    final (done, needed) = (progress['done'] as int, progress['needed'] as int);
    return ScreenFrame(
      ground: GroundKind.day,
      topSlot: const TimerBand.sun(secondsLeft: 252, elapsed: 0.3),
      body: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: Space.lg,
        children: [
          Text(TalkCopy.headline, style: context.skin.typography.screenTitle),
          TeachingHold(
            target: TalkCopy.myNight,
            face: widget.viewer.myNight,
            cue: Cue.holdMyNight,
            cover: (teaching) =>
                PeekBox(title: TalkCopy.myNight, teaching: teaching),
          ),
          deckStrip(RoleCardSize.mini, deckOf(me)),
        ],
      ),
      actions: [
        ProgressPips(
          done: done,
          total: needed,
          label: TalkCopy.progress.fill({'d': done, 'n': needed}),
        ),
        PrimaryButton.quiet(
          label: _ready ? CommonCopy.readyDone : TalkCopy.readyToVote,
          onPressed: () => setState(() => _ready = !_ready),
        ),
      ],
    );
  }
}

/// 09: pick a name, then lock it in. Your own row is never listed; once
/// locked every row looks the same.
class VotePage extends ConsumerStatefulWidget {
  const VotePage({super.key});

  @override
  ConsumerState<VotePage> createState() => _VotePageState();
}

class _VotePageState extends ConsumerState<VotePage> {
  NightSeat? _pick;
  var _locked = false;

  @override
  Widget build(BuildContext context) {
    final others = fiveSeats.where((s) => s != ana).toList();
    final pick = _pick;
    return ScreenFrame(
      ground: GroundKind.day,
      topSlot: const TimerBand.bar(secondsLeft: 72, remaining: 0.8),
      body: TeachOnce(
        cue: Cue.voteLock,
        builder: (context, teaching) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: Space.md,
          children: [
            Text(VoteCopy.headline, style: context.skin.typography.screenTitle),
            for (final (i, seat) in others.indexed)
              CueWave(
                play: teaching,
                index: i,
                distance: CueWave.rowNudge,
                child: PlayerRow(
                  token: seat.token,
                  name: seat.name,
                  size: PlayerRowSize.large,
                  picked: !_locked && seat == pick,
                  dimmed: _locked,
                  onTap: _locked ? null : () => setState(() => _pick = seat),
                ),
              ),
          ],
        ),
      ),
      actions: [
        ProgressPips(
          done: 3,
          total: fiveSeats.length,
          label: VoteCopy.progress.fill({'d': 3, 'n': fiveSeats.length}),
        ),
        if (_locked)
          const PrimaryButton.done(label: VoteCopy.locked)
        else if (pick == null)
          const PrimaryButton(label: VoteCopy.pickName, onPressed: null)
        else
          PrimaryButton(
            label: VoteCopy.lockIn.fill({'name': pick.name}),
            icon: Icons.lock_outline,
            onPressed: () {
              setState(() => _locked = true);
              ref.read(learnedCuesProvider.notifier).learn(Cue.voteLock);
            },
          ),
      ],
    );
  }
}

/// 10: who voted for whom, by name; who dies; the dead player's card, Now
/// and, where it moved, Dealt.
class CountPage extends StatelessWidget {
  const CountPage({super.key});

  @override
  Widget build(BuildContext context) {
    final type = context.skin.typography;
    return ScreenFrame(
      ground: GroundKind.day,
      topSlot: Band(
        child: Builder(
          builder: (context) => Row(
            spacing: Space.lg,
            children: [
              PlayerToken(
                cleo.token,
                size: TokenSize.band,
                ringColor: context.ground.dangerLine,
              ),
              Expanded(
                child: Align(
                  alignment: AlignmentDirectional.centerStart,
                  child: FitLine(
                    CountCopy.dies.fill({'name': cleo.name}),
                    style: type.heroVerdict,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
      body: Builder(
        builder: (context) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: Space.smPlus,
          children: [
            for (final (seat, voters) in [
              (cleo, [ana, ben, dev]),
              (ana, [cleo]),
            ])
              PlayerRow(
                token: seat.token,
                name: seat.name,
                size: PlayerRowSize.count,
                detail: nameList(voters.map((v) => v.name)),
                trailing: Tally(voters.length),
              ),
            Text(
              CountCopy.noVote.fill({'names': esme.name}),
              style: type.body.copyWith(color: context.ground.text),
            ),
            const _DeadCard(dealt: RoleId.werewolf, now: RoleId.werewolf),
          ],
        ),
      ),
      actions: [PrimaryButton(label: CountCopy.seeWhoWon, onPressed: () {})],
    );
  }
}

/// The dead player's card: Dealt, an arrow, Now, its name and team.
class _DeadCard extends StatelessWidget {
  const _DeadCard({required this.dealt, required this.now});

  final RoleId dealt;
  final RoleId now;

  static const _dealtWidth = 64.0;
  static const _nowWidth = 96.0;

  @override
  Widget build(BuildContext context) => PaperCard(
    lift: PaperLift.heroSlab,
    padding: const EdgeInsets.all(Space.smPlus),
    child: Builder(
      builder: (context) {
        final type = context.skin.typography;
        final quiet = type.caption.copyWith(color: context.ground.quietText);
        Widget card(RoleId role, double width, String caption) => Column(
          mainAxisSize: MainAxisSize.min,
          spacing: Space.xxs,
          children: [
            RolePortrait(role: role, width: width),
            FitWords(caption, style: quiet),
          ],
        );
        return Row(
          spacing: Space.sm,
          children: [
            if (dealt != now) ...[
              Flexible(child: card(dealt, _dealtWidth, CountCopy.dealt)),
              Icon(Icons.arrow_forward, color: context.ground.text),
            ],
            Flexible(flex: 2, child: card(now, _nowWidth, CountCopy.now)),
            Expanded(
              flex: 3,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                spacing: Space.sm,
                children: [
                  FitLine(now.displayName, style: type.display),
                  now.team == TeamId.werewolf
                      ? TagChip.danger(RoleText.teamTag(now.team))
                      : TagChip(RoleText.teamTag(now.team)),
                ],
              ),
            ),
          ],
        );
      },
    ),
  );
}

/// 11: who won, the night in order, and (for the host) play again.
class ResultsPage extends StatelessWidget {
  const ResultsPage({super.key, this.guest = false});

  final bool guest;

  @override
  Widget build(BuildContext context) {
    final type = context.skin.typography;
    String row(String role, String line) =>
        '${TimelineCopy.prefix.fill({'role': role})} $line';
    final timeline = [
      row(
        RoleId.werewolf.displayName,
        TimelineCopy.wakesAlone.fill({'name': cleo.name}),
      ),
      row(
        RoleId.werewolf.displayName,
        TimelineCopy.loneWerewolf.fill({'a': cleo.name, 'pos': centerName(0)}),
      ),
      row(
        RoleId.seer.displayName,
        TimelineCopy.seerPlayer.fill({'a': ana.name, 'b': cleo.name}),
      ),
      row(
        RoleId.robber.displayName,
        TimelineCopy.robber.fill({'a': ben.name, 'b': ana.name}),
      ),
      row(
        RoleId.troublemaker.displayName,
        TimelineCopy.skip.fill({'a': dev.name}),
      ),
    ];
    return ScreenFrame(
      ground: GroundKind.night,
      topSlot: Band(
        child: Row(
          spacing: Space.lg,
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            const RolePortrait.arched(
              role: RoleId.villager,
              width: RolePortrait.winner,
            ),
            Expanded(
              child: FitWords(ResultsCopy.villageWins, style: type.heroWinner),
            ),
          ],
        ),
      ),
      body: Builder(
        builder: (context) {
          final ink = context.ground.text;
          return Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            spacing: Space.sm,
            children: [
              Text(ResultsCopy.youWon, style: type.title),
              for (final line in timeline)
                Text(line, style: type.body.copyWith(color: ink)),
              // The timeline's last row: under each player, won or died.
              Wrap(
                spacing: Space.lg,
                runSpacing: Space.xs,
                children: [
                  for (final seat in fiveSeats)
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(seat.name, style: type.body.copyWith(color: ink)),
                        Text(
                          seat == cleo ? ResultsCopy.died : ResultsCopy.won,
                          style: type.caption.copyWith(
                            color: seat == cleo
                                ? context.ground.dangerText
                                : context.ground.quietText,
                          ),
                        ),
                      ],
                    ),
                ],
              ),
              Text(
                ResultsCopy.center.fill({
                  'roles': nameList([
                    RoleId.werewolf.displayName,
                    RoleId.drunk.displayName,
                    RoleId.insomniac.displayName,
                  ]),
                }),
                style: type.body.copyWith(color: ink),
              ),
            ],
          );
        },
      ),
      actions: [
        if (guest) ...[
          Builder(
            builder: (context) => Text(
              ResultsCopy.hostDealsNext.fill({'host': ana.name}),
              textAlign: TextAlign.center,
              style: type.body.copyWith(color: context.ground.text),
            ),
          ),
          SecondaryButton(label: CommonCopy.leave, onPressed: () {}),
        ] else
          Row(
            spacing: Space.md,
            children: [
              Expanded(
                child: PrimaryButton(
                  label: ResultsCopy.playAgain,
                  onPressed: () {},
                  size: ButtonSize.large,
                ),
              ),
              Expanded(
                child: SecondaryButton(
                  label: ResultsCopy.editDeck,
                  onPressed: () {},
                  size: ButtonSize.large,
                ),
              ),
            ],
          ),
      ],
    );
  }
}
