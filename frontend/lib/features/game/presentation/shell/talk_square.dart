import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../design_system/copy/copy.dart';
import '../../../../design_system/faces/face_content.dart';
import '../../../../design_system/faces/held_face.dart';
import '../../../../design_system/layout/space.dart';
import '../../../../design_system/models/role.dart';
import '../../../../design_system/night/night_pick.dart';
import '../../../../design_system/primitives/board_pieces.dart';
import '../../../../design_system/primitives/deck_pile.dart';
import '../../../../design_system/primitives/name_tag.dart';
import '../../../../design_system/primitives/primary_button.dart';
import '../../../../design_system/primitives/role_sheet_body.dart';
import '../../../../design_system/primitives/screen_frame.dart';
import '../../../../design_system/primitives/sheet_scaffold.dart';
import '../../../../design_system/skin/skin.dart';

/// The square's measures (08): what the board holds and how it is spaced.
abstract final class SquareMetrics {
  /// The deck's portraits: the widest, with six roles or fewer and with
  /// more, and the narrowest before the board scrolls.
  static const widestFew = 84.0;
  static const widestMany = 64.0;
  static const narrowest = 40.0;
  static const step = 2.0;

  /// Columns of the deck: three, four past six roles.
  static const fewRoles = 6;

  /// Between piles in a row (at most), between the deck's rows, between tags.
  static const pileGap = Space.xl;
  static const rowGap = Space.lg;
  static const tagGap = Space.sm;

  /// The spare height: this share above the deck, this between it and the
  /// tags (the rest below).
  static const spareAbove = 0.3;
  static const spareBetween = 0.4;

  /// The one button's widest, on the cobbles.
  static const buttonWidest = 264.0;

  /// The least body (board and foot) before the band and body scroll
  /// together.
  static const leastBody = 380.0;
}

/// One pile of the deck in play: the role, how many, and its words.
typedef Pile = ({RoleId role, int count, String label});

/// The deck in play, one pile per role, in the deck's order.
List<Pile> pilesOf(Map<RoleId, int> deck) => [
  for (final MapEntry(key: role, value: count) in deck.entries)
    (
      role: role,
      count: count,
      label: count > 1
          ? TalkCopy.deckCount.fill({'n': count, 'roles': role.pluralName})
          : role.displayName,
    ),
];

/// The square at rest, on the board's felt: the deck in play (public: the
/// game's set-up), then every player as a name tag in seat order, centred,
/// as many to a row as fit. The deck's portraits are as large as lets both
/// fit whole in the room; at the narrowest, on a short phone with large
/// text, the board scrolls (fading at its foot).
class SquareBoard extends StatelessWidget {
  const SquareBoard({
    super.key,
    required this.deck,
    required this.seats,
    required this.you,
  });

  final Map<RoleId, int> deck;
  final List<NightSeat> seats;

  /// This phone's player.
  final int you;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    builder: (context, box) {
      final plan = _Plan.of(context, pilesOf(deck), seats, box.biggest);
      final content = _content(context, plan, box.maxWidth);
      return plan.fits ? content : FadingScroll(child: content);
    },
  );

  Widget _content(BuildContext context, _Plan plan, double width) {
    final spare = plan.spare;
    return SizedBox(
      width: width,
      child: Column(
        children: [
          SizedBox(
            height: SquareMetrics.tagGap + spare * SquareMetrics.spareAbove,
          ),
          for (final (i, row) in plan.rows.indexed) ...[
            if (i > 0) const SizedBox(height: SquareMetrics.rowGap),
            // A row that is too wide (only where the board scrolls) wraps.
            Wrap(
              alignment: WrapAlignment.center,
              spacing: math.max(Space.xs, plan.gaps[i]),
              runSpacing: SquareMetrics.rowGap,
              children: [
                for (final pile in row)
                  DeckPile(
                    role: pile.role,
                    count: pile.count,
                    label: pile.label,
                    portraitWidth: plan.portrait,
                    stripHeight: plan.strip,
                    onOpen: () => unawaited(openRole(context, pile.role)),
                  ),
              ],
            ),
          ],
          SizedBox(
            height: SquareMetrics.rowGap + spare * SquareMetrics.spareBetween,
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: Space.sm),
            child: Wrap(
              alignment: WrapAlignment.center,
              spacing: SquareMetrics.tagGap,
              runSpacing: SquareMetrics.tagGap,
              children: [
                for (final seat in seats)
                  NameTag(
                    name: seat.name,
                    token: seat.token,
                    you: seat.id == you,
                  ),
              ],
            ),
          ),
          const SizedBox(height: SquareMetrics.tagGap),
        ],
      ),
    );
  }

  /// A role's sheet (03b), from a tap or a hold on its pile.
  static Future<void> openRole(BuildContext context, RoleId role) =>
      showSkinSheet<void>(
        context,
        builder: (sheet) => SheetScaffold(
          actions: [
            const Spacer(),
            PrimaryButton(
              label: RoleSheetCopy.close,
              onPressed: () => Navigator.of(sheet).pop(),
              size: ButtonSize.compact,
            ),
          ],
          child: RoleSheetBody(role),
        ),
      );
}

/// How the square is set out in its room: the deck's rows, its portraits'
/// width, the gaps, and the height to spare.
class _Plan {
  const _Plan({
    required this.rows,
    required this.gaps,
    required this.portrait,
    required this.strip,
    required this.used,
    required this.spare,
    required this.fits,
  });

  /// The height it takes with no spare.
  final double used;

  final List<List<Pile>> rows;
  final List<double> gaps;
  final double portrait;
  final double strip;
  final double spare;
  final bool fits;

  static _Plan of(
    BuildContext context,
    List<Pile> piles,
    List<NightSeat> seats,
    Size room,
  ) {
    final type = context.skin.typography;
    final scaler = MediaQuery.textScalerOf(context);
    final width = room.width - 2 * Space.sm;
    // The tags, wrapped as the Wrap will.
    final tagHeight = NameTag.heightOf(type.name, scaler);
    var tagRows = 1;
    var line = 0.0;
    for (final seat in seats) {
      final w = math.min(width, NameTag.widthOf(seat.name, type.name, scaler));
      if (line > 0 && line + SquareMetrics.tagGap + w > width) {
        tagRows++;
        line = w;
      } else {
        line += (line > 0 ? SquareMetrics.tagGap : 0) + w;
      }
    }
    final tags = tagRows * tagHeight + (tagRows - 1) * SquareMetrics.tagGap;
    // The deck's rows, as even as they go (the first longer).
    final columns = piles.length > SquareMetrics.fewRoles ? 4 : 3;
    final count = math.max(1, (piles.length / columns).ceil());
    final rows = <List<Pile>>[];
    var at = 0;
    for (var r = 0; r < count; r++) {
      final n = piles.length ~/ count + (r < piles.length % count ? 1 : 0);
      rows.add(piles.sublist(at, at + n));
      at += n;
    }
    final stripLine = (TextPainter(
      text: TextSpan(text: 'Ag', style: type.tag),
      textDirection: TextDirection.ltr,
      textScaler: scaler,
      maxLines: 1,
    )..layout());
    final strip = math.max(
      BoardCard.defaultStripHeight,
      stripLine.height + Space.hairline,
    );
    stripLine.dispose();
    final labels = {
      for (final pile in piles)
        pile.label: DeckPile.labelWidth(context, pile.label),
    };
    final widest = piles.length > SquareMetrics.fewRoles
        ? SquareMetrics.widestMany
        : SquareMetrics.widestFew;
    _Plan at_(double portrait, {required bool fits}) {
      final gaps = <double>[];
      var cardHeight = 0.0;
      for (final row in rows) {
        var content = 0.0;
        for (final pile in row) {
          final card = DeckPile.cardSize(portrait, labels[pile.label]!, strip);
          final size = DeckPile.sizeOf(card, pile.count);
          cardHeight = math.max(cardHeight, size.height);
          content += size.width;
        }
        gaps.add(
          row.length < 2
              ? 0
              : math.min(
                  SquareMetrics.pileGap,
                  (width - content) / (row.length - 1),
                ),
        );
      }
      final deck =
          rows.length * cardHeight + (rows.length - 1) * SquareMetrics.rowGap;
      final used =
          2 * SquareMetrics.tagGap + deck + SquareMetrics.rowGap + tags;
      return _Plan(
        rows: rows,
        gaps: gaps,
        portrait: portrait,
        strip: strip,
        used: used,
        spare: math.max(0.0, room.height - used),
        fits: fits,
      );
    }

    for (
      var p = widest;
      p >= SquareMetrics.narrowest;
      p -= SquareMetrics.step
    ) {
      final plan = at_(p, fits: true);
      if (plan.used <= room.height && plan.gaps.every((g) => g >= Space.xs)) {
        return plan;
      }
    }
    return at_(SquareMetrics.narrowest, fits: false);
  }
}

/// "My night", held (piece 1 of 2): the board's area from its top, under
/// the clock, shows this player's night while the note is held (today the
/// face, every page stacked, as the sheet had it; piece 2 draws each night
/// as a picture story here). Built only while shown: nothing of it is in the
/// tree otherwise.
class MyNightPanel extends StatelessWidget {
  const MyNightPanel({super.key, required this.face});

  final FaceContent face;

  @override
  Widget build(BuildContext context) => LayoutBuilder(
    // The face takes the board's area from its top; its portrait takes what
    // the words leave, so the words keep their size (the reading floor).
    builder: (context, box) => Align(
      alignment: Alignment.topCenter,
      child: Padding(
        padding: const EdgeInsets.only(top: Space.sm),
        child: SizedBox(
          width: HeldFace.widthFor(
            math.min(box.maxWidth + 2 * Space.gutter, ScreenFrame.maxWidth),
          ),
          height: math.max(0.0, box.maxHeight - Space.sm),
          child: HeldFace(content: face, page: 0, announce: true, fill: true),
        ),
      ),
    ),
  );
}
