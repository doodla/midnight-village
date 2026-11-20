import 'package:flutter/material.dart';
import 'package:midnight_village/design_system/copy/copy.dart';
import 'package:midnight_village/design_system/layout/space.dart';
import 'package:midnight_village/design_system/night/night_board.dart';
import 'package:midnight_village/design_system/primitives/face_down_card.dart';
import 'package:midnight_village/design_system/primitives/primary_button.dart';
import 'package:midnight_village/design_system/primitives/progress_pips.dart';
import 'package:midnight_village/design_system/primitives/screen_frame.dart';
import 'package:midnight_village/design_system/primitives/world_timer.dart';
import 'package:midnight_village/design_system/skin/ground.dart';
import 'package:midnight_village/design_system/skin/skin.dart';
import 'package:midnight_village/design_system/teach/teach_once.dart';
import 'package:midnight_village/design_system/teach/teaching_hold.dart';

import 'sheet_data.dart';

// 04 Your card, 05 between, 06 the night board, to the first-time play spec.

/// 04: the dealt card, face down; the whole role card while held; "Ready"
/// locked until a 0.8 s reveal (a tap on it replays the hold cue); plain
/// pips.
class CardPage extends StatefulWidget {
  const CardPage({super.key, required this.viewer});

  final Viewer viewer;

  @override
  State<CardPage> createState() => _CardPageState();
}

class _CardPageState extends State<CardPage> {
  final _replay = CueReplay();
  var _revealed = false;

  @override
  void dispose() {
    _replay.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return ScreenFrame(
      ground: GroundKind.night,
      topArt: skin.art.nightVillage,
      topArtLayout: TopArtLayout.backdrop,
      body: Column(
        spacing: Space.lg,
        children: [
          Text(
            CardCopy.headline,
            textAlign: TextAlign.center,
            style: skin.typography.screenTitle,
          ),
          TeachingHold(
            target: CardCopy.headline,
            face: widget.viewer.card,
            replay: _replay,
            onRevealed: () => setState(() => _revealed = true),
            cover: (teaching) =>
                FaceDownCard(size: FaceDownSize.hero, hold: teaching),
          ),
        ],
      ),
      actionGap: Space.lg,
      actions: [
        if (_revealed)
          PrimaryButton(
            label: CardCopy.ready,
            onPressed: () {},
            size: ButtonSize.large,
          )
        else
          PrimaryButton.locked(
            label: CardCopy.ready,
            onLockedTap: _replay.replay,
            size: ButtonSize.large,
          ),
        ProgressPips(
          done: 2,
          total: fiveSeats.length,
          label: CommonCopy.progress.fill({'d': 2, 'n': fiveSeats.length}),
          centred: true,
        ),
      ],
    );
  }
}

/// 05: while the night's next screen loads; nothing to do.
class WaitPage extends StatelessWidget {
  const WaitPage({super.key});

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return ScreenFrame(
      ground: GroundKind.night,
      topArt: skin.art.sleepingVillage,
      body: Column(
        spacing: Space.lgPlus,
        children: [
          Text(
            CommonCopy.nightTitle,
            textAlign: TextAlign.center,
            style: skin.typography.screenTitle,
          ),
          const WorldTimer.candle(secondsLeft: 19),
        ],
      ),
    );
  }
}

/// 06: the night board, as every phone has it. With [fails] the server
/// never takes a choose (the phone is offline).
class BoardPage extends StatelessWidget {
  const BoardPage({
    super.key,
    required this.viewer,
    this.ten = false,
    this.textScale = 1,
    this.fails = false,
  });

  final Viewer viewer;
  final bool ten;
  final double textScale;
  final bool fails;

  @override
  Widget build(BuildContext context) => MediaQuery(
    data: MediaQuery.of(
      context,
    ).copyWith(textScaler: TextScaler.linear(textScale)),
    child: NightBoard(
      seats: ten ? tenSeats : fiveSeats,
      selfId: ana.id,
      stage: 'window-2',
      rule: viewer.rule,
      face: viewer.you,
      secondsLeft: 14,
      onChoose: (_, _) async {
        if (fails) throw StateError('offline');
      },
    ),
  );
}
