import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:midnight_village/design_system/copy/copy.dart';
import 'package:midnight_village/design_system/layout/space.dart';
import 'package:midnight_village/design_system/night/night_pick.dart';
import 'package:midnight_village/design_system/primitives/band.dart';
import 'package:midnight_village/design_system/primitives/panels.dart';
import 'package:midnight_village/design_system/primitives/player_row.dart';
import 'package:midnight_village/design_system/primitives/primary_button.dart';
import 'package:midnight_village/design_system/primitives/progress_pips.dart';
import 'package:midnight_village/design_system/primitives/role_card.dart';
import 'package:midnight_village/design_system/primitives/screen_frame.dart';
import 'package:midnight_village/design_system/skin/ground.dart';
import 'package:midnight_village/design_system/skin/skin.dart';
import 'package:midnight_village/design_system/teach/cue_wave.dart';
import 'package:midnight_village/design_system/teach/learned_store.dart';
import 'package:midnight_village/design_system/teach/teach_once.dart';
import 'package:midnight_village/design_system/teach/teaching_hold.dart';

import 'sheet_data.dart';
import 'table_pages.dart';

// 08 Talk and 09 Vote, to the first-time play spec (10 and 11:
// end_pages.dart).

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
