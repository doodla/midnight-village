import 'package:flutter/material.dart';
import 'package:midnight_village/design_system/copy/copy.dart';
import 'package:midnight_village/design_system/layout/space.dart';
import 'package:midnight_village/design_system/faces/night_report.dart';
import 'package:midnight_village/design_system/night/choose_prompt.dart';
import 'package:midnight_village/design_system/night/night_board.dart';
import 'package:midnight_village/design_system/night/night_pick.dart';
import 'package:midnight_village/design_system/primitives/face_down_card.dart';
import 'package:midnight_village/design_system/primitives/primary_button.dart';
import 'package:midnight_village/design_system/primitives/progress_pips.dart';
import 'package:midnight_village/design_system/skin/dress.dart';
import 'package:midnight_village/design_system/primitives/screen_frame.dart';
import 'package:midnight_village/design_system/primitives/world_timer.dart';
import 'package:midnight_village/design_system/skin/art_set.dart';
import 'package:midnight_village/design_system/skin/ground.dart';
import 'package:midnight_village/design_system/skin/skin.dart';
import 'package:midnight_village/design_system/teach/teach_once.dart';
import 'package:midnight_village/design_system/teach/teaching_hold.dart';

import 'sheet_data.dart';

// 04 Your card, 05 between, 06 the night board, to the first-time play spec,
// each as a phone of a recorded game had it (sheet_data.dart).

/// 04: the dealt card, face down; the whole role card while held; "Ready"
/// locked until a 0.8 s reveal (a tap on it replays the hold cue); plain
/// pips.
class CardPage extends StatefulWidget {
  const CardPage({super.key, required this.viewer, this.look});

  final Viewer viewer;

  /// The viewer's own `/me/` in the look stage (its card and the count);
  /// game 7's Ana's count with [viewer]'s card when not given.
  final Map<String, dynamic>? look;

  @override
  State<CardPage> createState() => _CardPageState();
}

class _CardPageState extends State<CardPage> {
  /// Game 7's look stage: who has looked, as the server counts it.
  late final _look =
      (widget.look ?? recordedMe('me_look_stage'))['progress']
          as Map<String, dynamic>;
  late final _face = widget.look == null
      ? widget.viewer.card
      : NightReport.fromMe(widget.look!).card;
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
      topScene: LayeredSceneId.nightVillage,
      topArtLayout: TopArtLayout.backdrop,
      body: Column(
        spacing: Space.lg,
        children: [
          // Left, clear of the moon in the picture.
          SizedBox(
            width: double.infinity,
            child: Text(CardCopy.headline, style: skin.typography.screenTitle),
          ),
          TeachingHold(
            target: CardCopy.headline,
            face: _face,
            replay: _replay,
            inPlace: true,
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
          done: _look['done'] as int,
          total: _look['needed'] as int,
          label: CommonCopy.progress.fill({
            'd': _look['done'],
            'n': _look['needed'],
          }),
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

/// 06: the night board, as [viewer]'s phone had it in the recorded game,
/// or at that game's [table] changed (`tableOf`). With [fails] the choose
/// gets no answer (the phone is offline).
class BoardPage extends StatelessWidget {
  const BoardPage({
    super.key,
    required this.viewer,
    this.table,
    this.textScale = 1,
    this.fails = false,
    this.secondsLeft = 14,
    this.share,
    this.dress,
  });

  /// How the board is dressed; null: as the live screen (`NightBoard.defaultDress`).
  final Dress? dress;

  final Viewer viewer;
  final Map<String, dynamic> Function(Map<String, dynamic> me)? table;
  final double textScale;
  final bool fails;

  /// What the candle's number says.
  final int secondsLeft;

  /// How much of the window the candle shows left; null, whole.
  final double? share;

  @override
  Widget build(BuildContext context) {
    final me = table?.call(viewer.nightMe) ?? viewer.nightMe;
    final prompt = ChoosePrompt.fromMe(me);
    return MediaQuery(
      data: MediaQuery.of(
        context,
      ).copyWith(textScaler: TextScaler.linear(textScale)),
      child: NightBoard(
        seats: NightSeat.seatsOf(me),
        selfId: selfIn(me),
        prompt: prompt,
        face: NightReport.fromMe(me).you(prompt),
        dealt: NightReport.fromMe(me).dealt,
        secondsLeft: secondsLeft,
        share: share,
        dress: dress,
        onChoose: (_, _) async =>
            fails ? ChooseAnswer.notSent : ChooseAnswer.taken,
      ),
    );
  }
}
