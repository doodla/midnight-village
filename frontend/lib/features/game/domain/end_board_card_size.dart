part of 'end_board_rows.dart';

/// A card before it is placed: its size and what it needs round it.
class SizedCard {
  const SizedCard({
    required this.id,
    required this.pw,
    required this.width,
    required this.height,
    required this.nameWidth,
    required this.tagNames,
    required this.tagWidth,
    required this.dealt,
    required this.you,
    required this.hanged,
    required this.reachLeft,
    required this.reachRight,
    required this.above,
    required this.header,
    required this.lean,
    required this.tagHeight,
    required this.tagColumns,
    required this.wideStrand,
  });

  final int id;

  /// The portrait's width.
  final double pw;
  final double width;
  final double height;

  /// The name and its room in the header (what a card of it is at least).
  final double nameWidth;
  final List<String> tagNames;

  /// The widest tag of its strand (0 with none).
  final double tagWidth;
  final bool dealt;
  final bool you;
  final bool hanged;

  /// What sticks out of it to the left (the dealt card) and right (the seal,
  /// the ribbon).
  final double reachLeft;
  final double reachRight;

  /// Air it needs above its row: for its dealt card and its ribbon.
  final double above;

  /// The name's header: as tall as the name is at this text size.
  final double header;

  /// How far the card, turned by its own tilt, reaches out of its upright box
  /// across and down (the same up).
  final Size lean;

  /// How tall each of its tags is, and in how many columns they hang.
  final double tagHeight;
  final int tagColumns;

  /// Its strand hangs across the whole row (the other card in it has none),
  /// from under the lower of the two.
  final bool wideStrand;

  bool get hasTags => tagNames.isNotEmpty;

  /// The room it needs across the board: the card, or its strand of tags.
  double get need => math.max(
    width + 2 * lean.width,
    wideStrand
        ? tagWidth
        : tagWidth * tagColumns + EndMetrics.tagGap * (tagColumns - 1),
  );

  /// How far it reaches under its upright bottom: its lean, then its strand.
  double get under =>
      lean.height +
      EndMetrics.strand(tagNames.length, tagHeight, columns: tagColumns);
}

/// A card sized: the width is the largest of the portrait plus 8, the name plus
/// 20, and the wider role plus 18 (and 28 more with tags, to clear the pin),
/// never more than [maxWidth] (the name is then set smaller, never cut).
SizedCard sizeCard({
  required int id,
  required double pw,
  required String name,
  required List<String> stripWords,
  required List<String> tagNames,
  required bool dealt,
  required bool you,
  required bool hanged,
  required double maxWidth,
  required double header,
  required double tagHeight,
  required double angle,
  required double slot,
  required EndMeasure measure,
  bool wideStrand = false,
  int across = EndMetrics.tagsInOneColumn,
  int mostColumns = EndMetrics.mostTagColumns,
}) {
  final role = stripWords
      .map((w) => measure(EndText.role, w))
      .fold(0.0, math.max);
  final nameWidth = measure(EndText.name, name) + EndMetrics.nameRoom;
  final width = math
      .max(
        pw + 2 * EndMetrics.portraitInset,
        math.max(
          nameWidth,
          role +
              EndMetrics.roleRoom +
              (tagNames.isEmpty ? 0 : EndMetrics.tagRoom),
        ),
      )
      .clamp(0.0, maxWidth)
      .toDouble();
  final dw = EndMetrics.dealtWidth(pw);
  final rw = EndMetrics.ribbonWidth(pw);
  final rh = EndMetrics.ribbonHeight(rw);
  final dealtUp = EndMetrics.dealtOutY * dw * EndMetrics.dealtRatio;
  final ribbonUp = rh * (1 - EndMetrics.ribbonInside);
  final height = EndMetrics.cardHeight(pw, header: header);
  final lean = EndMetrics.leanOf(Size(width, height), angle);
  final tagWidth = tagNames
      .map((n) => EndMetrics.tagApron + measure(EndText.tag, n))
      .fold(0.0, math.max);
  // More than three tags (more than [across]) hang in as many columns as fit
  // the room (two in a card's own slot, up to three across a row), so a
  // strand stays short.
  var columns = 1;
  if (tagNames.length > across) {
    for (var k = mostColumns; k > 1; k--) {
      if (k * tagWidth + (k - 1) * EndMetrics.tagGap <=
          slot - 2 * EndMetrics.clear) {
        columns = k;
        break;
      }
    }
  }
  return SizedCard(
    id: id,
    pw: pw,
    width: width,
    height: height,
    nameWidth: nameWidth,
    header: header,
    lean: lean,
    tagHeight: tagHeight,
    tagColumns: columns,
    wideStrand: wideStrand && columns > 1,
    tagNames: tagNames,
    tagWidth: tagWidth,
    dealt: dealt,
    you: you,
    hanged: hanged,
    reachLeft: dealt ? EndMetrics.dealtOutX * dw : 0,
    reachRight: math.max(
      // Room for the seal on every card, so no card moves with who is looking.
      EndMetrics.sealHang,
      hanged ? rw * (1 - EndMetrics.ribbonInside) : 0,
    ),
    above:
        lean.height +
        math.max(
          dealt
              ? math.max(EndMetrics.gapDealt, dealtUp + EndMetrics.hangClear)
              : EndMetrics.gap,
          hanged ? ribbonUp + EndMetrics.hangClear : 0,
        ),
  );
}
