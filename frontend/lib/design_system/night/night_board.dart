import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../copy/copy.dart';
import '../faces/face_content.dart';
import '../layout/space.dart';
import '../primitives/face_down_card.dart';
import '../primitives/fit_line.dart';
import '../primitives/notice.dart';
import '../primitives/primary_button.dart';
import '../primitives/screen_frame.dart';
import '../primitives/world_timer.dart';
import '../skin/ground.dart';
import '../skin/skin.dart';
import '../teach/cue_wave.dart';
import '../teach/learned_store.dart';
import '../teach/teach_once.dart';
import '../teach/teaching_hold.dart';
import 'choose_prompt.dart';
import 'night_pick.dart';

/// The night (06), sections 3, 7 and 8 of the first-time play spec.
///
/// - Drawn from [seats] in seat order, the viewer's own captioned "You",
///   then Left, Middle and Right: the same cards, places, lift and button on
///   every phone, whatever the role.
/// - Holding "You" shows [face] (what this phone may do); until this device
///   has held "You" once, the thumbprint cue points at it (`hold_you`).
///   Nothing waits on the hold; a tap on "You" picks it at once.
/// - A tap selects a card the prompt's rule can take (lift plus the
///   selection's outline) and unselects a chosen one; a card it cannot take
///   does not select. "You" alone (do nothing) is always a choice. The picks
///   are always that, one of the rule's shapes or the start of one, so a
///   slip cannot waste the turn.
/// - The button: "Choose a card" and "Choose 1 more" are locked (a tap
///   replays the wave over the cards), then "Choose {cards}", or "Keep my
///   card" for "You" alone; "Chosen" from the moment it is pressed.
/// - One Choose per turn. The board re-arms only when [prompt]'s stage or
///   turn changes ([ChoosePrompt.turn]: the Doppelganger's look giving way
///   to her follow-up), never on the prompt's counts.
/// - Choose changes what the table can see at once and never waits: see
///   [onChoose]. What the server sends back belongs on a held face.
///
/// Hidden information: the role reaches this board only as [face], shown
/// while held, and the prompt's rule, which only decides what the player's
/// own taps select; the board's layout and motion are the same for every role
/// (test/design_system/night/night_layout_test.dart).
class NightBoard extends ConsumerStatefulWidget {
  const NightBoard({
    super.key,
    required this.seats,
    required this.selfId,
    required this.prompt,
    required this.face,
    required this.secondsLeft,
    required this.onChoose,
  });

  final List<NightSeat> seats;

  /// The viewer's seat.
  final int selfId;

  /// This phone's prompt, read from `/me/`.
  final ChoosePrompt prompt;

  /// What "You" shows while held.
  final FaceContent face;

  /// The stage's countdown, as the server gives it.
  final int secondsLeft;

  /// Sends the picks, in tap order, with the prompt's stage, and says what
  /// became of them ([ChooseAnswer.fromStatus] on the server's answer). The
  /// board shows "Chosen" before it is called. [ChooseAnswer.taken] learns
  /// the board's cue; [ChooseAnswer.stale] (`409 wrong_stage`,
  /// `409 already_chosen`, any refusal) changes nothing here: the stage has
  /// moved on or the server has the choose, and the caller fetches `/me/`.
  /// Only [ChooseAnswer.notSent], or a Future that fails (no answer at all),
  /// shows "Not sent." with "Try again".
  final Future<ChooseAnswer> Function(String stage, List<NightPick> picks)
  onChoose;

  /// Cards per row at most: four for a small table, five for a large one,
  /// and four with large text.
  static const perRowSmallTable = 4;
  static const perRow = 5;
  static const perRowLargeText = 4;

  /// A table this small or smaller has [perRowSmallTable] to a row.
  static const smallTable = 6;

  /// From this text scale the board wraps to [perRowLargeText].
  static const largeText = 1.3;

  @override
  ConsumerState<NightBoard> createState() => _NightBoardState();
}

class _NightBoardState extends ConsumerState<NightBoard> {
  final _replay = CueReplay();
  var _picks = <NightPick>[];

  /// What Choose sent this turn; null until it is pressed.
  List<NightPick>? _sent;
  var _failed = false;

  /// Which send is the latest: an answer to an older one, or to an earlier
  /// turn, is ignored.
  var _sends = 0;

  @override
  void didUpdateWidget(NightBoard old) {
    super.didUpdateWidget(old);
    if (old.prompt.stage != widget.prompt.stage ||
        old.prompt.turn != widget.prompt.turn) {
      _sends++;
      _picks = [];
      _sent = null;
      _failed = false;
    }
  }

  @override
  void dispose() {
    _replay.dispose();
    super.dispose();
  }

  void _tap(NightPick pick) {
    if (_sent != null) return;
    setState(() => _picks = widget.prompt.rule.tap(_picks, pick));
  }

  void _choose() {
    setState(() => _sent = _picks);
    _send();
  }

  void _retry() {
    setState(() => _failed = false);
    _send();
  }

  void _send() {
    final send = ++_sends;
    bool current() => mounted && send == _sends;
    void failed() {
      if (current()) setState(() => _failed = true);
    }

    unawaited(
      widget
          .onChoose(widget.prompt.stage, _sent!)
          .then(
            (answer) => switch (answer) {
              ChooseAnswer.taken when current() =>
                ref.read(learnedCuesProvider.notifier).learn(Cue.nightChoose),
              ChooseAnswer.notSent => failed(),
              _ => null,
            },
            onError: (Object _) => failed(),
          ),
    );
  }

  String _caption(NightPick pick) => switch (pick) {
    SelfPick() => NightCopy.you,
    CenterPick(:final index) => centerName(index),
    PlayerPick(:final playerId) =>
      widget.seats.firstWhere((s) => s.id == playerId).name,
  };

  Widget _button() {
    if (_sent != null) return const PrimaryButton.done(label: NightCopy.chosen);
    if (!widget.prompt.rule.fits(_picks)) {
      return PrimaryButton.locked(
        label: _picks.isEmpty ? NightCopy.chooseNone : NightCopy.chooseMore,
        onLockedTap: _replay.replay,
      );
    }
    final label = _picks.length == 1 && _picks.single is SelfPick
        ? NightCopy.keep
        : NightCopy.choose.fill({'cards': _picks.map(_caption).join(', ')});
    return PrimaryButton(label: label, onPressed: _choose);
  }

  @override
  Widget build(BuildContext context) {
    final type = context.skin.typography;
    final large =
        MediaQuery.textScalerOf(context).scale(1) >= NightBoard.largeText;
    final perRow = large
        ? NightBoard.perRowLargeText
        : widget.seats.length <= NightBoard.smallTable
        ? NightBoard.perRowSmallTable
        : NightBoard.perRow;
    final cards = [
      for (final seat in widget.seats)
        seat.id == widget.selfId ? _you(seat) : _player(seat),
    ];
    final center = [for (var i = 0; i < 3; i++) _center(i)];

    return TeachOnce(
      cue: Cue.nightChoose,
      replay: _replay,
      builder: (context, teaching) {
        var index = 0;
        Widget wave(Widget card) => CueWave(
          play: teaching,
          index: index++,
          distance: CueWave.boardLift,
          child: card,
        );
        // The board is the screen: high, under the title.
        return ScreenFrame(
          ground: GroundKind.night,
          body: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
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
                padding: const EdgeInsets.only(top: Space.xl),
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
          actions: [
            if (_failed)
              Notice(
                message: BannerCopy.notSent,
                action: BannerCopy.tryAgain,
                onAction: _retry,
              ),
            _button(),
          ],
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
    cue: Cue.holdYou,
    face: widget.face,
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
