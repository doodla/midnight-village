import 'dart:math' as math;

import 'package:flutter/foundation.dart' show listEquals;
import 'package:flutter/material.dart';

import '../layout/space.dart';
import '../skin/art_set.dart';
import '../skin/skin.dart';
import '../skin/skin_type.dart';
import 'cut_paper.dart';
import 'fit_line.dart';
import 'paper_seal.dart';
import 'player_token.dart';
import 'you_tag.dart';

/// [PlayerRow]'s sizes, from the mocks.
enum PlayerRowSize {
  /// At the table (S02): 46 tall, a 32 token, the name at 18 (or the
  /// [PlayerNameSize] above it).
  lobby(
    height: 46,
    token: TokenSize.lobby,
    gap: Space.smPlus,
    endPadding: Space.smPlus,
    nameSize: 18,
  ),

  /// The vote's compact fallback (S09): 52 tall, a 38 token, the name at 21.
  compact(
    height: 52,
    token: TokenSize.row,
    gap: Space.md,
    endPadding: Space.md,
  ),

  /// In the vote (S09): 68 tall, a 52 token, the name at 26.
  large(
    height: 68,
    token: TokenSize.vote,
    gap: Space.mdPlus,
    endPadding: Space.lg,
  ),

  /// In the vote when the room holds more than the mock's rows (S09): 88
  /// tall, a 60 token, the name at 26, so a table of few fills the screen.
  grand(
    height: 88,
    token: TokenSize.grand,
    gap: Space.lg,
    endPadding: Space.xl,
  ),

  /// In the count (S10): 64 tall, a 48 token, the name at 24, the voters'
  /// names under it and a [Tally] at the end.
  count(
    height: 64,
    token: TokenSize.count,
    gap: Space.md,
    endPadding: Space.mdPlus,
  );

  const PlayerRowSize({
    required this.height,
    required this.token,
    required this.gap,
    required this.endPadding,
    this.nameSize,
  });

  final double height;
  final TokenSize token;

  /// Between the token and the name.
  final double gap;

  /// After the trailing part.
  final double endPadding;

  /// The name's size where it is not a role's own ([lobby]).
  final double? nameSize;

  TextStyle nameStyle(SkinType type) => switch (this) {
    lobby => type.name.copyWith(fontSize: nameSize),
    compact => type.name,
    large || grand => type.title,
    count => type.heading,
  };
}

/// What a locked vote does to the pick's row (09). The owner's choice: the
/// spec's text says the pick "stays as it is" ([sealOnly]); [bloodFill] is the
/// first build's red row.
enum LockedFill {
  /// The pick keeps its bone paper, its lift and its outline, and gets the
  /// seal (a red disc); the other rows dim.
  sealOnly,

  /// The pick's paper turns dried-blood red, cut in on the frame of the lock
  /// (a tween would pass through a grey no ink reads on), its words in bone,
  /// with the seal (a bone disc); the other rows dim.
  bloodFill;

  /// The one in use until the owner chooses.
  static const standard = sealOnly;
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

/// One player as a strip of paper: token, name, an optional [detail] line
/// under the name (who voted for them, by name, S10) and an optional
/// [trailing] part (a [Tally]). With [onTap] it is a button.
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
///   sealed), and with [lockedFill] [LockedFill.bloodFill] the paper turns
///   dried-blood red with its words in bone. Never a fill of the screen's
///   amber.
/// - [condemned]: the count's verdict on a player the vote killed: the
///   [picked] outline is cut in thicker, in the paper's ink (a cut, never a
///   tween). Never red: on this screen red is the Werewolf team's, and a dead
///   Villager must not read as a wolf. No seal.
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
    this.detail,
    this.trailing,
    this.picked = false,
    this.own = false,
    this.practice = false,
    this.away = false,
    this.dimmed = false,
    this.sealed = false,
    this.condemned = false,
    this.lockedFill = LockedFill.standard,
    this.stretch = 0,
    this.onTap,
    this.size = PlayerRowSize.compact,
  });

  /// How far a finger presses a row down.
  static const dip = 2.0;

  /// How much thicker a [condemned] row's outline is than a picked one's.
  static const condemnedExtra = 2.0;

  final TokenId? token;
  final String name;
  final String? detail;
  final Widget? trailing;
  final bool picked;
  final bool own;
  final bool practice;
  final bool away;
  final bool dimmed;
  final bool sealed;
  final bool condemned;

  /// What [sealed] does to the paper.
  final LockedFill lockedFill;
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
    final (token, name, detail, trailing) = (
      widget.token,
      widget.name,
      widget.detail,
      widget.trailing,
    );
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
    final bloody = sealed && widget.lockedFill == LockedFill.bloodFill;
    final red = bloody;
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

    final paper = AnimatedContainer(
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
              width: widget.condemned
                  ? skin.shape.selectedRing + PlayerRow.condemnedExtra
                  : skin.shape.selectedRing,
              radius: radius,
            )
          : own
          ? BoxDecoration(
              borderRadius: radius,
              border: Border.all(color: ink, width: skin.shape.selectedRing),
            )
          : null,
      child: _RowInk(
        ink: ink,
        child: Row(
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
                      onBone: !bloody,
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
                  // Names wrap between words, never inside one.
                  if (detail case final detail?)
                    FitWords(
                      detail,
                      style: skin.typography.body.copyWith(
                        // On red paper the quiet ink is unreadable: the bone.
                        color: red ? ink : skin.paper.quietText,
                      ),
                    ),
                ],
              ),
            ),
            ?trailing,
          ],
        ),
      ),
    );
    // The height is set here, outside the tween: a row that changes size
    // (the room changed) is the new size at once, never mid-way and over.
    final row = ConstrainedBox(
      constraints: BoxConstraints(minHeight: size.height + widget.stretch),
      child: paper,
    );
    final shown = AnimatedOpacity(
      duration: Motion.within(context, Motion.quick),
      opacity: dimmed ? skin.dimmed : 1,
      child: row,
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

class _RowInk extends InheritedWidget {
  const _RowInk({required this.ink, required super.child});

  final Color ink;

  static _RowInk? of(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<_RowInk>();

  @override
  bool updateShouldNotify(_RowInk old) => ink != old.ink;
}

/// The number of votes at the end of a count row (S10). With [struck], and
/// two votes or more, the votes are also tally marks under the number, cut
/// from paper: four strokes and a fifth across them, in the row's ink (one
/// vote is the number alone: a "1" over one mark is only noise). [struck] says how far mark `k`
/// (from 0) is struck, 0 to 1; it is only how the marks arrive, the number is
/// the whole count from the first frame (nothing is held back).
class Tally extends StatelessWidget {
  const Tally(this.count, {super.key, this.struck});

  /// Between the name and the number, on top of the row's own gap.
  static const gap = Space.sm;

  final int count;
  final double Function(int mark)? struck;

  @override
  Widget build(BuildContext context) {
    final ink = _RowInk.of(context)?.ink ?? context.ground.text;
    final number = Text(
      '$count',
      textAlign: TextAlign.end,
      style: context.skin.typography.tally.copyWith(color: ink),
    );
    final struck = this.struck;
    // A gap of its own beyond the row's, so a long name (wrapped, set as
    // large as the room allows) never reads as touching the number.
    if (struck == null || count < 2) {
      return Padding(
        padding: const EdgeInsets.only(left: gap),
        child: number,
      );
    }
    return Padding(
      padding: const EdgeInsets.only(left: gap),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.end,
        spacing: Space.xxs,
        children: [
          number,
          ExcludeSemantics(
            child: CustomPaint(
              size: TallyMarks.sizeOf(count),
              painter: TallyMarks([
                for (var k = 0; k < count; k++) struck(k),
              ], ink),
            ),
          ),
        ],
      ),
    );
  }
}

/// Votes as paper tally marks: groups of five (four strokes and a slash
/// across them), each stroke drawn downward as it is struck. A hand's cut, so
/// every stroke leans a little differently, the same each time.
class TallyMarks extends CustomPainter {
  TallyMarks(this.progress, this.ink);

  /// How far each mark is struck, 0 to 1, in order.
  final List<double> progress;
  final Color ink;

  static const strokeHeight = 18.0;
  static const strokeWidth = 4.0;
  static const pitch = 8.0;
  static const groupGap = 10.0;

  /// A group's width: four strokes (the fifth lies across them).
  static const _group = 3 * pitch + strokeWidth;

  static Size sizeOf(int count) {
    final groups = (count + 4) ~/ 5;
    final last = count - (groups - 1) * 5;
    final lastWidth = last >= 4 ? _group : (last - 1) * pitch + strokeWidth;
    final width = groups == 0
        ? 0.0
        : (groups - 1) * (_group + groupGap) + lastWidth;
    return Size(width, strokeHeight);
  }

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = ink
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.butt;
    for (var k = 0; k < progress.length; k++) {
      final t = Motion.curve.transform(progress[k].clamp(0.0, 1.0));
      if (t <= 0) continue;
      final group = k ~/ 5;
      final at = k % 5;
      final left = group * (_group + groupGap);
      // A little lean, from the stroke's place only.
      final lean = ((k * 7) % 5 - 2) * 0.35;
      if (at < 4) {
        final x = left + at * pitch + strokeWidth / 2;
        canvas.drawLine(
          Offset(x - lean, 0),
          Offset(x - lean + (lean * 2) * t, strokeHeight * t),
          paint,
        );
      } else {
        final end = Offset(left + _group + 1, strokeHeight * 0.15);
        final start = Offset(left - 1, strokeHeight * 0.85);
        canvas.drawLine(start, Offset.lerp(start, end, t)!, paint);
      }
    }
  }

  @override
  bool shouldRepaint(TallyMarks old) =>
      ink != old.ink || !listEquals(progress, old.progress);
}
