import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/widgets.dart';

import '../../../../design_system/primitives/pending.dart' show RequestFailure;
import '../../../../design_system/copy/copy.dart';
import '../../../../design_system/layout/space.dart';
import '../../../../design_system/models/role.dart';
import '../../../../design_system/primitives/board_pieces.dart';
import '../../../../design_system/primitives/notice.dart';
import '../../../../design_system/primitives/paper_scrap.dart';
import '../../../../design_system/primitives/primary_button.dart';
import '../../../../design_system/skin/skin.dart';
import '../../domain/end_board.dart';
import '../../domain/end_board_metrics.dart';
import '../../domain/end_story.dart';
import '../../domain/night_timeline.dart';

import 'end_night.dart';
import 'end_reveal.dart';

// The foot of the end board, on the cobbles, under the board's window: "What
// happened" and the three cards nobody held on a row; then, for the host,
// "Edit deck" and the amber "Play again", and for a guest "Leave" and who
// deals next. Its rows are as tall as what is in them, measured at the phone's
// text size, and its air is less on a short phone; the board's window is what
// is left above it. Its torn lip lies over the board's foot.

/// The middle cards' portrait, the least a middle card is wide, and the paper
/// beside its role's tab (the tab is the role and 5 each side).
const _middlePortrait = Size(44, 33);
const _middleLeast = 52.0;
const _middleRoom = 2 * BoardCard.stripPad + 2;

/// How far apart the middle cards stand, and how much each is turned.
const _middleApart = 3.0;
const _middleTurn = 1.5 * math.pi / 180;
const _whatHappenedTurn = -3 * math.pi / 180;
const _editTurn = 2 * math.pi / 180;

/// What a control at the foot asks for: the one on its way shows busy, and
/// the others take no second request.
enum EndAct { playAgain, editDeck, leave }

class EndFootBand extends StatelessWidget {
  const EndFootBand({
    super.key,
    required this.foot,
    required this.centre,
    required this.screenHeight,
    required this.busy,
    required this.onWhatHappened,
    required this.onEditDeck,
    required this.onPlayAgain,
    required this.onLeave,
    this.failure,
    this.onTryAgain,
  });

  final EndFoot foot;
  final List<RoleId> centre;
  final double screenHeight;
  final EndAct? busy;

  /// The last request did not work: one quiet line over the controls, with
  /// "Try again" where it may be sent again.
  final RequestFailure? failure;
  final VoidCallback? onTryAgain;
  final VoidCallback onWhatHappened;
  final VoidCallback onEditDeck;
  final VoidCallback onPlayAgain;
  final VoidCallback onLeave;

  @override
  Widget build(BuildContext context) {
    final tall = EndMetrics.tallness(screenHeight);
    double air(double short, double tallAir) =>
        lerpDouble(short, tallAir, tall)!;
    final top = air(Space.sm, Space.lgPlus);
    final between = air(Space.sm, Space.md);
    final bottom =
        air(Space.sm, Space.lgPlus) + MediaQuery.paddingOf(context).bottom;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        const Positioned(
          left: 0,
          right: 0,
          top: -EndMetrics.lip,
          bottom: 0,
          child: BoardFoot(height: double.infinity),
        ),
        Padding(
          padding: EdgeInsets.fromLTRB(Space.sm, top, Space.sm, bottom),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              if (failure case final failure?) ...[
                Notice(
                  message: failure.words,
                  action: failure.canRetry ? BannerCopy.tryAgain : null,
                  onAction: failure.canRetry ? onTryAgain : null,
                ),
                SizedBox(height: between),
              ],
              LayoutBuilder(
                builder: (context, box) => _firstRow(context, box.maxWidth),
              ),
              SizedBox(height: between),
              foot.host ? _hostRow(context) : _guestRow(context),
            ],
          ),
        ),
        // The first time the night plays, the cue that it goes on: on the
        // board's lower edge, over the lip.
        const Positioned(
          left: 0,
          right: 0,
          top: -EndMetrics.lip / 2,
          child: Center(child: NightCue()),
        ),
      ],
    );
  }

  /// "What happened" at the left and the middle cards at the right, on one
  /// row when they fit (its words on two lines if that makes them fit);
  /// otherwise the cards take a row of their own above.
  Widget _firstRow(BuildContext context, double width) {
    final cards = _MiddleCards(roles: centre);
    if (!foot.whatHappened) {
      return Align(alignment: Alignment.centerRight, child: cards);
    }
    // While the night plays the same scrap leads back to the result: as wide
    // as the wider of its two labels, so nothing beside it moves.
    double wide(String day) =>
        math.max(_scrapWidth(context, day), _scrapWidth(context, _backOf(day)));
    Widget scrap(String label) => Transform.rotate(
      angle: _whatHappenedTurn,
      child: _NightScrap(day: label, width: wide(label), onTap: onWhatHappened),
    );
    final room = width - Space.xs - cards.widthIn(context);
    for (final label in [EndCopy.whatHappened, EndCopy.whatHappenedTwoLines]) {
      if (wide(label) <= room) {
        return Row(
          crossAxisAlignment: CrossAxisAlignment.center,
          children: [scrap(label), const Spacer(), cards],
        );
      }
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        Align(alignment: Alignment.centerRight, child: cards),
        // Clear of the turned scrap's corners.
        const SizedBox(height: Space.md),
        Align(
          alignment: Alignment.centerLeft,
          child: scrap(EndCopy.whatHappened),
        ),
      ],
    );
  }

  Widget _hostRow(BuildContext context) => Row(
    crossAxisAlignment: CrossAxisAlignment.center,
    children: [
      Transform.rotate(
        angle: _editTurn,
        child: PaperScrap(
          label: EndCopy.editDeck,
          onTap: onEditDeck,
          sends: true,
          busy: busy == EndAct.editDeck,
        ),
      ),
      const SizedBox(width: Space.md),
      Expanded(
        // Busy stays a live look; while Edit deck is on its way it says so.
        child: busy == null || busy == EndAct.playAgain
            ? PrimaryButton(
                label: EndCopy.playAgain,
                onPressed: onPlayAgain,
                busy: busy == EndAct.playAgain,
                size: ButtonSize.large,
              )
            : PrimaryButton.waiting(
                label: EndCopy.playAgain,
                reason: SpokenCopy.working,
                size: ButtonSize.large,
              ),
      ),
    ],
  );

  /// "Leave", and beside it in plain words who deals next (not a control).
  Widget _guestRow(BuildContext context) {
    final type = context.skin.typography;
    return Row(
      crossAxisAlignment: CrossAxisAlignment.center,
      children: [
        PaperScrap(
          label: EndCopy.leave,
          onTap: onLeave,
          pinned: false,
          sends: true,
          busy: busy == EndAct.leave,
        ),
        const SizedBox(width: Space.md),
        if (foot.hostName case final host?)
          Expanded(
            child: Text(
              EndCopy.hostDealsNext.fill({'host': host}),
              style: type.name.copyWith(color: context.ground.text),
            ),
          )
        else
          const Spacer(),
      ],
    );
  }

  /// How wide a pinned scrap of [label] is: its widest line, its padding,
  /// its pin.
  static double _scrapWidth(BuildContext context, String label) {
    final skin = context.skin;
    return label
            .split('\n')
            .map((line) => _textWidth(context, line, skin.typography.name))
            .fold(0.0, math.max) +
        2 * Space.md +
        skin.parts.pinSize;
  }
}

/// The scrap's words at night for its words [day] (on as many lines).
String _backOf(String day) =>
    day.contains('\n') ? EndCopy.backToResultTwoLines : EndCopy.backToResult;

/// "What happened" by day; while the night plays, the way back to the result,
/// in the same place and the same paper.
class _NightScrap extends StatelessWidget {
  const _NightScrap({
    required this.day,
    required this.width,
    required this.onTap,
  });

  final String day;
  final double width;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final on = EndNightScope.maybeOf(context)?.on ?? false;
    return PaperScrap(
      label: on ? _backOf(day) : day,
      id: EndCopy.whatHappened,
      width: width,
      onTap: onTap,
    );
  }
}

double _textWidth(BuildContext context, String text, TextStyle style) {
  final p = TextPainter(
    text: TextSpan(text: text, style: style),
    textDirection: Directionality.of(context),
    textScaler: MediaQuery.textScalerOf(context),
    maxLines: 1,
  )..layout();
  final w = p.width;
  p.dispose();
  return w;
}

/// The three cards nobody held, face up, side by side and level; past the
/// width they have, they wrap to a second row, right-aligned.
class _MiddleCards extends StatelessWidget {
  const _MiddleCards({required this.roles});

  final List<RoleId> roles;

  /// Each card's size at this phone's text size.
  List<Size> _sizes(BuildContext context) {
    final type = context.skin.typography;
    final scaler = MediaQuery.textScalerOf(context);
    final strip = math.max(
      EndMetrics.stripHeight,
      scaler.scale(type.tag.fontSize!) * (type.tag.height ?? 1.2) + 2,
    );
    final height =
        BoardCard.inset +
        _middlePortrait.height +
        EndMetrics.cardFoot +
        (strip - EndMetrics.stripHeight);
    // Each as wide as every role it shows, the night's too (What happened
    // turns it in place).
    final story = EndNightScope.read(context)?.story;
    List<RoleId> held(int i) => [
      roles[i],
      if (story != null)
        for (final faces in [story.dealt, ...story.steps.map((s) => s.after)])
          if (i < faces.centre.length) faces.centre[i].strip,
    ];
    return [
      for (var i = 0; i < roles.length; i++)
        Size(
          held(i)
                  .map((r) => _textWidth(context, r.displayName, type.tag))
                  .fold(_middleLeast - _middleRoom, math.max) +
              _middleRoom,
          height,
        ),
    ];
  }

  double widthIn(BuildContext context) {
    final sizes = _sizes(context);
    return sizes.fold(0.0, (a, s) => a + s.width) +
        _middleApart * math.max(0, sizes.length - 1);
  }

  @override
  Widget build(BuildContext context) {
    final type = context.skin.typography;
    final scaler = MediaQuery.textScalerOf(context);
    final strip = math.max(
      EndMetrics.stripHeight,
      scaler.scale(type.tag.fontSize!) * (type.tag.height ?? 1.2) + 2,
    );
    final sizes = _sizes(context);
    final night = EndNightScope.maybeOf(context);
    if (night != null && night.on && night.story != null) {
      return _atNight(context, night, sizes, strip);
    }
    final driver = EndRevealScope.maybeOf(context);
    // In the reveal they lie face down and turn with the last row.
    Widget turning(int i, Widget face) => driver == null
        ? face
        : revealMiddleTurn(
            driver,
            size: sizes[i],
            portraitWidth: _middlePortrait.width,
            angle: (i - 1) * _middleTurn,
            face: face,
          );
    return Semantics(
      label: EndCopy.middle.fill({
        'roles': roles.map((r) => r.displayName).join(EndCopy.listComma),
      }),
      excludeSemantics: true,
      child: Wrap(
        alignment: WrapAlignment.end,
        spacing: _middleApart,
        runSpacing: Space.xs,
        children: [
          for (var i = 0; i < roles.length; i++)
            SizedBox.fromSize(
              size: sizes[i],
              child: turning(
                i,
                BoardCard(
                  role: roles[i],
                  strip: roles[i].displayName,
                  paper: BoardPaper.winner,
                  size: sizes[i],
                  portraitWidth: _middlePortrait.width,
                  rect: Offset.zero & sizes[i],
                  angle: (i - 1) * _middleTurn,
                  stripHeight: strip,
                  semantics: roles[i].displayName,
                ),
              ),
            ),
        ],
      ),
    );
  }

  BoardCard _card(int i, Size size, double strip, StoryFace f, BoardPaper p) =>
      BoardCard(
        role: f.face,
        strip: f.strip.displayName,
        paper: p,
        size: size,
        portraitWidth: _middlePortrait.width,
        rect: Offset.zero & size,
        angle: (i - 1) * _middleTurn,
        stripHeight: strip,
        semantics: f.strip.displayName,
      );

  /// At night: the cards in the middle at this step, turning as the step
  /// moves one (and at the night's opening from the result to the deal).
  Widget _atNight(
    BuildContext context,
    EndNight night,
    List<Size> sizes,
    double strip,
  ) {
    final before = night.before.centre, after = night.after.centre;
    final lifted = {
      for (final p in night.current?.places ?? const <CardPlace>[])
        if (p is CenterPlace) p.index,
    };
    Widget turned(int i) {
      final size = sizes[i];
      final box = Offset.zero & size;
      Widget face(StoryFace f) => _card(i, size, strip, f, paperAtNight(f));
      Widget card = before[i] == after[i]
          ? face(after[i])
          : RevealTurn(
              driver: night.driver,
              value: night.moveTurn,
              backAt: box,
              back: face(before[i]),
              face: face(after[i]),
            );
      if (night.opening) {
        final role = roles[i];
        card = RevealTurn(
          driver: night.driver,
          value: night.dealTurn,
          backAt: box,
          back: _card(i, size, strip, (
            face: role,
            strip: role,
          ), BoardPaper.winner),
          face: card,
        );
      }
      return card;
    }

    return Semantics(
      label: EndCopy.middle.fill({
        'roles': after.map((f) => f.strip.displayName).join(EndCopy.listComma),
      }),
      excludeSemantics: true,
      child: Wrap(
        alignment: WrapAlignment.end,
        spacing: _middleApart,
        runSpacing: Space.xs,
        children: [
          for (var i = 0; i < roles.length; i++)
            if (lifted.contains(i))
              // Lifted onto the board beside the one who acted, for the step
              // (`NightBoard`): its place here stands empty.
              SizedBox.fromSize(size: sizes[i])
            else
              SizedBox.fromSize(
                key: night.placeKey(CenterPlace(i)),
                size: sizes[i],
                child: turned(i),
              ),
        ],
      ),
    );
  }
}
