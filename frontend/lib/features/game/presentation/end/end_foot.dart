import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/widgets.dart';

import '../../../../design_system/copy/copy.dart';
import '../../../../design_system/layout/space.dart';
import '../../../../design_system/models/role.dart';
import '../../../../design_system/primitives/board_pieces.dart';
import '../../../../design_system/primitives/paper_scrap.dart';
import '../../../../design_system/primitives/primary_button.dart';
import '../../../../design_system/skin/skin.dart';
import '../../domain/end_board.dart';
import '../../domain/end_board_metrics.dart';

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

class EndFootBand extends StatelessWidget {
  const EndFootBand({
    super.key,
    required this.foot,
    required this.centre,
    required this.screenHeight,
    required this.playAgainBusy,
    required this.onWhatHappened,
    required this.onEditDeck,
    required this.onPlayAgain,
    required this.onLeave,
  });

  final EndFoot foot;
  final List<RoleId> centre;
  final double screenHeight;
  final bool playAgainBusy;
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
              LayoutBuilder(
                builder: (context, box) => _firstRow(context, box.maxWidth),
              ),
              SizedBox(height: between),
              foot.host ? _hostRow(context) : _guestRow(context),
            ],
          ),
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
    Widget scrap(String label) => Transform.rotate(
      angle: _whatHappenedTurn,
      child: PaperScrap(label: label, onTap: onWhatHappened),
    );
    final room = width - Space.xs - cards.widthIn(context);
    for (final label in [EndCopy.whatHappened, EndCopy.whatHappenedTwoLines]) {
      if (_scrapWidth(context, label) <= room) {
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
        child: PaperScrap(label: EndCopy.editDeck, onTap: onEditDeck),
      ),
      const SizedBox(width: Space.md),
      Expanded(
        child: PrimaryButton(
          label: EndCopy.playAgain,
          onPressed: onPlayAgain,
          busy: playAgainBusy,
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
        PaperScrap(label: EndCopy.leave, onTap: onLeave, pinned: false),
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
    return [
      for (final r in roles)
        Size(
          math.max(
            _middleLeast,
            _textWidth(context, r.displayName, type.tag) + _middleRoom,
          ),
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
}
