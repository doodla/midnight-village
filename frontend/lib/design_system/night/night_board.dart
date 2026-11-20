import 'dart:async';
import 'dart:math' as math;

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
import '../skin/skin_tilt.dart';
import '../teach/cue_wave.dart';
import '../teach/learned_store.dart';
import '../teach/teach_once.dart';
import '../teach/teaching_hold.dart';
import 'board_layout.dart';
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
  /// `409 already_chosen`) changes nothing here: the stage has moved on or
  /// the server has the choose, and the caller fetches `/me/`.
  /// [ChooseAnswer.refused] (any other `4xx`) arms the board again, the
  /// picks still lifted. Only [ChooseAnswer.notSent], or a Future that fails
  /// (no answer at all), shows "Not sent." with "Try again".
  final Future<ChooseAnswer> Function(String stage, List<NightPick> picks)
  onChoose;

  /// The board's words (the title, the seconds, the names and captions)
  /// grow with the text size up to this: the cards are what the board
  /// shows, and larger words would leave no room for them.
  static const labelScale = 1.3;

  /// The button's words grow further, as far as a held face's.
  static const buttonScale = 1.6;

  @override
  ConsumerState<NightBoard> createState() => _NightBoardState();
}

class _NightBoardState extends ConsumerState<NightBoard> {
  final _replay = CueReplay();
  var _picks = <NightPick>[];

  /// What Choose sent this turn; null until it is pressed (empty when the
  /// server already had the turn's choose before this board was shown).
  late List<NightPick>? _sent = _usedUp(widget.prompt);
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
      _sent = _usedUp(widget.prompt);
      _failed = false;
    } else {
      // The server counted a choose this board did not send.
      _sent ??= _usedUp(widget.prompt);
    }
  }

  @override
  void dispose() {
    _replay.dispose();
    super.dispose();
  }

  static List<NightPick>? _usedUp(ChoosePrompt prompt) =>
      prompt.used ? const [] : null;

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
              ChooseAnswer.refused when current() => setState(
                () => _sent = null,
              ),
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
    final skin = context.skin;
    final type = skin.typography;
    final names = [for (final seat in widget.seats) seat.name, NightCopy.you];
    final captions = [for (var i = 0; i < 3; i++) centerName(i)];
    final tilt = [
      for (var i = 0; i < 3; i++) skin.tilt.angle(Tilt.scatter(i)).abs(),
    ].reduce(math.max);

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
        // The board is the screen: the title and the seconds, the table's
        // seats in balanced rows, and the table's own three cards on their
        // strip above the button.
        return MediaQuery.withClampedTextScaling(
          maxScaleFactor: NightBoard.buttonScale,
          child: ScreenFrame(
            ground: GroundKind.night,
            fitsHeight: true,
            body: MediaQuery.withClampedTextScaling(
              maxScaleFactor: NightBoard.labelScale,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _header(context),
                  const SizedBox(height: Space.xl),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, room) {
                        // The wave runs left to right, top to bottom, from 0
                        // each time the board is laid out.
                        index = 0;
                        final layout = BoardLayout.solve(
                          seats: widget.seats.length,
                          names: names,
                          captions: captions,
                          room: room.biggest,
                          nameStyle: type.nameSmall,
                          captionStyle: type.caption,
                          scaler: MediaQuery.textScalerOf(context),
                          place: NightCopy.you,
                          placePadding: FaceDownCard.placeCardPadding,
                          tilt: tilt,
                        );
                        return _board(layout, room.biggest, wave);
                      },
                    ),
                  ),
                ],
              ),
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
          ),
        );
      },
    );
  }

  /// The title, on two lines where one would set it small, and the seconds.
  Widget _header(BuildContext context) => Row(
    spacing: Space.md,
    children: [
      Expanded(
        child: Semantics(
          header: true,
          child: FitWords(
            CommonCopy.nightTitle,
            maxLines: 2,
            style: context.skin.typography.screenTitle,
          ),
        ),
      ),
      WorldTimer.candleCompact(secondsLeft: widget.secondsLeft),
    ],
  );

  /// The seats in [layout]'s rows, then the table's strip; what is to spare
  /// goes above the seats and between them and the table, half each.
  Widget _board(
    BoardLayout layout,
    Size room,
    Widget Function(Widget card) wave,
  ) {
    final spare = math.max(0.0, room.height - layout.used);
    var at = 0;
    final rows = [
      for (final count in layout.rows)
        [for (var i = 0; i < count; i++) widget.seats[at++]],
    ];
    Widget seat(NightSeat seat) => SizedBox(
      width: layout.column,
      child: wave(
        seat.id == widget.selfId ? _you(seat, layout) : _player(seat, layout),
      ),
    );
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SizedBox(height: spare / 2),
        for (final (i, row) in rows.indexed) ...[
          if (i > 0) const SizedBox(height: BoardLayout.rowGap),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            crossAxisAlignment: CrossAxisAlignment.start,
            spacing: BoardLayout.columnGap,
            children: [for (final s in row) seat(s)],
          ),
        ],
        SizedBox(height: BoardLayout.tableGap + spare / 2),
        _table(layout, wave),
      ],
    );
  }

  /// The table's own three cards: smaller, dropped at a slant, on a strip
  /// of the table.
  Widget _table(BoardLayout layout, Widget Function(Widget card) wave) {
    final skin = context.skin;
    return Container(
      padding: const EdgeInsets.all(BoardLayout.tablePadding),
      decoration: BoxDecoration(
        color: context.ground.panel,
        borderRadius: BorderRadius.circular(skin.shape.radius),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: BoardLayout.tableCardGap,
        children: [
          for (var i = 0; i < 3; i++)
            SizedBox(
              width: layout.centerColumn,
              child: wave(_center(i, layout)),
            ),
        ],
      ),
    );
  }

  Widget _player(NightSeat seat, BoardLayout layout) {
    final pick = PlayerPick(seat.id);
    return FaceDownCard(
      size: FaceDownSize.board,
      cardWidth: layout.cardWidth,
      nameSize: layout.nameSize,
      nameHeight: layout.nameHeight,
      owner: seat.token,
      ownerName: seat.name,
      selected: _picks.contains(pick),
      semanticLabel: seat.name,
      onTap: () => _tap(pick),
    );
  }

  Widget _center(int index, BoardLayout layout) {
    final pick = CenterPick(index);
    return FaceDownCard(
      size: FaceDownSize.board,
      cardWidth: layout.centerWidth,
      caption: centerName(index),
      tilt: Tilt.scatter(index),
      selected: _picks.contains(pick),
      semanticLabel: centerName(index),
      onTap: () => _tap(pick),
    );
  }

  Widget _you(NightSeat seat, BoardLayout layout) => TeachingHold(
    target: NightCopy.you,
    cue: Cue.holdYou,
    face: widget.face,
    cover: (teaching) => FaceDownCard(
      size: FaceDownSize.board,
      cardWidth: layout.cardWidth,
      nameSize: layout.nameSize,
      nameHeight: layout.nameHeight,
      owner: seat.token,
      ownerName: NightCopy.you,
      mine: true,
      selected: _picks.contains(const SelfPick()),
      semanticLabel: NightCopy.you,
      hold: teaching,
      onTap: () => _tap(const SelfPick()),
    ),
  );
}
