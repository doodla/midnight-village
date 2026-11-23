import 'dart:math' as math;

import 'package:flutter/widgets.dart';

import '../layout/space.dart';
import '../skin/art_set.dart';
import '../skin/dress.dart';
import '../skin/dress_style.dart';
import '../skin/skin.dart';
import 'fit_line.dart';
import 'paper_piece.dart';
import 'you_seal.dart';

/// "My night" at rest (08's square): a folded note of bone paper, the same on
/// every phone, its flap sealed with this player's own wax ([YouSeal]) and its
/// words at its foot. What is in it shows only while it is held (the screen's
/// [HoldToReveal], drawn on the board), so the note itself never holds a
/// secret. [pressed]: under the thumb (or open by itself as the talk begins)
/// it sinks into its shadow. [stir]: the seal lifts off the flap and settles,
/// once each time the number goes up (and once as it is first built, when
/// it is above 0): the gesture taught by doing it,
/// never in words (none under reduce motion). The flap is a fold of the same
/// paper (filled shapes, no line). Plain, it is its words.
class SealedNote extends StatefulWidget {
  const SealedNote({
    super.key,
    required this.label,
    required this.token,
    this.pressed = false,
    this.stir = 0,
  });

  final String label;

  /// This player's sigil, pressed in the seal.
  final TokenId? token;
  final bool pressed;
  final int stir;

  /// The note's size at text 1: it grows with its words.
  static const size = Size(200, 74);

  /// The flap's depth, of the note's height at rest.
  static const flapShare = 0.5;

  /// The wax seal across.
  static const seal = 28.0;

  /// How far, and how much turned, the seal lifts as it stirs.
  static const lift = Space.sm;
  static const turn = -9 * math.pi / 180;

  /// The stir: up and back.
  static const stirTime = Duration(milliseconds: 900);

  /// The note's height for its words at [scaler].
  static double heightOf(BuildContext context, TextStyle style) {
    final painter = TextPainter(
      text: TextSpan(text: ' ', style: style),
      textDirection: TextDirection.ltr,
      textScaler: MediaQuery.textScalerOf(context),
      maxLines: 1,
    )..layout();
    final line = painter.height;
    painter.dispose();
    return math.max(
      size.height,
      size.height * flapShare + seal / 2 + Space.xs + line + Space.sm,
    );
  }

  @override
  State<SealedNote> createState() => _SealedNoteState();
}

class _SealedNoteState extends State<SealedNote>
    with SingleTickerProviderStateMixin {
  late final _stir = AnimationController(
    vsync: this,
    duration: SealedNote.stirTime,
  );

  @override
  void initState() {
    super.initState();
    if (widget.stir > 0) {
      WidgetsBinding.instance.addPostFrameCallback((_) => _play());
    }
  }

  @override
  void didUpdateWidget(SealedNote old) {
    super.didUpdateWidget(old);
    if (widget.stir > old.stir) _play();
  }

  void _play() {
    if (!mounted || MediaQuery.disableAnimationsOf(context)) return;
    _stir.forward(from: 0);
  }

  @override
  void dispose() {
    _stir.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final paper = context.dress.isPaper;
    final style = skin.typography.buttonLabel.copyWith(
      color: paper
          ? PaperPiece.inkOf(context, PaperPart.scrap)
          : context.ground.text,
    );
    final words = FitLine(widget.label, style: style);
    if (!paper) return words;
    final height = SealedNote.heightOf(context, style);
    final flap = SealedNote.size.height * SealedNote.flapShare;
    final fill = PaperPiece.fillOf(context, PaperPart.scrap);
    final fold = Color.lerp(fill, skin.paper.text, skin.parts.foldShade)!;
    final face = Color.lerp(fill, context.ground.text, skin.parts.flapLight)!;
    return SizedBox(
      width: SealedNote.size.width,
      height: height,
      child: PaperPiece(
        part: PaperPart.scrap,
        id: 'sealed_note',
        pressed: widget.pressed,
        child: Stack(
          clipBehavior: Clip.none,
          children: [
            Positioned(
              left: 0,
              right: 0,
              top: 0,
              height: flap,
              child: CustomPaint(
                painter: _FlapPainter(fold: fold, face: face),
              ),
            ),
            Positioned(
              left: Space.sm,
              right: Space.sm,
              bottom: Space.sm,
              child: Center(child: words),
            ),
            Positioned(
              left: 0,
              right: 0,
              top: flap - SealedNote.seal / 2,
              child: Center(
                child: AnimatedBuilder(
                  animation: _stir,
                  builder: (context, child) {
                    // Up, a little turned, and back: a sine over the stir.
                    final t = math.sin(_stir.value * math.pi);
                    return Transform.translate(
                      offset: Offset(0, -SealedNote.lift * t),
                      child: Transform.rotate(
                        angle: SealedNote.turn * t,
                        child: child,
                      ),
                    );
                  },
                  child: YouSeal(token: widget.token, size: SealedNote.seal),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

/// The flap: a fold of the note's own paper from its top corners to its
/// middle, a hair lighter, with the fold's shade under it. Filled shapes only.
class _FlapPainter extends CustomPainter {
  const _FlapPainter({required this.fold, required this.face});

  final Color fold;
  final Color face;

  @override
  void paint(Canvas canvas, Size size) {
    Path flap(double drop) => Path()
      ..moveTo(Space.xxs, 0)
      ..lineTo(size.width - Space.xxs, 0)
      ..lineTo(size.width / 2, size.height + drop)
      ..close();
    canvas
      ..drawPath(flap(Space.hairline), Paint()..color = fold)
      ..drawPath(flap(0), Paint()..color = face);
  }

  @override
  bool shouldRepaint(_FlapPainter old) => old.fold != fold || old.face != face;
}
