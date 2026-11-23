import 'package:flutter/widgets.dart';

import '../copy/copy.dart';
import '../layout/space.dart';
import '../skin/dress.dart';
import '../skin/dress_style.dart';
import '../skin/skin.dart';
import 'fit_line.dart';
import 'paper_pin.dart';
import 'paper_piece.dart';
import 'secondary_button.dart' show BusyMark;

/// A scrap of bone paper pinned to a board, and tapped as a whole: "What
/// happened", "Edit deck", "Leave". Its paper is [paperHeight] tall (more where
/// its words take two lines) and the finger's target is [touchHeight] tall,
/// the paper and an invisible margin round it, so a scrap that looks 40 is hit
/// at 48. The words are in the name face (16), never cut: they are set smaller
/// or on two lines between words. It is a [PaperPiece] (part scrap), with the
/// skin's flat pin through its top left; on a plain screen it is its words in
/// the ground's ink, with the same target.
class PaperScrap extends StatelessWidget {
  const PaperScrap({
    super.key,
    required this.label,
    required this.onTap,
    this.id,
    this.pinned = true,
    this.width,
    this.sends = false,
    this.busy = false,
  }) : assert(!busy || sends, 'a scrap that can be busy is one that sends');

  /// The words. A break the caller wants is a newline.
  final String label;
  final VoidCallback onTap;

  /// Its tap sends a request, so it can be [busy]: its paper keeps the busy
  /// mark's room at its end, as a button's padding does, so the mark never
  /// lies on its words and the words never move.
  final bool sends;

  /// Its request is on its way: as on `PrimaryButton` and `SecondaryButton`,
  /// the busy mark turns in the paper's own end room, the words stay in their
  /// place in their full ink, and a tap does nothing.
  final bool busy;

  /// Seeds the tear and the tilt (the label when null).
  final Object? id;
  final bool pinned;

  /// The paper's width; as wide as its words when null.
  final double? width;

  /// The paper's height for one line of words.
  static const paperHeight = 40.0;

  /// The paper's height for two lines of words.
  static const paperHeightTwoLines = 48.0;

  /// What a finger can hit: the paper and the invisible margin round it.
  static const touchHeight = 48.0;

  /// The end room of a scrap that [sends]: the busy mark, [Space.sm] in from
  /// the paper's end, and air between it and the words.
  static const busyRoom = Space.sm + Space.xl + Space.xxs;

  Widget _busy(BuildContext context, Widget scrap) =>
      _busyOver(context, scrap, busy);

  @override
  Widget build(BuildContext context) {
    final words = _Words(
      label,
      pinned: pinned && context.dress.isPaper,
      endRoom: sends ? busyRoom : Space.md,
    );
    final tap = busy ? null : onTap;
    return Semantics(
      button: true,
      label: label.replaceAll('\n', ' '),
      value: busy ? SpokenCopy.working : null,
      excludeSemantics: true,
      onTap: tap,
      child: GestureDetector(
        behavior: HitTestBehavior.opaque,
        onTap: tap,
        child: ConstrainedBox(
          constraints: const BoxConstraints(minHeight: touchHeight),
          child: Center(
            widthFactor: 1,
            heightFactor: 1,
            child: _busy(
              context,
              context.dress.isPaper
                  ? SizedBox(
                      width: width,
                      child: PaperPiece(
                        part: PaperPart.scrap,
                        id: id ?? label,
                        child: words,
                      ),
                    )
                  : SizedBox(width: width, child: words),
            ),
          ),
        ),
      ),
    );
  }
}

/// While busy: the busy mark turning in the scrap's own end room
/// ([PaperScrap.busyRoom]), in its words' ink; the words keep their place and
/// their ink, and nothing beside it moves (the form of `PrimaryButton`'s and
/// `SecondaryButton`'s `Pending`).
Widget _busyOver(BuildContext context, Widget scrap, bool busy) {
  if (!busy) return scrap;
  final ink = context.dress.isPaper
      ? PaperPiece.inkOf(context, PaperPart.scrap)
      : context.ground.text;
  return Stack(
    alignment: Alignment.center,
    children: [
      scrap,
      PositionedDirectional(
        end: Space.sm,
        child: BusyMark(size: Space.xl, color: ink),
      ),
    ],
  );
}

/// A slip of bone paper that says something and is no control: the words of a
/// step, "{host} deals next.", a number on a twine. Pinned when it is on a
/// board, loose when it is not. Its words are in the name face, never cut.
class PaperSlip extends StatelessWidget {
  const PaperSlip({
    super.key,
    required this.label,
    this.id,
    this.pinned = true,
    this.maxWidth,
    this.maxLines,
  });

  final String label;
  final Object? id;
  final bool pinned;

  /// The most lines its words wrap to (null: the lines [label] has): a
  /// sentence of any length on a slip of [maxWidth].
  final int? maxLines;

  /// The most it is wide: its words wrap between words, then are set smaller,
  /// before they are cut.
  final double? maxWidth;

  @override
  Widget build(BuildContext context) {
    final paper = context.dress.isPaper;
    final words = _Words(label, pinned: pinned && paper, maxLines: maxLines);
    final body = paper
        ? PaperPiece(part: PaperPart.scrap, id: id ?? label, child: words)
        : words;
    return Semantics(
      label: label.replaceAll('\n', ' '),
      excludeSemantics: true,
      child: maxWidth == null
          ? body
          : ConstrainedBox(
              constraints: BoxConstraints(maxWidth: maxWidth!),
              child: body,
            ),
    );
  }
}

/// The words of a scrap or a slip, on its paper: padded, with the pin's room
/// kept clear on the left when it is pinned.
class _Words extends StatelessWidget {
  const _Words(
    this.label, {
    required this.pinned,
    this.maxLines,
    this.endRoom = Space.md,
  });

  final String label;
  final bool pinned;
  final int? maxLines;

  /// The padding at its end: more on a scrap that sends, for the busy mark.
  final double endRoom;

  @override
  Widget build(BuildContext context) {
    final paper = context.dress.isPaper;
    final drawn = '\n'.allMatches(label).length + 1;
    final lines = maxLines ?? drawn;
    final style = context.skin.typography.name.copyWith(
      color: paper
          ? PaperPiece.inkOf(context, PaperPart.scrap)
          : context.ground.text,
    );
    final pin = context.skin.parts.pinSize;
    final body = ConstrainedBox(
      constraints: BoxConstraints(
        minHeight: drawn > 1
            ? PaperScrap.paperHeightTwoLines
            : PaperScrap.paperHeight,
      ),
      child: Padding(
        padding: EdgeInsets.fromLTRB(
          pinned ? Space.md + pin : Space.md,
          Space.xxs,
          endRoom,
          Space.xxs,
        ),
        child: Center(
          widthFactor: 1,
          heightFactor: 1,
          child: FitWords(
            label,
            style: style,
            textAlign: TextAlign.center,
            maxLines: lines,
          ),
        ),
      ),
    );
    if (!pinned) return body;
    return Stack(
      clipBehavior: Clip.none,
      children: [
        body,
        Positioned(
          left: Space.xs,
          top: Space.xs,
          child: PaperPin(ink: PaperPiece.inkOf(context, PaperPart.scrap)),
        ),
      ],
    );
  }
}
