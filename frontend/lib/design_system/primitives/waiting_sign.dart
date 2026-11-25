import 'dart:async';

import 'package:flutter/material.dart';

import '../copy/copy.dart';
import '../feel/ambient.dart';
import '../layout/space.dart';
import '../skin/skin.dart';
import 'fit_line.dart';
import 'notice.dart';
import 'paper_lantern.dart';

/// What a wait says, by how long it has lasted and whether it is failing
/// (feel.md, "Loading"): the same on every screen that waits.
enum WaitStage {
  /// Not yet [Motion.signAfter]: the screen's own frame, nothing else. An
  /// answer that comes now shows no sign at all, so nothing flashes.
  quiet,

  /// The sign of life: three paper lanterns, lit one after another.
  sign,

  /// Past [Motion.slowAfter] with nothing failed: "Still on its way."
  slow,

  /// A fetch failed (it is made again by itself): "One moment", alone.
  failing,
}

/// The one body every waiting screen has (opening the app, joining, entering
/// a game, the stage's data not here yet): three paper lanterns hung from
/// the top of where it is laid (a screen puts it under its header's edge),
/// lit one after another; a plain line under them when the wait is long; and
/// "One moment" with "Try again", on its own and one line, while a fetch is
/// failing (never lanterns and a failure at once).
///
/// It is laid in the frame of the screen it waits for (its ground, its
/// header, its headline), so the answer lands on a screen already there and
/// nothing flashes; it never holds anything back: it only ever adds to the
/// frame, and the real content replaces it the frame it arrives
/// (`SceneSwitcher`'s crossfade). With reduce motion the lanterns burn
/// steadily.
class Waiting extends StatefulWidget {
  const Waiting({
    super.key,
    this.failing = false,
    this.onRetry,
    this.centred = false,
  });

  /// The fetch is failing and being made again.
  final bool failing;

  /// "Try again": the fetch now, instead of at its next turn. Offered with
  /// "One moment" when it is given.
  final VoidCallback? onRetry;

  /// The lanterns and their line in the middle (hung from a band or a
  /// picture's edge), else from the start (under a headline).
  final bool centred;

  @override
  State<Waiting> createState() => _WaitingState();
}

class _WaitingState extends State<Waiting> {
  Timer? _sign;
  Timer? _slow;
  var _signed = false;
  var _slowed = false;

  @override
  void initState() {
    super.initState();
    _sign = Timer(Motion.signAfter, () => setState(() => _signed = true));
    _slow = Timer(Motion.slowAfter, () => setState(() => _slowed = true));
  }

  @override
  void dispose() {
    _sign?.cancel();
    _slow?.cancel();
    super.dispose();
  }

  WaitStage get stage => widget.failing
      ? WaitStage.failing
      : _slowed
      ? WaitStage.slow
      : _signed
      ? WaitStage.sign
      : WaitStage.quiet;

  @override
  Widget build(BuildContext context) {
    final stage = this.stage;
    final style = context.skin.typography.body.copyWith(
      color: context.ground.text,
    );
    // The line's place is kept from the first frame, so it coming in moves
    // nothing (the title above a bottom-laid body would jump).
    final lineHeight = MediaQuery.textScalerOf(
      context,
    ).scale((style.fontSize ?? 16) * (style.height ?? 1.3));
    return Semantics(
      liveRegion: true,
      label: SpokenCopy.working,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          if (stage == WaitStage.failing)
            Notice(
              message: BannerCopy.offline,
              action: widget.onRetry == null ? null : BannerCopy.tryAgain,
              onAction: widget.onRetry,
            )
          else ...[
            Align(
              alignment: widget.centred
                  ? Alignment.topCenter
                  : Alignment.topLeft,
              child: WaitingSign(shown: stage != WaitStage.quiet),
            ),
            const SizedBox(height: Space.sm),
            SizedBox(
              height: lineHeight,
              child: stage == WaitStage.slow
                  ? TweenAnimationBuilder<double>(
                      tween: Tween(begin: 0, end: 1),
                      duration: Motion.within(context, Motion.settle),
                      curve: Motion.curve,
                      builder: (context, t, child) =>
                          Opacity(opacity: t, child: child),
                      child: FitWords(
                        BannerCopy.slow,
                        textAlign: widget.centred
                            ? TextAlign.center
                            : TextAlign.start,
                        style: style,
                      ),
                    )
                  : null,
            ),
          ],
        ],
      ),
    );
  }
}

/// Three paper lanterns hung from the top edge of where this is laid, on
/// cords of different lengths, lit one after another over [Motion.waitLoop]:
/// calm, one idea, nothing that moves but the light. They fade in over
/// [Motion.settle] when [shown] turns true. With reduce motion all three
/// burn steadily.
class WaitingSign extends StatelessWidget {
  const WaitingSign({super.key, this.shown = true});

  final bool shown;

  /// How far each hangs: the cords differ, so they do not look like a row of
  /// dots.
  static const cords = [Space.xs, Space.xl, Space.md];

  /// The height this takes, cords and lanterns.
  static final height = cords
      .map((c) => PaperLantern.heightFor(Sizes.waitLantern, c))
      .reduce((a, b) => a > b ? a : b);

  /// How brightly lantern [i] burns at the loop's [t]: each rises to full
  /// and sinks back in its own third, one after another (the others keep a
  /// glimmer), so one idea moves at a time.
  static double lit(int i, double t) {
    final local = (t * 3 - i).clamp(0.0, 1.0);
    final bump = local <= 0 || local >= 1
        ? 0.0
        : Curves.easeInOut.transform(local < 0.5 ? local * 2 : (1 - local) * 2);
    return 0.22 + 0.78 * bump;
  }

  @override
  Widget build(BuildContext context) {
    final steady = MediaQuery.disableAnimationsOf(context);
    return AnimatedOpacity(
      opacity: shown ? 1 : 0,
      duration: Motion.within(context, Motion.settle),
      curve: Motion.curve,
      child: ExcludeSemantics(
        // Its job is to show the wait, so it loops while shown, with no
        // rest; only the lanterns' paint follows it, in its own layer.
        child: Ambient.continuous(
          still: 1,
          period: Motion.waitLoop,
          curve: Curves.linear,
          reverse: false,
          running: shown,
          builder: (context, loop, _) => SizedBox(
            height: WaitingSign.height,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: Sizes.waitGap,
              children: [
                for (var i = 0; i < 3; i++)
                  steady
                      ? PaperLantern(
                          width: Sizes.waitLantern,
                          cord: WaitingSign.cords[i],
                          lit: 1,
                        )
                      : PaperLantern.driven(
                          width: Sizes.waitLantern,
                          cord: WaitingSign.cords[i],
                          loop: loop,
                          litAt: (t) => WaitingSign.lit(i, t),
                        ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
