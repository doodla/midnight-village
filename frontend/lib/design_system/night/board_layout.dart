import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../layout/space.dart';
import '../primitives/face_down_card.dart';

/// Where the night board's cards go on a phone: how the seats are split into
/// rows, how wide a card is, the one size every name under a card is set at,
/// and how large the table's own three cards are. Worked out from the room
/// the board has, the names at the table and the text scale, never from a
/// role, so every phone at a table lays out the same board (the names it
/// measures are everyone's, "You" included, whichever seat is this phone's).
///
/// The rules, in order:
/// - Every card is on the screen, the table's three too; nothing scrolls.
/// - A name is never cut: every name is set at one size, the largest at
///   which each fits its column on one line, or on two lines broken between
///   words; never below [nameFloor] while some split of the rows allows it.
/// - Rows are balanced and never leave one card alone on a row (5 is 3 + 2,
///   7 is 4 + 3, 9 is 3 + 3 + 3 or 5 + 4, 10 is 4 + 3 + 3 or 5 + 5).
/// - Where no split keeps both every card at [smallest] or larger and every
///   name at its floor (ten long names on a 320 phone), the split that falls
///   least short of the two, each as a share of its minimum, the name's
///   counted twice: a name too small to read is worse than a small card.
/// - Of the splits that keep every name at its floor, the one with the
///   largest cards; of two within [sameSize] of each other, the one with
///   fewer rows.
/// - A column is as wide as its card and a gap, or its widest name, and no
///   wider: the seats sit together as at a table, the rows centred.
@immutable
class BoardLayout {
  const BoardLayout._({
    required this.rows,
    required this.column,
    required this.cardWidth,
    required this.centerWidth,
    required this.centerColumn,
    required this.nameSize,
    required this.nameHeight,
    required this.used,
  });

  /// Cards per row of players, top to bottom.
  final List<int> rows;

  /// A player's column: the width a name has under its card.
  final double column;

  /// A player's card.
  final double cardWidth;

  /// One of the table's three cards, set apart smaller (S06: 62 to 78).
  final double centerWidth;

  /// A center card's column, for its caption.
  final double centerColumn;

  /// The font size (before the text scale) every name is set at.
  final double nameSize;

  /// The room under every token for its name: [nameSize]'s lines (two
  /// when any name wraps), the place card round "You" included.
  final double nameHeight;

  /// The height the board takes: the rest of the room is to spare.
  final double used;

  /// The table's cards to a player's.
  static const centerScale = 0.8;

  /// Gap between two columns of players.
  static const columnGap = Space.sm;

  /// Room a column keeps beside its card: with [columnGap], the gap between
  /// two cards of short names.
  static const seatGap = Space.lg;

  /// Gap between two rows of players: room for a picked card's lift.
  static const rowGap = Space.lg;

  /// Between the last row of players and the table's strip.
  static const tableGap = Space.lg;

  /// Inside the table's strip, round its cards.
  static const tablePadding = Space.md;

  /// Between two of the table's cards.
  static const tableCardGap = Space.xl;

  /// The most cards in a row of players.
  static const mostPerRow = 5;

  /// The smallest card the board would rather not draw: 60% of the mocks'
  /// player card, still a thumb's width.
  static final smallest = FaceDownSize.player.mock.width * 0.6;

  /// Two splits whose cards are within this share of each other's width are
  /// as good: the one with fewer rows is calmer.
  static const sameSize = 0.08;

  /// Names are set no smaller than the reading floor for captions.
  /// As drawn, after the text scale: with large text a name grows where
  /// there is room and is set back to this where there is not.
  static const nameFloor = 14.0;

  /// Text measured is laid out a hair narrower than it fits.
  static const _safety = 0.98;

  /// A card's height for its width.
  static double heightOf(double width) =>
      width * FaceDownSize.board.mock.height / FaceDownSize.board.mock.width;

  /// Splits [seats] into [rowCount] rows, the longer ones first, as even as
  /// they go.
  static List<int> balanced(int seats, int rowCount) => [
    for (var i = 0; i < rowCount; i++)
      seats ~/ rowCount + (i < seats % rowCount ? 1 : 0),
  ];

  /// The splits of [seats] the board may use: balanced, at most
  /// [mostPerRow] to a row, never one card alone on a row of its own unless
  /// it is the only row.
  static List<List<int>> splits(int seats) {
    final all = <List<int>>[];
    for (var rowCount = 1; rowCount <= seats; rowCount++) {
      final rows = balanced(seats, rowCount);
      if (rows.first > mostPerRow) continue;
      if (rowCount > 1 && rows.last < 2) break;
      all.add(rows);
    }
    return all;
  }

  /// The board for [seats] seats with [names] under them (every seat's
  /// name, plus "You") in [room], the names in [nameStyle] (on a place card
  /// [placePadding] high round "You") and the table's [captions] in
  /// [captionStyle], all under [scaler]; the table's cards tilt by at most
  /// [tilt] radians.
  factory BoardLayout.solve({
    required int seats,
    required Iterable<String> names,
    required Iterable<String> captions,
    required Size room,
    required TextStyle nameStyle,
    required TextStyle captionStyle,
    required TextScaler scaler,
    String? place,
    EdgeInsets placePadding = EdgeInsets.zero,
    double tilt = 0,
  }) {
    final base = nameStyle.fontSize!;
    final needs = [
      for (final name in names.toSet())
        _Need.of(
          name,
          nameStyle,
          scaler,
          name == place ? placePadding.horizontal : 0,
        ),
    ];
    final captionHeight = _lineHeight(captionStyle, scaler);
    final captionWidth = captions
        .map((c) => _widthOf(c, captionStyle, scaler))
        .reduce(math.max);
    final centerColumn = math.max(
      (room.width - 2 * tablePadding - 2 * tableCardGap) / 3,
      captionWidth,
    );
    // A tilted card's height: its turned box.
    final turn = math.cos(tilt) + math.sin(tilt.abs()) / heightOf(1);

    _Candidate? best;
    for (final rows in splits(seats)) {
      final widest = rows.first;
      final column = (room.width - (widest - 1) * columnGap) / widest;

      // The one name size: the largest at which every name fits its column.
      final fits = needs
          .map((n) => base * column * _safety / n.narrowest)
          .reduce(math.min);
      final size = math.min(base, fits);
      final lines = needs.any((n) => n.oneLine * size / base > column) ? 2 : 1;
      final nameHeight =
          lines * _lineHeight(nameStyle.copyWith(fontSize: size), scaler) +
          placePadding.vertical;

      double heightFor(double card) {
        final players =
            rows.length *
                (heightOf(card) +
                    FaceDownCard.ownerTokenFor(card) / 2 +
                    FaceDownCard.nameGap +
                    nameHeight) +
            (rows.length - 1) * rowGap;
        final table =
            2 * tablePadding +
            heightOf(card * centerScale) * turn +
            FaceDownCard.captionGap +
            captionHeight;
        return players + tableGap + table;
      }

      // The widest card that fits its column, the board's size and the
      // height.
      var card = [
        column,
        FaceDownSize.board.mock.width,
        centerColumn / centerScale,
      ].reduce(math.min);
      if (heightFor(card) > room.height) {
        var low = 0.0;
        var high = card;
        for (var i = 0; i < 30; i++) {
          final mid = (low + high) / 2;
          (heightFor(mid) <= room.height) ? low = mid : high = mid;
        }
        card = low;
      }
      final candidate = _Candidate(
        BoardLayout._(
          rows: rows,
          column: math.min(
            column,
            math.max(
              card + seatGap,
              needs.map((n) => n.narrowest * size / base).reduce(math.max) /
                  _safety,
            ),
          ),
          cardWidth: card,
          centerWidth: card * centerScale,
          centerColumn: centerColumn,
          nameSize: size,
          nameHeight: nameHeight,
          used: heightFor(card),
        ),
        short:
            math.min(1.0, card / smallest) *
            math
                .pow(math.min(1.0, scaler.scale(size) / nameFloor), 2)
                .toDouble(),
      );
      if (best == null || candidate.beats(best)) best = candidate;
    }
    return best!.layout;
  }

  static double _lineHeight(TextStyle style, TextScaler scaler) {
    final painter = TextPainter(
      text: TextSpan(style: style),
      textScaler: scaler,
      textDirection: TextDirection.ltr,
    );
    final height = painter.preferredLineHeight;
    painter.dispose();
    return height;
  }

  static double _widthOf(String text, TextStyle style, TextScaler scaler) {
    final painter = TextPainter(
      text: TextSpan(text: text, style: style),
      textScaler: scaler,
      textDirection: TextDirection.ltr,
      maxLines: 1,
    )..layout();
    final width = painter.width;
    painter.dispose();
    return width;
  }
}

/// How wide a name is at the base size.
class _Need {
  const _Need(this.oneLine, this.narrowest);

  factory _Need.of(
    String name,
    TextStyle style,
    TextScaler scaler,
    double padding,
  ) {
    final oneLine = BoardLayout._widthOf(name, style, scaler) + padding;
    var narrowest = oneLine;
    final words = name.split(' ');
    for (var at = 1; at < words.length; at++) {
      final top = BoardLayout._widthOf(words.take(at).join(' '), style, scaler);
      final rest = BoardLayout._widthOf(
        words.skip(at).join(' '),
        style,
        scaler,
      );
      narrowest = math.min(narrowest, math.max(top, rest) + padding);
    }
    return _Need(oneLine, narrowest);
  }

  /// On one line.
  final double oneLine;

  /// On its narrowest one or two lines (broken between words).
  final double narrowest;
}

class _Candidate {
  const _Candidate(this.layout, {required this.short});

  final BoardLayout layout;

  /// How near the cards are to [BoardLayout.smallest] and the names to
  /// their floor, multiplied: 1 when both are there.
  final double short;

  /// Whether this split is better than [other] (BoardLayout's rules).
  bool beats(_Candidate other) {
    final (mine, theirs) = (layout, other.layout);
    final fewer = mine.rows.length < theirs.rows.length;
    if ((short - other.short).abs() > 0.01) return short > other.short;
    final gain = mine.cardWidth / theirs.cardWidth - 1;
    return gain.abs() <= BoardLayout.sameSize ? fewer : gain > 0;
  }
}
