import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../copy/copy.dart';
import '../faces/face_content.dart';
import '../layout/space.dart';
import '../primitives/face_down_card.dart';
import '../primitives/fit_line.dart';
import '../primitives/hold_to_reveal.dart';
import '../primitives/primary_button.dart';
import '../primitives/screen_frame.dart';
import '../primitives/world_timer.dart';
import '../skin/ground.dart';
import '../skin/skin.dart';
import '../teach/cue_wave.dart';
import '../teach/learned_store.dart';
import '../teach/teach_once.dart';
import '../teach/teaching_hold.dart';
import 'night_pick.dart';

/// The night (06): the same board on every phone, whatever the role
/// (first-time play spec, "The night, second by second").
///
/// - It is drawn from [seats] in seat order, the viewer's own captioned
///   "You", then Left, Middle and Right; never from a prompt's targets.
/// - A tap toggles a pick (on "You", a press shorter than 120 ms: longer is
///   a hold). Up to two picks; a third replaces the oldest; tapping a chosen
///   card unchooses it. Nothing flashes, nothing is refused, nothing sounds.
/// - A pick lifts and takes the selection's outline.
/// - Choose is locked until "You" has been held 0.8 s in this window and
///   there is a pick: "Choose a card" (no pick), then "Choose {cards}", or
///   "Keep my card" when only "You" is picked; "Chosen" once done.
/// - In window 1 every phone chooses twice: after the first Choose the picks
///   clear and Choose locks again until "You" is held again.
/// - Each Choose calls [onChoose] once with the picks in tap order. It shows
///   at once and rolls back if [onChoose] answers false.
///
/// Hidden information: nothing here takes the role but [face], the held face
/// of "You", which only a hold shows; the rest of the board, its states and
/// what it sends have the same shape on every phone
/// (test/design_system/night/night_uniformity_test.dart).
class NightBoard extends ConsumerStatefulWidget {
  const NightBoard({
    super.key,
    required this.seats,
    required this.selfId,
    required this.window,
    required this.face,
    required this.secondsLeft,
    required this.onChoose,
  });

  final List<NightSeat> seats;

  /// The viewer's seat.
  final int selfId;
  final NightWindow window;

  /// What "You" shows while held: the role, this window's instruction, and
  /// window 1's page.
  final FaceContent face;

  /// The window's countdown, as the server gives it.
  final int secondsLeft;

  /// Sends the picks; answers whether the server took them.
  final Future<bool> Function(List<NightPick> picks) onChoose;

  /// Cards per row at most, and with large text.
  static const perRow = 5;
  static const perRowLargeText = 4;

  /// From this text scale the board wraps to [perRowLargeText].
  static const largeText = 1.3;

  @override
  ConsumerState<NightBoard> createState() => _NightBoardState();
}

class _NightBoardState extends ConsumerState<NightBoard> {
  final _replay = CueReplay();
  var _picks = <NightPick>[];

  /// "You" held 0.8 s since this window opened, or since the last Choose.
  var _held = false;
  var _chosen = 0;

  bool get _done => _chosen >= widget.window.chooses;

  @override
  void didUpdateWidget(NightBoard old) {
    super.didUpdateWidget(old);
    if (old.window != widget.window) {
      _picks = [];
      _held = false;
      _chosen = 0;
    }
  }

  @override
  void dispose() {
    _replay.dispose();
    super.dispose();
  }

  void _tap(NightPick pick) {
    if (_done) return;
    setState(() => _picks = toggled(_picks, pick));
  }

  Future<void> _choose() async {
    final sent = _picks;
    final held = _held;
    setState(() {
      _chosen++;
      // Window 1's first Choose: the picks clear and it locks again.
      if (!_done) {
        _picks = [];
        _held = false;
      }
    });
    final taken = await widget.onChoose(sent);
    if (!mounted) return;
    if (taken) {
      await ref.read(learnedCuesProvider.notifier).learn(Cue.nightChoose);
    } else {
      setState(() {
        _chosen--;
        _picks = sent;
        _held = held;
      });
    }
  }

  String _caption(NightPick pick) => switch (pick) {
    SelfPick() => NightCopy.you,
    CenterPick(:final index) => centerName(index),
    PlayerPick(:final playerId) =>
      widget.seats.firstWhere((s) => s.id == playerId).name,
  };

  Widget _button() {
    if (_done) return const PrimaryButton.done(label: NightCopy.chosen);
    if (_picks.isEmpty) {
      return const PrimaryButton(label: NightCopy.chooseNone, onPressed: null);
    }
    final label = _picks.length == 1 && _picks.single is SelfPick
        ? NightCopy.keep
        : NightCopy.choose.fill({'cards': _picks.map(_caption).join(', ')});
    if (!_held) {
      return PrimaryButton.locked(label: label, onLockedTap: _replay.replay);
    }
    return PrimaryButton(label: label, onPressed: _choose);
  }

  @override
  Widget build(BuildContext context) {
    final type = context.skin.typography;
    final large =
        MediaQuery.textScalerOf(context).scale(1) >= NightBoard.largeText;
    final perRow = large ? NightBoard.perRowLargeText : NightBoard.perRow;
    final cards = [
      for (final seat in widget.seats)
        seat.id == widget.selfId ? _you(seat) : _player(seat),
    ];
    final center = [for (var i = 0; i < 3; i++) _center(i)];

    return TeachOnce(
      cue: Cue.nightChoose,
      builder: (context, teaching) {
        var index = 0;
        Widget wave(Widget card) => CueWave(
          play: teaching,
          index: index++,
          distance: CueWave.boardLift,
          child: card,
        );
        // The board rests just above the button, so a held face has room
        // above the thumb.
        return ScreenFrame(
          ground: GroundKind.night,
          fillHeight: true,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Row(
                spacing: Space.md,
                children: [
                  Expanded(
                    child: Semantics(
                      header: true,
                      child: FitWords(
                        CommonCopy.nightTitle,
                        style: type.screenTitle,
                      ),
                    ),
                  ),
                  WorldTimer.candleCompact(secondsLeft: widget.secondsLeft),
                ],
              ),
              Padding(
                padding: const EdgeInsets.only(top: Space.lg),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  spacing: Space.lg,
                  children: [
                    for (var at = 0; at < cards.length; at += perRow)
                      _row([
                        for (final card in cards.skip(at).take(perRow))
                          wave(card),
                      ], perRow),
                    _row([for (final card in center) wave(card)], perRow),
                  ],
                ),
              ),
            ],
          ),
          actions: [_button()],
        );
      },
    );
  }

  /// One row of cards, each a column's width ([perRow] to a row), centred.
  Widget _row(List<Widget> cards, int perRow) {
    final gap = perRow - cards.length;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.start,
      spacing: Space.xs,
      children: [
        if (gap > 0) Spacer(flex: gap),
        for (final card in cards) Expanded(flex: 2, child: card),
        if (gap > 0) Spacer(flex: gap),
      ],
    );
  }

  Widget _player(NightSeat seat) {
    final pick = PlayerPick(seat.id);
    return FaceDownCard(
      owner: seat.token,
      ownerName: seat.name,
      selected: _picks.contains(pick),
      semanticLabel: seat.name,
      onTap: () => _tap(pick),
    );
  }

  Widget _center(int index) {
    final pick = CenterPick(index);
    return FaceDownCard(
      caption: centerName(index),
      selected: _picks.contains(pick),
      semanticLabel: centerName(index),
      onTap: () => _tap(pick),
    );
  }

  Widget _you(NightSeat seat) => TeachingHold(
    target: NightCopy.you,
    face: widget.face,
    cap: HoldToReveal.nightCap,
    replay: _replay,
    onRevealed: () {
      if (!_held && mounted) setState(() => _held = true);
    },
    cover: (teaching) => FaceDownCard(
      owner: seat.token,
      ownerName: NightCopy.you,
      selected: _picks.contains(const SelfPick()),
      semanticLabel: NightCopy.you,
      hold: teaching,
      onTap: () => _tap(const SelfPick()),
    ),
  );
}
