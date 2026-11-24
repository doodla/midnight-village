import 'dart:math' as math;

import 'package:flutter/material.dart';

import '../layout/space.dart';
import '../skin/art_set.dart';
import '../skin/dress.dart';
import '../skin/skin.dart';
import '../skin/skin_tilt.dart';
import '../skin/skin_type.dart';
import 'cut_paper.dart';
import 'deckled_paper.dart';
import 'paper_mark.dart';
import 'paper_pin.dart';
import 'tilted_paper.dart';
import 'fit_line.dart';
import 'paper_seal.dart';
import 'player_token.dart';
import 'you_tag.dart';

/// [PlayerRow]'s sizes: the mocks' rows, shrunk to the one name size (16,
/// `type.name`; the owner's type choice of 23 November 2026). A row that is
/// tapped (the vote's) is never under 48 tall.
enum PlayerRowSize {
  /// At the table (S02): 38 tall, a 26 token (or the [PlayerNameSize] above
  /// it for the name).
  lobby(
    height: 38,
    token: TokenSize.lobby,
    gap: Space.smPlus,
    endPadding: Space.smPlus,
  ),

  /// The vote's compact fallback (S09): 48 tall, a 32 token.
  compact(
    height: 48,
    token: TokenSize.row,
    gap: Space.md,
    endPadding: Space.md,
  ),

  /// In the vote (S09): 52 tall, a 38 token.
  large(
    height: 52,
    token: TokenSize.vote,
    gap: Space.mdPlus,
    endPadding: Space.lg,
  ),

  /// In the vote when the room holds more than the mock's rows (S09): 88
  /// tall, a 60 token, the name in its one role, so a table of few fills the
  /// screen.
  grand(
    height: 88,
    token: TokenSize.grand,
    gap: Space.lg,
    endPadding: Space.xl,
  );

  const PlayerRowSize({
    required this.height,
    required this.token,
    required this.gap,
    required this.endPadding,
  });

  /// The row's least height; it grows with larger text.
  final double height;
  final TokenSize token;

  /// Between the token and the name.
  final double gap;

  /// After the name.
  final double endPadding;

  /// A player's name is one role in every row.
  TextStyle nameStyle(SkinType type) => type.name;
}

/// One name size for every [PlayerRowSize.lobby] row below it: the table's
/// two-up rows all set their names at the size the longest word fits at, so a
/// long name never makes one row's name smaller than its neighbour's.
class PlayerNameSize extends InheritedWidget {
  const PlayerNameSize({super.key, required this.size, required super.child});

  final double size;

  static double? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<PlayerNameSize>()?.size;

  @override
  bool updateShouldNotify(PlayerNameSize old) => size != old.size;
}

/// One player as a strip of paper: token and name. With [onTap] it is a
/// button.
///
/// - [picked]: the player's pick lifts and takes the selection's outline
///   (ink by day); never a fill (first-time play spec, copy rule 10).
/// - [own]: the viewer's own row, a thicker outline in the paper's ink and
///   "You" ([YouTag]) after the name (S02, S10).
/// - [practice]: a practice player (a seat the server plays), "Practice"
///   ([PracticeTag]) on the name's line in every row (the name set smaller
///   first, never moved under it); never [own].
/// - [sealed]: the vote locked on this player: a [PaperSeal] is stamped on
///   the token's lower corner (it lands once, unless the row opened already
///   sealed), and the paper turns dried-blood red with its words in bone
///   (owner, 22 November 2026: "red row and seal"), cut in on the frame of
///   the lock (a tween would pass through a grey no ink reads on). Never a fill of the screen's
///   amber.
/// - [stretch]: how much taller than its size the row stands, where the
///   room allows it (the vote fills the screen).
/// - A row with [onTap] dips 2 px the frame a finger lands and comes back
///   when it lifts or slides away (colour only under reduce motion).
/// - [away]: a dropped member, the token dimmed, with no words (S02).
/// - [dimmed]: the vote once locked, where every row dims the same and none
///   shows the pick (S09).
class PlayerRow extends StatefulWidget {
  const PlayerRow({
    super.key,
    required this.token,
    required this.name,
    this.picked = false,
    this.own = false,
    this.practice = false,
    this.away = false,
    this.dimmed = false,
    this.sealed = false,
    this.stretch = 0,
    this.onTap,
    this.size = PlayerRowSize.compact,
  });

  /// How far a finger presses a row down.
  static const dip = 2.0;

  final TokenId? token;
  final String name;
  final bool picked;
  final bool own;
  final bool practice;
  final bool away;
  final bool dimmed;
  final bool sealed;

  final double stretch;
  final VoidCallback? onTap;
  final PlayerRowSize size;

  @override
  State<PlayerRow> createState() => _PlayerRowState();
}

class _PlayerRowState extends State<PlayerRow> {
  /// A finger is on the row.
  var _down = false;

  /// The row opened already sealed: no stamp to play.
  late final bool _openedSealed;

  @override
  void initState() {
    super.initState();
    _openedSealed = widget.sealed;
  }

  void _touch(bool down) {
    if (_down != down && mounted) setState(() => _down = down);
  }

  /// The seal's width as a share of the token's.
  static const _sealSize = 0.6;

  /// The ink with more contrast on [paper].
  static Color _inkOn(Color paper, Color dark, Color light) =>
      _contrast(dark, paper) >= _contrast(light, paper) ? dark : light;

  /// WCAG 2.1 contrast ratio of two opaque colours.
  static double _contrast(Color a, Color b) {
    final (la, lb) = (a.computeLuminance(), b.computeLuminance());
    return (math.max(la, lb) + 0.05) / (math.min(la, lb) + 0.05);
  }

  Size _size(BuildContext context) => context.size ?? Size.zero;

  PlayerRowSize get size => widget.size;
  bool get picked => widget.picked;

  @override
  Widget build(BuildContext context) {
    final (token, name) = (widget.token, widget.name);
    final (own, practice, away, dimmed, onTap) = (
      widget.own,
      widget.practice,
      widget.away,
      widget.dimmed,
      widget.onTap,
    );
    final sealed = widget.sealed;
    final skin = context.skin;
    final ground = context.ground;
    final red = sealed;
    final reduced = MediaQuery.disableAnimationsOf(context);
    // A finger answers in the first frame (`press` down, `quick` back up);
    // with reduce motion the paper tints instead of moving.
    final pressed = _down && onTap != null && !dimmed;
    final dip = pressed && !reduced ? PlayerRow.dip : 0.0;
    final lift = picked ? Space.xs : 0.0;
    final base = picked ? ground.elevation.selected : ground.elevation.card;
    final fill = red
        ? ground.danger
        : pressed && reduced
        ? Color.alphaBlend(
            skin.paper.text.withValues(alpha: 0.08),
            ground.paper,
          )
        : ground.paper;
    // Whichever ink reads better on the paper. The paper only changes colour
    // in a cut (the lock; a tint of a few percent), never through the grey
    // between bone and red where neither ink reaches 4.5:1, so the ink is
    // the right one on every frame.
    final ink = _inkOn(fill, skin.paper.text, ground.onDanger);
    final duration = Motion.within(
      context,
      _down ? Motion.press : Motion.quick,
    );
    final lead = skin.shape.corner(
      size.height + widget.stretch,
      skin.shape.rowLeadRoundness,
      square: skin.shape.radius,
    );
    final radius = BorderRadius.horizontal(
      left: Radius.circular(lead),
      right: Radius.circular(skin.shape.radius),
    );

    final scoped = size == PlayerRowSize.lobby
        ? PlayerNameSize.of(context)
        : null;
    final nameStyle = scoped == null
        ? size.nameStyle(skin.typography)
        : size.nameStyle(skin.typography).copyWith(fontSize: scoped);

    final content = Row(
      spacing: size.gap,
      children: [
        Stack(
          clipBehavior: Clip.none,
          children: [
            PlayerToken(
              token,
              size: size.token,
              ringColor: ink,
              away: away && !sealed,
            ),
            // Stamped inside the portrait's lower right corner (its tilt
            // and shadow too), so it never hangs below the paper or
            // reaches the name, which it also grows away from.
            if (sealed)
              Positioned(
                right: size.token.size * _sealSize * PaperSeal.tiltReach,
                bottom:
                    size.token.size * _sealSize * PaperSeal.tiltReach +
                    PaperSeal.drop,
                child: PaperSeal(
                  size: size.token.size * _sealSize,
                  lands: !_openedSealed,
                ),
              ),
          ],
        ),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              // A long name wraps between words, then is set smaller;
              // never cut short.
              // "You" beside the name where both fit, under it where
              // not, so a long name keeps its room and a short one its
              // size.
              if (own)
                Wrap(
                  spacing: Space.sm,
                  runSpacing: Space.xxs,
                  crossAxisAlignment: WrapCrossAlignment.center,
                  children: [
                    FitWords(
                      name,
                      maxLines: 2,
                      style: nameStyle.copyWith(color: ink),
                    ),
                    YouTag(ink: ink),
                  ],
                )
              // "Practice" always on the name's line, so every row of
              // a list is laid out alike.
              else if (practice)
                Row(
                  spacing: Space.sm,
                  children: [
                    Flexible(
                      child: FitWords(
                        name,
                        maxLines: 2,
                        style: nameStyle.copyWith(color: ink),
                      ),
                    ),
                    PracticeTag(ink: ink),
                  ],
                )
              else
                FitWords(
                  name,
                  maxLines: 2,
                  style: nameStyle.copyWith(color: ink),
                ),
            ],
          ),
        ),
      ],
    );
    final dressed = context.dress.isPaper;
    Widget plainPaper() => AnimatedContainer(
      // The red is cut in, not blended from bone (see [ink]).
      key: ValueKey(red),
      duration: duration,
      curve: Motion.curve,
      transform: Matrix4.translationValues(0, dip - lift, 0),
      padding: EdgeInsets.fromLTRB(
        Space.sm,
        Space.xxs,
        size.endPadding,
        Space.xxs,
      ),
      decoration: cutPaper(
        context,
        fill: fill,
        radius: radius,
        elevation: dip > 0 ? base.lowered(dip) : base,
      ),
      foregroundDecoration: picked
          ? ringDecoration(
              color: ground.selection,
              width: skin.shape.selectedRing,
              radius: radius,
            )
          : own
          ? BoxDecoration(
              borderRadius: radius,
              border: Border.all(color: ink, width: skin.shape.selectedRing),
            )
          : null,
      child: content,
    );
    // Dressed up: torn paper set down a hair off square (the same every build,
    // from its name and token), pinned to the table; the words stay level.
    final seed = (token, name);
    Widget dressedPaper() => AnimatedContainer(
      key: ValueKey(red),
      duration: duration,
      curve: Motion.curve,
      transform: Matrix4.translationValues(0, dip - lift, 0),
      child: TiltedPaper(
        angle: skin.tilt.angle(Tilt.seededRow('${token?.name}:$name')),
        duration: duration,
        decoration: deckledPaper(
          context,
          fill: fill,
          id: seed,
          elevation: dip > 0 ? base.lowered(dip) : base,
        ),
        // Picked is the paper's mark and the lift, never a ring; the viewer's
        // own row is told by its "You" tag (a ring along the torn edge was a
        // border).
        child: Padding(
          padding: EdgeInsets.fromLTRB(
            Space.sm,
            Space.xxs,
            size.endPadding,
            Space.xxs,
          ),
          child: content,
        ),
      ),
    );
    final Widget paper = dressed ? dressedPaper() : plainPaper();
    // The height is set here, outside the tween: a row that changes size
    // (the room changed) is the new size at once, never mid-way and over.
    final row = ConstrainedBox(
      constraints: BoxConstraints(minHeight: size.height + widget.stretch),
      child: paper,
    );
    final shown = AnimatedOpacity(
      duration: Motion.within(context, Motion.quick),
      opacity: dimmed ? skin.dimmed : 1,
      child: dressed
          // Pinned to the table: a flat pin through the top edge, a pick
          // wearing the paper's mark on its corner.
          ? PaperMarkCorner(
              shown: picked,
              child: Stack(
                clipBehavior: Clip.none,
                children: [
                  row,
                  Positioned(
                    top: -skin.parts.pinSize / 3,
                    left: Space.xl + Space.lg,
                    child: PaperPin(ink: ink),
                  ),
                ],
              ),
            )
          : row,
    );
    // Once locked (dimmed) a row cannot be picked: it reads as switched off.
    // One tree whatever the row can do, so a row that is locked (or dimmed)
    // keeps its state and its tweens.
    final tappable = onTap != null && !dimmed;
    return Semantics(
      enabled: dimmed ? false : null,
      button: tappable ? true : null,
      selected: tappable ? picked : null,
      child: Listener(
        // The press answers the frame the finger lands, not when the tap is
        // recognised.
        onPointerDown: (_) => tappable ? _touch(true) : null,
        // Sliding off the row cancels the press (the tap is cancelled too).
        onPointerMove: (event) {
          if (_down &&
              !(Offset.zero & _size(context)).contains(event.localPosition)) {
            _touch(false);
          }
        },
        onPointerUp: (_) => _touch(false),
        onPointerCancel: (_) => _touch(false),
        child: Material(
          type: MaterialType.transparency,
          // Material sets its own default text style (the theme's body)
          // under it, for every row, tappable or not; the row's words take
          // the one they were given from above.
          textStyle: DefaultTextStyle.of(context).style,
          child: InkWell(
            onTap: tappable ? onTap : null,
            onHighlightChanged: (value) {
              if (!value) _touch(false);
            },
            borderRadius: radius,
            highlightColor: Colors.transparent,
            splashColor: Colors.transparent,
            child: shown,
          ),
        ),
      ),
    );
  }
}
