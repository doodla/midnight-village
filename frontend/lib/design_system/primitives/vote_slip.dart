import 'package:flutter/material.dart';

import '../copy/copy.dart';
import '../feel/press.dart';
import '../layout/space.dart';
import '../skin/art_set.dart';
import '../skin/dress.dart';
import '../skin/dress_style.dart';
import '../skin/skin.dart';
import 'fit_line.dart';
import 'paper_mark.dart';
import 'paper_piece.dart';
import 'paper_seal.dart';
import 'player_row.dart';
import 'player_token.dart';
import 'you_tag.dart';

/// A player on the vote's board (09): a slip of bone paper laid on the felt
/// (a [PaperPiece] of part scrap: one soft shadow, from the screen's one
/// light; no pin), their sigil as a cut disc and their name in the name face,
/// wrapped between words and set smaller before it is ever cut. It is laid
/// out exactly as a [PlayerRow] of the same [size] (the vote measures its
/// rows by that), and plain it IS that row.
///
/// - [onTap]: it is a button; a finger sinks the paper into its shadow the
///   frame it lands ([Pressable], by paint alone).
/// - [picked]: lifted, with the paper mark on its corner (in a picked tag's
///   navy wax, so it stands off the bone): chosen, not yet final (the amber
///   plaque under the board still asks to lock it).
/// - [sealed]: the vote locked on this player (the owner's red row and seal,
///   22 November 2026): the slip is cut in dried-blood red with bone words,
///   and a [PaperSeal] lands on the sigil's lower corner (in place at once on
///   a slip that opened sealed). The one red here that is not the Werewolf
///   team's, and only on a locked vote.
/// - [dimmed]: once locked, every other slip lies down into the felt (the
///   paper solid, its shadow gone) and its sigil and name dim alike.
/// - [practice]: "Practice" after the name, on its line.
class VoteSlip extends StatefulWidget {
  const VoteSlip({
    super.key,
    required this.token,
    required this.name,
    this.size = PlayerRowSize.compact,
    this.stretch = 0,
    this.picked = false,
    this.sealed = false,
    this.dimmed = false,
    this.practice = false,
    this.onTap,
  });

  final TokenId? token;
  final String name;
  final PlayerRowSize size;

  /// How much taller than [size] the slip stands, where the room allows it.
  final double stretch;
  final bool picked;
  final bool sealed;
  final bool dimmed;
  final bool practice;
  final VoidCallback? onTap;

  /// The seal's width as a share of the sigil's ([PlayerRow]'s).
  static const sealShare = 0.6;

  @override
  State<VoteSlip> createState() => _VoteSlipState();
}

class _VoteSlipState extends State<VoteSlip> {
  /// The slip opened already sealed: no stamp to play (read as it opens,
  /// not when the seal is first drawn).
  late final bool _openedSealed;

  @override
  void initState() {
    super.initState();
    _openedSealed = widget.sealed;
  }

  bool get _tappable => widget.onTap != null && !widget.dimmed;

  @override
  Widget build(BuildContext context) {
    final w = widget;
    if (!context.dress.isPaper) {
      return PlayerRow(
        token: w.token,
        name: w.name,
        size: w.size,
        stretch: w.stretch,
        picked: w.picked,
        sealed: w.sealed,
        dimmed: w.dimmed,
        practice: w.practice,
        onTap: w.onTap,
      );
    }
    final skin = context.skin;
    final ground = context.ground;
    const part = PaperPart.scrap;
    final ink = w.sealed ? ground.onDanger : PaperPiece.inkOf(context, part);
    final style = w.size.nameStyle(skin.typography).copyWith(color: ink);
    final tokenSize = w.size.token.size;
    final seal = tokenSize * VoteSlip.sealShare;
    final sigil = Stack(
      clipBehavior: Clip.none,
      children: [
        PlayerToken(w.token, size: w.size.token, ringColor: ink),
        // Stamped inside the sigil's lower right corner, so it never hangs
        // below the paper or reaches the name.
        if (w.sealed)
          Positioned(
            right: seal * PaperSeal.tiltReach,
            bottom: seal * PaperSeal.tiltReach + PaperSeal.drop,
            child: PaperSeal(size: seal, lands: !_openedSealed),
          ),
      ],
    );
    final name = FitWords(w.name, maxLines: 2, style: style);
    final content = Padding(
      padding: EdgeInsets.fromLTRB(
        Space.sm,
        Space.xxs,
        w.size.endPadding,
        Space.xxs,
      ),
      child: Row(
        spacing: w.size.gap,
        children: [
          sigil,
          Expanded(
            child: w.practice
                ? Row(
                    spacing: Space.sm,
                    children: [
                      Flexible(child: name),
                      PracticeTag(ink: ink),
                    ],
                  )
                : Align(alignment: Alignment.centerLeft, child: name),
          ),
        ],
      ),
    );
    Widget paper(Animation<double> press) => PaperPiece(
      // The red is cut in on the frame of the lock, never blended from bone
      // (a grey between them that neither ink reads on).
      key: ValueKey(w.sealed),
      part: part,
      id: (w.token, w.name),
      // Once locked, the others lie down into the felt: solid paper, never
      // a see-through ghost of it.
      pressed: w.dimmed,
      press: press,
      lifted: w.picked,
      fill: w.sealed ? ground.danger : null,
      duration: Motion.within(context, Motion.quick),
      child: ConstrainedBox(
        constraints: BoxConstraints(minHeight: w.size.height + w.stretch),
        child: AnimatedOpacity(
          duration: Motion.within(context, Motion.quick),
          opacity: w.dimmed ? skin.dimmed : 1,
          child: content,
        ),
      ),
    );
    // The navy wax of a picked tag, so the mark stands off the bone.
    Widget shown(Animation<double> press) => PaperMarkCorner(
      shown: w.picked && !w.sealed,
      seal: true,
      child: paper(press),
    );
    return Semantics(
      label: w.name,
      value: w.sealed ? VoteCopy.locked : null,
      button: _tappable ? true : null,
      selected: _tappable || w.sealed ? w.picked || w.sealed : null,
      enabled: w.dimmed ? false : null,
      excludeSemantics: true,
      onTap: _tappable ? w.onTap : null,
      // The press answers the frame the finger lands.
      child: Pressable(
        enabled: _tappable,
        builder: (context, press, _) => GestureDetector(
          behavior: HitTestBehavior.opaque,
          excludeFromSemantics: true,
          onTap: _tappable ? w.onTap : null,
          child: shown(press),
        ),
      ),
    );
  }
}
