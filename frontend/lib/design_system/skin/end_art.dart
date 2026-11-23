import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import 'art_set.dart';

/// The end board's ornaments (`assets/skins/shadow_paper/end/<file>.webp`, made
/// from `docs/design/art/end/` by `just skin-art`; where each came from:
/// `docs/design/art/end/PROVENANCE.md`). The board's three stretching pieces
/// (the banner, the frame and the roof) keep the pixels they were cut in,
/// because their slices are declared in those pixels.
enum EndPiece {
  banner('banner', Size(1460, 477)),
  bannerRed('banner_red', Size(1460, 477)),
  frame('frame', Size(666, 863)),
  roof('roof', Size(629, 140)),
  postLeft('post_l', Size(79, 147)),
  postRight('post_r', Size(81, 148)),
  lantern('lantern', Size(264, 456)),
  crow1('crow_1', Size(312, 424)),
  crow2('crow_2', Size(312, 232)),
  crow3('crow_3', Size(312, 311)),
  crow4('crow_4', Size(312, 255)),
  crow5('crow_5', Size(312, 244)),
  crow6('crow_6', Size(312, 310)),
  cobbles('cobbles', Size(1170, 651)),
  seal('seal', Size(90, 90)),
  ribbon('ribbon', Size(153, 193));

  const EndPiece(this.file, this.pixels);

  /// The file's name under `end/`.
  final String file;

  /// The file's size in pixels (checked against the bundle by
  /// `skin_contract_test.dart`).
  final Size pixels;
}

/// How a stretching piece is cut: the [slice] (in the file's own pixels: the
/// corners and ends outside it never stretch) and [pixelsPerPoint], how many of
/// the file's pixels make one logical pixel at the size the board draws it.
/// So an end is always `slice.left / pixelsPerPoint` wide, however wide or
/// tall the piece is made.
@immutable
class SliceArt {
  const SliceArt(this.piece, this.slice, this.pixelsPerPoint);

  final EndPiece piece;
  final Rect slice;
  final double pixelsPerPoint;

  Size get pixels => piece.pixels;

  /// The ends, as drawn: the left, the top, the right and the bottom.
  EdgeInsets get ends => EdgeInsets.fromLTRB(
    slice.left / pixelsPerPoint,
    slice.top / pixelsPerPoint,
    (pixels.width - slice.right) / pixelsPerPoint,
    (pixels.height - slice.bottom) / pixelsPerPoint,
  );

  /// A [slice] (this piece's own when null) in the picture's logical pixels,
  /// as Flutter's `centerSlice` wants it: the file's pixels over the scale.
  Rect inPoints([Rect? slice]) {
    final r = slice ?? this.slice;
    return Rect.fromLTRB(
      r.left / pixelsPerPoint,
      r.top / pixelsPerPoint,
      r.right / pixelsPerPoint,
      r.bottom / pixelsPerPoint,
    );
  }

  /// The size at rest: the file's own, in logical pixels.
  Size get natural => pixels / pixelsPerPoint;

  /// The same piece cut another way: a banner that takes a third line is cut
  /// with [bannerTall], a middle that stretches in height too, the ends staying
  /// as they are.
  SliceArt withSlice(Rect slice) => SliceArt(piece, slice, pixelsPerPoint);

  /// The swallowtail banner is 128 tall; its three pieces (an end, a middle
  /// that stretches with the words, an end) run the full height.
  static const banner = SliceArt(
    EndPiece.banner,
    Rect.fromLTRB(300, 0, 1130, 477),
    477 / 128,
  );

  /// The same cut for the red banner (the same silhouette to the pixel).
  static const bannerRed = SliceArt(
    EndPiece.bannerRed,
    Rect.fromLTRB(300, 0, 1130, 477),
    477 / 128,
  );

  /// A banner of three lines: the middle stretches in height too (the ends
  /// stay as they are).
  static const bannerTall = Rect.fromLTRB(300, 140, 1130, 330);

  /// The board's frame, about 19 pt (`0.19` points a pixel), nine slices.
  static const frame = SliceArt(
    EndPiece.frame,
    Rect.fromLTRB(99, 102, 570, 761),
    1 / 0.19,
  );

  /// The roof, 30 tall, its middle stretching in width only.
  static const roof = SliceArt(
    EndPiece.roof,
    Rect.fromLTRB(120, 0, 509, 140),
    140 / 30,
  );
}

/// The art of the end board in one skin's folder (`ArtSet.end`).
@immutable
class EndArt {
  const EndArt(this.folder);

  final String folder;

  ArtImage piece(EndPiece piece) =>
      ArtImage('$folder/end/${piece.file}.webp', pixels: piece.pixels);

  /// Where the lantern's light is, as a share of the lantern's width and
  /// height, as the board shows it (turned round, hung from its top right):
  /// the centre of its four panes, read off the picture.
  static const lanternLight = Offset(0.41, 0.755);

  /// How wide and tall the lantern is drawn.
  static const lanternSize = Size(88, 152);

  /// The crows, in the order of the files.
  static const crows = [
    EndPiece.crow1,
    EndPiece.crow2,
    EndPiece.crow3,
    EndPiece.crow4,
    EndPiece.crow5,
    EndPiece.crow6,
  ];
}
