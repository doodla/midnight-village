import 'dart:async';
import '../feel/atmo_parts.dart';
import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../copy/copy.dart';
import '../faces/face_content.dart';
import '../layout/space.dart';
import '../models/role.dart';
import '../primitives/candle_gauge.dart';
import '../primitives/face_down_card.dart';
import '../primitives/fit_line.dart';
import '../primitives/notice.dart';
import '../primitives/paper_banner.dart';
import '../primitives/paper_card.dart';
import '../primitives/paper_piece.dart';
import '../skin/dress_style.dart';
import '../primitives/primary_button.dart';
import '../primitives/screen_frame.dart';
import '../primitives/text_backing.dart';
import '../skin/art_set.dart' show LayeredSceneId;
import '../primitives/world_timer.dart';
import '../skin/dress.dart';
import '../skin/ground.dart';
import '../skin/skin.dart';
import '../skin/skin_tilt.dart';
import '../skin/skin_type.dart';
import '../teach/cue_wave.dart';
import '../teach/learned_store.dart';
import '../teach/teach_once.dart';
import '../teach/teaching_hold.dart';
import 'board_layout.dart';
import 'choose_prompt.dart';
import 'night_pick.dart';

part 'night_board_pieces.dart';

/// The night (06), sections 3, 7 and 8 of the first-time play spec.
///
/// - Drawn from [seats]: the other players in seat order, in rows
///   ([BoardLayout]); in front of them the viewer's own card, "You", on its
///   paper place, beside Left, Middle and Right on their strip: the same
///   cards, places, lift and button on every phone, whatever the role.
/// - "You" shows the role this phone was dealt, face up ([dealt]); holding it
///   shows [face] (what this phone may do, and what the night changed). The
///   hold is taught on 04, not here. Nothing waits on the hold; a tap on "You"
///   picks it at once.
/// - A tap selects a card the prompt's rule can take (lift plus the
///   selection's outline) and unselects a chosen one; a card it cannot take
///   does not select. "You" alone (do nothing) is always a choice. The picks
///   are always that, one of the rule's shapes or the start of one, so a
///   slip cannot waste the turn.
/// - The button: "Choose a card" and "Choose 1 more" are locked (a tap
///   replays the wave over the cards), then "Choose {cards}", or "Keep my
///   card" for "You" alone; "Chosen" from the moment it is pressed.
/// - A board with nothing to choose ([ChoosePrompt.sleeps]) asks nothing: no
///   button, "Nothing to do" quiet in its place; a tap on a card bobs it
///   (a fidget, cover for anyone who wants it) and picks or sends nothing.
/// - One Choose per turn. The board re-arms only when [prompt]'s stage or
///   turn changes ([ChoosePrompt.turn]: the Doppelganger's look giving way
///   to her follow-up), never on the prompt's counts.
/// - Choose changes what the table can see at once and never waits: see
///   [onChoose]. What the server sends back belongs on a held face.
///
/// Hidden information: the role this phone was dealt (which it saw on 04) is
/// shown face up on "You"; what the night changed reaches the board only as
/// [face], while held, and the prompt's rule only decides what the player's
/// own taps select; the board's layout and motion are the same for every role
/// (test/design_system/night/night_layout_test.dart).
class NightBoard extends ConsumerStatefulWidget {
  const NightBoard({
    super.key,
    required this.seats,
    required this.selfId,
    required this.prompt,
    required this.face,
    required this.dealt,
    required this.secondsLeft,
    this.share,
    required this.onChoose,
    this.dress,
  });

  /// How the screen is dressed (`ScreenFrame.dress`; null: as the screen
  /// above it): plain is the look the game has today; paper puts the title and
  /// the seconds on a banner and the mood's own village behind the board
  /// instead of a strip of it.
  final Dress? dress;

  /// The dress the live screen has (`dress` null): the one source the test
  /// pages and their sweeps read, never a second constant.
  static const defaultDress = Dress.paper;

  final List<NightSeat> seats;

  /// The viewer's seat.
  final int selfId;

  /// This phone's prompt, read from `/me/`.
  final ChoosePrompt prompt;

  /// What "You" shows while held.
  final FaceContent face;

  /// The role this phone was DEALT (`NightReport.dealt`), which "You" shows
  /// face up, its portrait and its name (owner, 23 November 2026: a card
  /// that hides who you are makes no sense here). Never a role the night has
  /// since changed: this phone has seen exactly this one on 04, and what
  /// changed is told only on a held [face].
  final RoleId dealt;

  /// The stage's countdown, as the server gives it; null in a window with
  /// no deadline (the candle alone).
  final int? secondsLeft;

  /// How much of the window is left, 0 to 1, for the candle's flame and wax
  /// ([StageShare.left]: the same on every phone); null when the server did
  /// not say how long the window is: the candle whole.
  final double? share;

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

  /// The strip of the night village behind the title shows the picture from
  /// this row of pixels down: its roofs and spire, clear of the moon above,
  /// which would sit under the seconds.
  static const villageFrom = 360.0;

  /// The strip behind the title grows with the height a phone has beyond
  /// [tallPhone], by [stripShare] of it, to at most [stripMost], at a table of
  /// [smallTable] seats.
  static const smallTable = 3;
  static const tallPhone = 700.0;
  static const stripShare = 0.45;
  static const stripMost = 72.0;

  /// The most of the header's width the seconds take.
  static const timerShare = 0.36;

  /// The lines of room a title has, at the full title size.
  static const titleLines = 2;

  @override
  ConsumerState<NightBoard> createState() => _NightBoardState();
}

class _NightBoardState extends ConsumerState<NightBoard>
    with _NightBoardPieces {
  final _replay = CueReplay();
  @override
  var _picks = <NightPick>[];

  /// A sleeper's idle taps: each card's latest one, which bobs it once.
  final _fidgets = <NightPick, int>{};
  var _taps = 0;

  /// What Choose sent this turn; null until it is pressed (empty when the
  /// server already had the turn's choose before this board was shown).
  late List<NightPick>? _sent = _usedUp(widget.prompt);
  var _failed = false;

  /// The candle's cuts have been asked for.
  var _candleWarmed = false;

  /// Which send is the latest: an answer to an older one, or to an earlier
  /// turn, is ignored.
  var _sends = 0;

  /// The last layout and what it was worked out from: the board is rebuilt
  /// every second (the countdown) and on every tap, and measures its names
  /// again only when the names, the room, the text or the skin change.
  (_LayoutKey, BoardLayout)? _layout;

  BoardLayout _layoutFor(_LayoutKey key, BoardLayout Function() solve) {
    if (_layout case (final last, final layout) when last == key) {
      return layout;
    }
    final layout = solve();
    _layout = (key, layout);
    return layout;
  }

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

  @override
  void _tap(NightPick pick) {
    if (widget.prompt.sleeps) {
      setState(() => _fidgets[pick] = ++_taps);
      return;
    }
    if (_sent != null) return;
    setState(() => _picks = widget.prompt.rule.tap(_picks, pick));
  }

  /// [card] bobbing once for its latest idle tap.
  @override
  Widget _fidget(NightPick pick, Widget card) => switch (_fidgets[pick]) {
    final tap? => CueWave(
      key: ValueKey(tap),
      play: true,
      index: 0,
      distance: CueWave.boardLift,
      child: card,
    ),
    null => card,
  };

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
    if (widget.prompt.sleeps) {
      return const PrimaryButton.done(label: NightCopy.nothingToDo);
    }
    if (_sent != null) return const PrimaryButton.done(label: NightCopy.chosen);
    if (!widget.prompt.rule.fits(_picks)) {
      return PrimaryButton.locked(
        label: _picks.isEmpty ? NightCopy.chooseNone : NightCopy.chooseMore,
        onLockedTap: _replay.replay,
        slot: true,
      );
    }
    final kind = widget.prompt.kind;
    final label = _picks.length == 1 && _picks.single is SelfPick
        ? kind.pass
        : kind.go.fill({'cards': _picks.map(_caption).join(', ')});
    return PrimaryButton(label: label, onPressed: _choose, rises: true);
  }

  @override
  Widget build(BuildContext context) => DressScope(
    dress: widget.dress ?? NightBoard.defaultDress,
    child: Builder(builder: _screen),
  );

  Widget _screen(BuildContext context) {
    final skin = context.skin;
    final dressed = context.dress.isPaper;
    final type = skin.typography;
    final names = [for (final seat in widget.seats) seat.name];
    final captions = [for (var i = 0; i < 3; i++) centerName(i)];
    final tilt = [
      for (var i = 0; i < 3; i++) skin.tilt.angle(Tilt.scatter(i)).abs(),
    ].reduce(math.max);

    return TeachOnce(
      cue: Cue.nightChoose,
      replay: _replay,
      builder: (context, teaching) {
        var index = 0;
        // A sleeper is not taught to pick: nothing waves at it.
        Widget wave(Widget card) => CueWave(
          play: teaching && !widget.prompt.sleeps,
          index: index++,
          distance: CueWave.boardLift,
          child: card,
        );
        // The board is the screen: the title and the seconds, the other
        // seats in balanced rows, and in front of the player their own card
        // on its paper place beside the table's three on their strip.
        return MediaQuery.withClampedTextScaling(
          maxScaleFactor: NightBoard.buttonScale,
          child: ScreenFrame(
            ground: GroundKind.night,
            fitsHeight: true,
            // Dressed up the village is the mood behind the whole screen.
            topScene: dressed ? null : LayeredSceneId.nightVillage,
            topSceneFrom: dressed ? null : NightBoard.villageFrom,
            topArtExtra: dressed ? 0 : _stripExtra(context),
            topArtLayout: dressed ? TopArtLayout.scene : TopArtLayout.strip,
            body: MediaQuery.withClampedTextScaling(
              maxScaleFactor: NightBoard.labelScale,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  _header(context),
                  Expanded(
                    child: LayoutBuilder(
                      builder: (context, room) {
                        // The wave runs left to right, top to bottom, from 0
                        // each time the board is laid out.
                        index = 0;
                        final layout = _layoutFor(
                          _LayoutKey(
                            names: names,
                            room: room.biggest,
                            scale: MediaQuery.textScalerOf(context).scale(1),
                            type: type,
                            tilt: tilt,
                            plate: dressed ? 2 * FaceDownCard.nameBleed : 0,
                          ),
                          () => BoardLayout.solve(
                            others: widget.seats.length - 1,
                            names: names,
                            you: NightCopy.you,
                            captions: captions,
                            room: room.biggest,
                            nameStyle: type.nameSmall,
                            captionStyle: type.caption,
                            scaler: MediaQuery.textScalerOf(context),
                            tilt: tilt,
                            plate: dressed ? 2 * FaceDownCard.nameBleed : 0,
                          ),
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

  /// A table of three has two cards a row as wide as the phone allows, and on a
  /// tall phone air to spare: the village strip takes some of it (it is only a
  /// picture; nothing a neighbour could read moves).
  double _stripExtra(BuildContext context) {
    if (widget.seats.length != NightBoard.smallTable) return 0;
    final height = MediaQuery.sizeOf(context).height;
    return ((height - NightBoard.tallPhone) * NightBoard.stripShare).clamp(
      0.0,
      NightBoard.stripMost,
    );
  }

  /// The title in a room two lines high at the full title size (the taller of
  /// that and the timer's line), the same height on every phone whatever the
  /// role (so the board below sits alike): the prompt's words wrap between
  /// words, never leave one word alone on a line, and are set smaller only
  /// where two lines are not enough. Beside it the timer in the one timer
  /// style and the candle, as high as the timer's line.
  Widget _header(BuildContext context) {
    final title = context.skin.typography.screenTitle;
    // The timer is the one timer style (`timerSmall`, as 05, 08 and 09 draw
    // it), at its own size whatever the text scale.
    final timer = context.skin.typography.timerSmall;
    final timerLine = timer.fontSize! * timer.height!;
    // A pixel over two lines: a wrapped title measures a hair more than its
    // lines times the line height.
    final titleRoom =
        MediaQuery.textScalerOf(
              context,
            ).scale(title.fontSize! * title.height!) *
            NightBoard.titleLines +
        1;
    final room = math.max(titleRoom, timerLine);
    // On a banner the candle stands inside the slip, a little lower than the
    // timer's line.
    final candle = context.dress.isPaper
        ? timerLine * context.skin.parts.bannerCandle
        : timerLine;
    if (!_candleWarmed) {
      // The candle's cuts decoded now, for the first frame the board draws.
      _candleWarmed = true;
      CandleGauge.precache(context, candle);
    }
    // The seconds take at most this share of the header (a narrow phone with
    // minutes on the clock sets them smaller): the title keeps its room.
    return LayoutBuilder(
      builder: (context, header) => PaperBanner(
        id: #night,
        bleed: Space.md,
        padding: const EdgeInsets.symmetric(vertical: Space.xxs),
        child: (context) => Row(
          spacing: Space.md,
          children: [
            Expanded(
              child: SizedBox(
                height: room,
                child: Semantics(
                  header: true,
                  child: Align(
                    alignment: AlignmentDirectional.centerStart,
                    child: FitWords(
                      widget.prompt.kind.title,
                      maxLines: NightBoard.titleLines,
                      noWidow: true,
                      style: title,
                    ),
                  ),
                ),
              ),
            ),
            WorldTimer.candleCompact(
              secondsLeft: widget.secondsLeft,
              share: widget.share,
              candleHeight: candle,
              lineHeight: room,
              maxNumberWidth: header.maxWidth * NightBoard.timerShare,
            ),
          ],
        ),
      ),
    );
  }
}

/// What a [BoardLayout] is worked out from.
@immutable
class _LayoutKey {
  const _LayoutKey({
    required this.names,
    required this.room,
    required this.scale,
    required this.type,
    required this.tilt,
    required this.plate,
  });

  final List<String> names;
  final Size room;
  final double scale;
  final SkinType type;
  final double tilt;
  final double plate;

  @override
  bool operator ==(Object other) =>
      other is _LayoutKey &&
      other.plate == plate &&
      listEquals(other.names, names) &&
      other.room == room &&
      other.scale == scale &&
      identical(other.type, type) &&
      other.tilt == tilt;

  @override
  int get hashCode =>
      Object.hash(Object.hashAll(names), room, scale, tilt, plate);
}
