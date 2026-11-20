import 'dart:async';

import 'package:flutter/material.dart';
import 'package:midnight_village/design_system/copy/copy.dart';
import 'package:midnight_village/design_system/faces/face_content.dart';
import 'package:midnight_village/design_system/layout/space.dart';
import 'package:midnight_village/design_system/night/night_board.dart';
import 'package:midnight_village/design_system/night/night_pick.dart';
import 'package:midnight_village/design_system/primitives/face_down_card.dart';
import 'package:midnight_village/design_system/primitives/hold_to_reveal.dart';
import 'package:midnight_village/design_system/primitives/primary_button.dart';
import 'package:midnight_village/design_system/primitives/progress_pips.dart';
import 'package:midnight_village/design_system/primitives/screen_frame.dart';
import 'package:midnight_village/design_system/primitives/world_timer.dart';
import 'package:midnight_village/design_system/skin/ground.dart';
import 'package:midnight_village/design_system/skin/skin.dart';
import 'package:midnight_village/design_system/teach/teach_once.dart';
import 'package:midnight_village/design_system/teach/teaching_hold.dart';

import 'sheet_data.dart';

// 04 Your card, 05 between windows, 06 the night board, 07 What you saw, to
// the first-time play spec.

/// A face-down card that is held to read, with its gate under it: "Ready"
/// (04) or "Done" (07), locked until the reveal counts (and, on 07, until
/// [minimum] has passed since it opened).
class _HeldCardPage extends StatefulWidget {
  const _HeldCardPage({
    required this.headline,
    required this.face,
    required this.gate,
    required this.cap,
    this.minimum = Duration.zero,
    this.progress,
    this.backdrop = false,
  });

  final String headline;
  final FaceContent face;
  final String gate;
  final Duration? cap;
  final Duration minimum;
  final Widget? progress;
  final bool backdrop;

  @override
  State<_HeldCardPage> createState() => _HeldCardPageState();
}

class _HeldCardPageState extends State<_HeldCardPage> {
  final _replay = CueReplay();
  var _revealed = false;
  late var _waited = widget.minimum == Duration.zero;
  Timer? _wait;

  @override
  void initState() {
    super.initState();
    if (!_waited) {
      _wait = Timer(widget.minimum, () => setState(() => _waited = true));
    }
  }

  @override
  void dispose() {
    _wait?.cancel();
    _replay.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    return ScreenFrame(
      ground: GroundKind.night,
      topArt: widget.backdrop ? skin.art.nightVillage : null,
      topArtLayout: TopArtLayout.backdrop,
      body: Column(
        spacing: Space.lg,
        children: [
          Text(
            widget.headline,
            textAlign: TextAlign.center,
            style: skin.typography.screenTitle,
          ),
          TeachingHold(
            target: widget.headline,
            face: widget.face,
            cap: widget.cap,
            replay: _replay,
            onRevealed: () => setState(() => _revealed = true),
            cover: (teaching) =>
                FaceDownCard(size: FaceDownSize.hero, hold: teaching),
          ),
        ],
      ),
      actionGap: Space.lg,
      actions: [
        if (_revealed && _waited)
          PrimaryButton(
            label: widget.gate,
            onPressed: () {},
            size: ButtonSize.large,
          )
        else
          PrimaryButton.locked(
            label: widget.gate,
            onLockedTap: _replay.replay,
            size: ButtonSize.large,
          ),
        ?widget.progress,
      ],
    );
  }
}

/// 04: the dealt card, face down; the role text while held; "Ready" locked
/// until a 0.8 s reveal; plain pips.
class CardPage extends StatelessWidget {
  const CardPage({super.key, required this.viewer});

  final Viewer viewer;

  @override
  Widget build(BuildContext context) => _HeldCardPage(
    headline: CardCopy.headline,
    face: viewer.card,
    gate: CardCopy.ready,
    cap: null,
    backdrop: true,
    progress: ProgressPips(
      done: 2,
      total: fiveSeats.length,
      label: CommonCopy.progress.fill({'d': 2, 'n': fiveSeats.length}),
      centred: true,
    ),
  );
}

/// 05: between a window's close and 07; nothing to do.
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

/// 06: the night board, as every phone has it.
class BoardPage extends StatelessWidget {
  const BoardPage({
    super.key,
    required this.viewer,
    this.window = NightWindow.two,
    this.ten = false,
    this.textScale = 1,
  });

  final Viewer viewer;
  final NightWindow window;
  final bool ten;
  final double textScale;

  @override
  Widget build(BuildContext context) => MediaQuery(
    data: MediaQuery.of(
      context,
    ).copyWith(textScaler: TextScaler.linear(textScale)),
    child: NightBoard(
      seats: ten ? tenSeats : fiveSeats,
      selfId: ana.id,
      window: window,
      face: viewer.you,
      secondsLeft: 14,
      onChoose: (_) async => true,
    ),
  );
}

/// 07: what this phone saw when window 2 closed; "Done" after a 0.8 s
/// reveal and 4 s.
class SawPage extends StatelessWidget {
  const SawPage({super.key, required this.viewer});

  final Viewer viewer;

  /// The least time 07 stays.
  static const minimum = Duration(seconds: 4);

  @override
  Widget build(BuildContext context) => _HeldCardPage(
    headline: SawCopy.headline,
    face: viewer.sawFace,
    gate: CommonCopy.done,
    cap: HoldToReveal.nightCap,
    minimum: minimum,
  );
}
