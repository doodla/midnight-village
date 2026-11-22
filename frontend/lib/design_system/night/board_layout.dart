import 'dart:math' as math;

import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart' show kMinInteractiveDimension;
import 'package:flutter/painting.dart';

import '../layout/space.dart';
import '../primitives/face_down_card.dart';

/// Where the night board's cards go on a phone. Two parts: the other
/// players' seats, in rows, and under them the band in front of the player:
/// their own card on its paper place, beside the table's three cards on
/// their strip. Worked out from the room the board has, every name at the
/// table and the text scale, never from a role or from which seat is this
/// phone's, so every phone at a table lays out the same board.
///
/// The rules, in order:
/// - Every card is on the screen; nothing scrolls. The seats' cards use the
///   height the phone gives them, up to [largest]: no dead band on a small
///   table.
/// - A name is never cut: every name is set at one size, the largest at
///   which each fits its column on one line, or on two lines broken between
///   words.
/// - The seats' rows are balanced and never leave one card alone on a row
///   (4 is 4 or 2 + 2, 7 is 4 + 3, 8 is 4 + 4, 9 is 5 + 4 or 3 + 3 + 3).
/// - Where no split keeps both every card at [smallest] or larger and every
///   name at [nameFloor] (ten long names on a 320 phone), the split that
///   falls least short of the two, each as a share of its minimum, the
///   name's counted twice: a name too small to read is worse than a small
///   card.
/// - Of the rest, the one with the largest cards; of two within [sameSize]
///   of each other, the one with fewer rows.
/// - A column is as wide as its card and a gap, or its widest name, and no
///   wider: the seats sit together as at a table, the rows centred.
/// - The band's four cards are one size: a seat's, or less where the
///   phone's width needs it.
/// - A tap reaches a seat's whole column and a band card's cell, at least
///   [minTap] wide where the width allows; a split that cannot give that
///   falls short like a small card.
@immutable
class BoardLayout {
  const BoardLayout._({
    required this.rows,
    required this.column,
    required this.cardWidth,
    required this.bandCard,
    required this.bandCell,
    required this.bandHeight,
    required this.labelRoom,
    required this.seatLabelRoom,
    required this.ruleRoom,
    required this.nameSize,
    required this.nameHeight,
    required this.youNameHeight,
    required this.used,
  });

  /// Cards per row of the other players, top to bottom.
  final List<int> rows;

  /// A player's column: the width a name has under its card.
  final double column;

  /// A player's card.
  final double cardWidth;

  /// The player's own card and the table's three, in the band.
  final double bandCard;

  /// A card's cell in the band, what a tap on it reaches: the card, or
  /// [minTap] where the card is narrower.
  final double bandCell;

  /// The band's height: the place and the strip are drawn this high.
  final double bandHeight;

  /// The room the strip's "Center" label takes above its cards (and the
  /// place leaves empty above its own, so the four cards sit level).
  final double labelRoom;

  /// The room above the first row of seats for a label (the Seer's "1
  /// player"): kept on every board, empty on most, so every role's cards
  /// sit in the same places.
  final double seatLabelRoom;

  /// The gap between the last row and the band, high enough for the rule
  /// with "or" on it (the Seer's), kept on every board.
  final double ruleRoom;

  /// The font size (before the text scale) every name is set at.
  final double nameSize;

  /// The room under every token for its name: [nameSize]'s lines (two when
  /// any name wraps).
  final double nameHeight;

  /// The room under the player's own card for "You": one line, whatever
  /// the table's names need (it never wraps), so a table of long names does
  /// not make the band taller than its cards need.
  final double youNameHeight;

  /// The height the board takes: the rest of the room is to spare.
  final double used;

  /// Gap between two columns of players.
  static const columnGap = Space.sm;

  /// Room a column keeps beside its card: with [columnGap], the gap between
  /// two cards of short names.
  static const seatGap = Space.lg;

  /// Gap between two rows of players: room for a picked card's lift.
  static const rowGap = Space.md;

  /// Between the last row of players and the band.
  static const bandGap = Space.xl;

  /// The rule between the seats and the band sits in this much of its own
  /// line and a hair.
  static const ruleSlack = 2.0;

  /// Inside the place and the strip, above and below their cards, and
  /// beside them.
  static const bandPadding = Space.sm;
  static const bandPaddingSide = Space.sm;

  /// Between the place and the strip.
  static const placeGap = Space.md;

  /// Between two of the table's cards.
  static const tableCardGap = Space.sm;

  /// The most cards in a row of players.
  static const mostPerRow = 5;

  /// The widest a seat's card gets, where a table is small and the phone is
  /// tall: the cards grow to the height the phone gives them (the mocks'
  /// 96 is where a full table of ten ends up), up to this and no further.
  /// What a phone still has to spare goes between the parts evenly.
  static const largest = 160.0;

  /// A card grown past the mocks' board card (96) leaves this much air in
  /// each gap (above the seats, between the rows, above the band), so the
  /// parts of a board never touch.
  static const breath = Space.lg;

  /// The smallest card the board would rather not draw: 60% of the mocks'
  /// player card, still a thumb's width.
  static final smallest = FaceDownSize.player.mock.width * 0.6;

  /// Two splits whose cards are within this share of each other's width are
  /// as good: the one with fewer rows is calmer.
  static const sameSize = 0.08;

  /// A split that leaves more than this much of the room's height unused in
  /// each gap (above the seats, between the rows, above the band) has a dead
  /// band; of two splits, the one without is better.
  static const deadBand = 32.0;

  /// Names are set no smaller than the reading floor for captions, as drawn
  /// (after the text scale): with large text a name grows where there is
  /// room and is set back to this where there is not.
  static const nameFloor = ReadingFloor.caption;

  /// The smallest width a tap on a card reaches: its column, or its cell in
  /// the band (the platforms' 44 px target).
  static const minTap = kMinInteractiveDimension;

  /// Text measured is laid out a hair narrower than it fits.
  static const _safety = 0.98;

  /// A card's height for its width.
  static double heightOf(double width) =>
      width * FaceDownSize.board.mock.height / FaceDownSize.board.mock.width;

  /// The band's width for its cells [card] wide.
  static double bandWidth(double card) =>
      4 * bandPaddingSide + placeGap + 4 * card + 2 * tableCardGap;

  /// Splits [seats] into [rowCount] rows, the longer ones first, as even as
  /// they go.
  static List<int> balanced(int seats, int rowCount) => [
    for (var i = 0; i < rowCount; i++)
      seats ~/ rowCount + (i < seats % rowCount ? 1 : 0),
  ];

  /// The splits of [seats] the board may use: balanced, at most
  /// [mostPerRow] to a row, never one card alone on a row of its own unless
  /// it is the only row, with one exception: three seats may stand as a pair
  /// with the third centred under it (a triangle, not an orphan), because a
  /// row of three is as wide as the phone and leaves a tall phone's height
  /// unused. It is only taken where its cards come out larger.
  static List<List<int>> splits(int seats) {
    final all = <List<int>>[];
    for (var rowCount = 1; rowCount <= seats; rowCount++) {
      final rows = balanced(seats, rowCount);
      if (rows.first > mostPerRow) continue;
      final pair = seats == triangle && rowCount == 2;
      if (rowCount > 1 && rows.last < 2 && !pair) break;
      all.add(rows);
    }
    return all;
  }

  /// The one table whose seats may stand as a pair and a centred third.
  static const triangle = 3;

  /// The board for [others] other players in [room]. [names] are every
  /// seat's name, this phone's own included (so every phone measures the
  /// same names), in [nameStyle]; [you] is the name under the player's own
  /// card; the table's [captions] are in [captionStyle]; all under
  /// [scaler]. The table's cards tilt by at most [tilt] radians.
  factory BoardLayout.solve({
    required int others,
    required Iterable<String> names,
    required String you,
    required Iterable<String> captions,
    required Size room,
    required TextStyle nameStyle,
    required TextStyle captionStyle,
    required TextScaler scaler,
    double tilt = 0,
  }) {
    final base = nameStyle.fontSize!;
    // The seats' names (a player may be called "You" too), and "You".
    final needs = [
      for (final name in names.toSet()) _Need.of(name, nameStyle, scaler),
    ];
    final youNeed = _Need.of(you, nameStyle, scaler);
    final captionHeight = _lineHeight(captionStyle, scaler);
    // The strip's "Center" label is a caption line and its gap.
    // Clear of a picked card's lift (Space.sm) and the table's tilt.
    final labelRoom = captionHeight + Space.sm + Space.xxs;
    // The Seer's "1 player" above the seats, and her rule between them and
    // the band: room on every board, so none moves a card.
    final seatLabelRoom = captionHeight + Space.md;
    final ruleRoom = math.min(bandGap, captionHeight + ruleSlack);
    // A tilted card's height: its turned box.
    final turn = math.cos(tilt) + math.sin(tilt.abs()) / heightOf(1);
    // The band's four cells share what its paddings leave of the width.
    final bandMost = (room.width - bandWidth(0)) / 4;

    _Candidate? best;
    for (final rows in splits(others)) {
      final widest = rows.first;
      final column = (room.width - (widest - 1) * columnGap) / widest;

      // The one name size: the largest at which every name fits its column
      // (and "You" its card in the band).
      double fitIn(_Need n, double width) =>
          base * width * _safety / n.narrowest;
      final size = [
        base,
        for (final n in needs) fitIn(n, column),
        fitIn(youNeed, column),
      ].reduce(math.min);
      final lines = needs.any((n) => n.oneLine * size / base > column) ? 2 : 1;
      final oneLine = _lineHeight(nameStyle.copyWith(fontSize: size), scaler);
      final nameHeight = lines * oneLine;

      double band(double card) => math.min(card, bandMost);
      double bandHeightFor(double card) {
        final b = band(card);
        final place =
            heightOf(b) +
            FaceDownCard.ownerTokenFor(b) / 2 +
            FaceDownCard.nameGap +
            oneLine;
        final strip =
            heightOf(b) * turn + FaceDownCard.captionGap + captionHeight;
        return 2 * bandPadding + labelRoom + math.max(place, strip);
      }

      double heightFor(double card) =>
          rows.length *
              (heightOf(card) +
                  FaceDownCard.ownerTokenFor(card) / 2 +
                  FaceDownCard.nameGap +
                  nameHeight) +
          (rows.length - 1) * rowGap +
          seatLabelRoom +
          ruleRoom +
          bandHeightFor(card);

      // The widest card that fits its column, [largest] and the height with
      // [extra] to spare.
      double cardFor(double extra) {
        var card = math.min(column, largest);
        if (heightFor(card) + extra > room.height) {
          var low = 0.0;
          var high = card;
          for (var i = 0; i < 30; i++) {
            final mid = (low + high) / 2;
            (heightFor(mid) + extra <= room.height) ? low = mid : high = mid;
          }
          card = low;
        }
        return card;
      }

      // Up to the mocks' board card as tight as the room needs; beyond it
      // only where each gap keeps its breath.
      final card = math.max(
        cardFor(breath * (rows.length + 1)),
        math.min(cardFor(0), FaceDownSize.board.mock.width),
      );
      // A column is no narrower than its names as they are laid out: on one
      // line when every name fits one, else on their narrowest two.
      final widestName = needs
          .map((n) => (lines == 1 ? n.oneLine : n.narrowest) * size / base)
          .fold(0.0, math.max);
      final seatColumn = math.min(
        column,
        [card + seatGap, widestName / _safety, minTap].reduce(math.max),
      );
      final candidate = _Candidate(
        BoardLayout._(
          rows: rows,
          column: seatColumn,
          cardWidth: card,
          bandCard: band(card),
          bandCell: math.min(bandMost, math.max(band(card), minTap)),
          bandHeight: bandHeightFor(card),
          labelRoom: labelRoom,
          seatLabelRoom: seatLabelRoom,
          ruleRoom: ruleRoom,
          nameSize: size,
          nameHeight: nameHeight,
          youNameHeight: oneLine,
          used: heightFor(card),
        ),
        short:
            math.min(1.0, card / smallest) *
            math.min(
              1.0,
              math.min(seatColumn, math.max(band(card), minTap)) / minTap,
            ) *
            math.pow(math.min(1.0, scaler.scale(size) / nameFloor), 2),
        spare: math.max(0.0, room.height - heightFor(card)),
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

  factory _Need.of(String name, TextStyle style, TextScaler scaler) {
    final oneLine = BoardLayout._widthOf(name, style, scaler);
    var narrowest = oneLine;
    final words = name.split(' ');
    for (var at = 1; at < words.length; at++) {
      final top = BoardLayout._widthOf(words.take(at).join(' '), style, scaler);
      final rest = BoardLayout._widthOf(
        words.skip(at).join(' '),
        style,
        scaler,
      );
      narrowest = math.min(narrowest, math.max(top, rest));
    }
    return _Need(oneLine, narrowest);
  }

  /// On one line.
  final double oneLine;

  /// On its narrowest one or two lines (broken between words).
  final double narrowest;
}

class _Candidate {
  const _Candidate(this.layout, {required this.short, required this.spare});

  final BoardLayout layout;

  /// The height of the room this split leaves unused.
  final double spare;

  /// How near the cards are to [BoardLayout.smallest] and the names to
  /// their floor, multiplied: 1 when both are there.
  final num short;

  /// Whether this split is better than [other] (BoardLayout's rules).
  bool beats(_Candidate other) {
    final (mine, theirs) = (layout, other.layout);
    final fewer = mine.rows.length < theirs.rows.length;
    if ((short - other.short).abs() > 0.01) return short > other.short;
    // A split that leaves the phone's height unused in every gap (a dead
    // band) is worse than one that does not, whatever its cards' size.
    final dead = spare / (mine.rows.length + 1) > BoardLayout.deadBand;
    final theirDead =
        other.spare / (theirs.rows.length + 1) > BoardLayout.deadBand;
    if (dead != theirDead) return !dead;
    final gain = mine.cardWidth / theirs.cardWidth - 1;
    return gain.abs() <= BoardLayout.sameSize ? fewer : gain > 0;
  }
}
