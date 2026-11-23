import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../../../../design_system/copy/copy.dart';
import '../../../../design_system/models/role.dart';
import '../../../../design_system/primitives/board_pieces.dart';
import '../../../../design_system/primitives/paper_scrap.dart';
import '../../../../design_system/primitives/primary_button.dart';
import '../../../../design_system/skin/skin.dart';
import '../../domain/end_board.dart';
import '../../domain/end_board_metrics.dart';

// The foot of the end board, on the cobbles: "What happened" and the three
// cards nobody held on a row; then, for the host, "Edit deck" and the amber
// "Play again", and for a guest "Leave" and who deals next. Fixed to the
// bottom of the screen whatever the board does. Positions are from the SPEC's
// 360 x 780 phone, measured from the foot's top.

/// Where each piece of the foot lies, from the foot's top (y) and the screen's
/// edges (x).
abstract final class EndFootAt {
  static const whatHappenedLeft = 8.0;
  static const whatHappenedTop = 14.0;
  static const whatHappenedWidth = 139.0;
  static const whatHappenedTurn = -3 * math.pi / 180;

  static const middleTop = 22.0;
  static const middleRight = 6.0;
  static const middleApart = 3.0;
  static const middleLeast = 52.0;
  static const middlePortrait = Size(44, 33);
  static const middleStrip = 14.0;
  static const fanRise = 29.0;

  static const rowTop = 80.0;
  static const editLeft = 10.0;
  static const editWidth = 97.0;
  static const editTurn = 2 * math.pi / 180;
  static const leaveWidth = 76.0;
  static const playLeft = 121.0;
  static const playRight = 8.0;
  static const dealsLeft = 96.0;
}

/// The foot's pieces as children of the page's stack.
List<Widget> endFootPieces(
  BuildContext context, {
  required EndBoardPlan plan,
  required double top,
  required bool playAgainBusy,
  required VoidCallback onWhatHappened,
  required VoidCallback onEditDeck,
  required VoidCallback onPlayAgain,
  required VoidCallback onLeave,
}) {
  final width = plan.screen.width;
  final foot = plan.foot;
  return [
    if (foot.whatHappened)
      Positioned(
        left: EndFootAt.whatHappenedLeft,
        top: top + EndFootAt.whatHappenedTop,
        child: Transform.rotate(
          angle: EndFootAt.whatHappenedTurn,
          child: PaperScrap(
            label: EndCopy.whatHappened,
            onTap: onWhatHappened,
            width: EndFootAt.whatHappenedWidth,
          ),
        ),
      ),
    ..._middle(context, plan, top),
    if (foot.host) ...[
      Positioned(
        left: EndFootAt.editLeft,
        top: top + EndFootAt.rowTop - 2,
        child: Transform.rotate(
          angle: EndFootAt.editTurn,
          child: PaperScrap(
            label: EndCopy.editDeck,
            onTap: onEditDeck,
            width: EndFootAt.editWidth,
          ),
        ),
      ),
      Positioned(
        left: EndFootAt.playLeft,
        right: EndFootAt.playRight,
        top: top + EndFootAt.rowTop - 8,
        child: PrimaryButton(
          label: EndCopy.playAgain,
          onPressed: onPlayAgain,
          busy: playAgainBusy,
          size: ButtonSize.large,
        ),
      ),
    ] else ...[
      Positioned(
        left: EndFootAt.editLeft,
        top: top + EndFootAt.rowTop - 2,
        child: PaperScrap(
          label: EndCopy.leave,
          onTap: onLeave,
          width: EndFootAt.leaveWidth,
        ),
      ),
      if (foot.hostName case final host?)
        Positioned(
          left: EndFootAt.dealsLeft,
          top: top + EndFootAt.rowTop + 2,
          child: PaperSlip(
            label: EndCopy.hostDealsNext.fill({'host': host}),
            maxWidth: width - EndFootAt.dealsLeft - EndFootAt.playRight,
          ),
        ),
    ],
  ];
}

/// The three middle cards: on a row when they fit beside "What happened",
/// otherwise a small fan (the first at the left, the third at the right, the
/// middle one raised and on top) so every role stays whole.
List<Widget> _middle(BuildContext context, EndBoardPlan plan, double top) {
  final skin = context.skin;
  final scaler = MediaQuery.textScalerOf(context);
  final direction = Directionality.of(context);
  double roleWidth(RoleId role) {
    final p = TextPainter(
      text: TextSpan(text: role.displayName, style: skin.typography.tag),
      textDirection: direction,
      textScaler: scaler,
      maxLines: 1,
    )..layout();
    final w = p.width;
    p.dispose();
    return w;
  }

  final line = TextPainter(
    text: TextSpan(text: 'Ag', style: skin.typography.tag),
    textDirection: direction,
    textScaler: scaler,
    maxLines: 1,
  )..layout();
  final strip = math.max(EndFootAt.middleStrip, line.height + 2);
  line.dispose();
  final roles = plan.centre;
  final widths = [
    for (final r in roles)
      math.max(EndFootAt.middleLeast, roleWidth(r) + EndMetrics.roleRoom),
  ];
  final height =
      EndFootAt.middlePortrait.height +
      2 * BoardCard.inset +
      (strip - EndFootAt.middleStrip);
  final right = plan.screen.width - EndFootAt.middleRight;
  final room =
      right -
      (EndFootAt.whatHappenedLeft +
          EndFootAt.whatHappenedWidth +
          2 * EndFootAt.middleApart +
          EndFootAt.middleRight);
  final total =
      widths.fold(0.0, (a, b) => a + b) +
      EndFootAt.middleApart * (roles.length - 1);
  final fits = total <= room || !plan.foot.whatHappened && total <= right;
  final y = top + EndFootAt.middleTop;
  Widget card(int i, double left, double upBy) {
    final rect = Rect.fromLTWH(left, y - upBy, widths[i], height);
    return Positioned(
      left: rect.left,
      top: rect.top,
      width: rect.width,
      height: rect.height,
      child: BoardCard(
        role: roles[i],
        strip: roles[i].displayName,
        paper: BoardPaper.winner,
        size: rect.size,
        portraitWidth: EndFootAt.middlePortrait.width,
        rect: rect,
        angle: (i - 1) * 2 * math.pi / 180,
        stripHeight: strip,
        semantics: roles[i].displayName,
      ),
    );
  }

  if (roles.length != 3) return const [];
  if (fits) {
    var left = right - total;
    return [
      for (var i = 0; i < 3; i++)
        card(i, left += i == 0 ? 0 : widths[i - 1] + EndFootAt.middleApart, 0),
    ];
  }
  // A fan: the first at the left of the room, the third at the right, the
  // middle one raised and on top.
  final span = math.min(right - 8, widths[0] + widths[2] + widths[1] * 0.5);
  final first = right - span;
  final third = right - widths[2];
  final middle = (first + third) / 2 + (widths[0] - widths[2]) / 4;
  return [
    card(0, first, 0),
    card(2, third, 0),
    card(1, middle, EndFootAt.fanRise),
  ];
}
