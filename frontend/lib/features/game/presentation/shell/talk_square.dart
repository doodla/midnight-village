import 'dart:async';
import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../../../../design_system/copy/copy.dart';
import '../../../../design_system/layout/space.dart';
import '../../../../design_system/models/role.dart';
import '../../../../design_system/night/night_pick.dart';
import '../../../../design_system/night/night_story.dart';
import '../../../../design_system/night/night_story_view.dart';
import '../../../../design_system/primitives/board_pieces.dart';
import '../../../../design_system/primitives/deck_pile.dart';
import '../../../../design_system/primitives/name_tag.dart';
import '../../../../design_system/primitives/primary_button.dart';
import '../../../../design_system/primitives/role_sheet_body.dart';
import '../../../../design_system/primitives/screen_frame.dart';
import '../../../../design_system/primitives/sheet_scaffold.dart';
import '../../../../design_system/skin/skin.dart';

/// How the square is spaced (08). Its sizes are the skin's
/// (`PaperParts.square*`); what is here is the grid's count and the gaps,
/// which are the app's spacing.
abstract final class SquareMetrics {
  /// Columns of the deck: three, four past six roles; down to
  /// [fewestColumns] (more rows) where a row's words are too wide, and never
  /// a pile alone on a row of its own.
  static const fewRoles = 6;
  static const fewestColumns = 2;

  /// Between piles in a row (at most), between the deck's rows, between tags.
  static const pileGap = Space.xl;
  static const rowGap = Space.lg;
  static const tagGap = Space.sm;
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
/// fit whole in the room; below the least that still reads as a face the
/// cards become name-only (the role's words on its team's paper), and only if
/// those do not fit either does the board scroll (fading at its foot).
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
    final parts = context.skin.parts;
    final spare = plan.spare;
    return SizedBox(
      width: width,
      child: Column(
        children: [
          SizedBox(
            height: SquareMetrics.tagGap + spare * parts.squareSpareAbove,
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
                    nameOnly: plan.nameOnly,
                    stripHeight: plan.strip,
                    onOpen: () => unawaited(openRole(context, pile.role)),
                  ),
              ],
            ),
          ],
          SizedBox(
            height: SquareMetrics.rowGap + spare * parts.squareSpareBetween,
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
    required this.nameOnly,
    required this.used,
    required this.spare,
    required this.fits,
  });

  /// The height it takes with no spare.
  final double used;

  final List<List<Pile>> rows;
  final List<double> gaps;
  final double portrait;

  /// The cards are their words alone (the portraits would be too small).
  final bool nameOnly;
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
    final parts = context.skin.parts;
    // [list] in [count] rows, as even as they go (the first longer).
    List<List<Pile>> rowsOf(List<Pile> list, int count) {
      final grid = <List<Pile>>[];
      var at = 0;
      for (var r = 0; r < count; r++) {
        final n = list.length ~/ count + (r < list.length % count ? 1 : 0);
        grid.add(list.sublist(at, at + n));
        at += n;
      }
      return grid;
    }

    // A grid is balanced when no pile is left alone on its row.
    bool balanced(List<List<Pile>> grid) =>
        piles.length < 2 || grid.every((row) => row.length > 1);

    final columns = piles.length > SquareMetrics.fewRoles ? 4 : 3;
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
        ? parts.squarePortraitMany
        : parts.squarePortraitFew;
    // Name-only cards are as wide as their words: as many to a row as fit,
    // then as even as those rows let them be where that is no taller (each
    // row is as tall as its tallest pile).
    Size words(Pile pile) => DeckPile.sizeOf(
      DeckPile.cardSize(0, labels[pile.label]!, strip),
      pile.count,
      nameOnly: true,
    );
    double wordsWide(Pile pile) => words(pile).width;
    bool rowFits(List<Pile> row) =>
        row.fold(0.0, (w, pile) => w + wordsWide(pile)) +
            (row.length - 1) * Space.xs <=
        width;
    double tall(List<List<Pile>> rows) => rows.fold(
      0.0,
      (h, row) => h + row.map((p) => words(p).height).reduce(math.max),
    );
    var packed = <List<Pile>>[];
    var rowWidth = 0.0;
    for (final pile in piles) {
      final w = wordsWide(pile);
      if (packed.isNotEmpty && rowWidth + Space.xs + w <= width) {
        packed.last.add(pile);
        rowWidth += Space.xs + w;
      } else {
        packed.add([pile]);
        rowWidth = w;
      }
    }
    final even = rowsOf(piles, packed.length);
    if (even.every(rowFits) && tall(even) <= tall(packed)) packed = even;
    _Plan at_(
      double portrait, {
      required bool fits,
      List<List<Pile>> grid = const [],
    }) {
      final rows = portrait > 0 ? grid : packed;
      final gaps = <double>[];
      var cardHeight = 0.0;
      for (final row in rows) {
        var content = 0.0;
        for (final pile in row) {
          final card = DeckPile.cardSize(portrait, labels[pile.label]!, strip);
          final size = DeckPile.sizeOf(
            card,
            pile.count,
            nameOnly: portrait <= 0,
          );
          cardHeight = math.max(cardHeight, size.height);
          content += size.width;
        }
        gaps.add(
          row.length < 2
              ? SquareMetrics.pileGap
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
        nameOnly: portrait <= 0,
        used: used,
        spare: math.max(0.0, room.height - used),
        fits: fits,
      );
    }

    // The fullest balanced rows first, at the largest portrait down to a
    // comfortable one (`squarePortraitMany`): three calm faces to a row
    // before two big ones. Then the largest portrait that fits at any of
    // them, before the portraits go (eight roles' words, four to a row, are
    // wider than a 412 phone).
    final grids = [
      for (var c = columns; c >= SquareMetrics.fewestColumns; c--)
        rowsOf(piles, math.max(1, (piles.length / c).ceil())),
    ].where(balanced).toList();
    _Plan? fitting(double p, List<List<Pile>> grid) {
      final plan = at_(p, fits: true, grid: grid);
      return plan.used <= room.height && plan.gaps.every((g) => g >= Space.xs)
          ? plan
          : null;
    }

    final comfortable = math.min(widest, parts.squarePortraitMany);
    for (final grid in grids) {
      for (var p = widest; p >= comfortable; p -= parts.squarePortraitStep) {
        final plan = fitting(p, grid);
        if (plan != null) return plan;
      }
    }
    for (
      var p = widest;
      p >= parts.squarePortraitLeast;
      p -= parts.squarePortraitStep
    ) {
      for (final grid in grids) {
        final plan = fitting(p, grid);
        if (plan != null) return plan;
      }
    }
    // The portraits would be below what reads as a face at any number to a
    // row: name-only cards, before the board ever scrolls.
    final names = at_(0, fits: true);
    if (names.used <= room.height) return names;
    return at_(0, fits: false);
  }
}

/// "My night", held: the board's area from its top, under the clock, shows
/// this player's night as a picture story ([NightStoryView], from
/// [NightStory.of] their own night record) while the note is held. Built
/// only while shown: nothing of it is in the tree otherwise.
class MyNightPanel extends StatelessWidget {
  const MyNightPanel({super.key, required this.story});

  final NightStory story;

  @override
  Widget build(BuildContext context) => NightStoryView(story: story);
}
