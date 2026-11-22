import 'dart:async';

import 'package:flutter/material.dart';

import '../copy/copy.dart';
import '../layout/space.dart';
import '../skin/skin.dart';
import 'cut_paper.dart';
import 'fit_line.dart';
import 'notice.dart';

/// What a wait says, by how long it has lasted and whether it is failing
/// (feel.md, "Loading"): the same on every screen that waits.
enum WaitStage {
  /// Not yet [Motion.signAfter]: the screen's own frame, nothing else. An
  /// answer that comes now shows no sign at all, so nothing flashes.
  quiet,

  /// The sign of life: three paper lanterns lifting in turn.
  sign,

  /// Past [Motion.slowAfter] with nothing failed: "The village is waking."
  slow,

  /// A fetch failed (it is made again by itself): "One moment".
  failing,
}

/// The one body every waiting screen has (opening the app, joining, entering
/// a game, the stage's data not here yet): a sign of life, a plain line when
/// the wait is long, and "One moment" while a fetch is failing.
///
/// It is laid in the frame of the screen it waits for (its ground, its
/// header, its headline), so the answer lands on a screen already there and
/// nothing flashes; it never holds anything back: it only ever adds to the
/// frame, and the real content replaces it the frame it arrives
/// (`SceneSwitcher`'s crossfade). With reduce motion the lanterns stand
/// still.
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

  /// The sign and its line in the middle (a wait standing in for a card or
  /// a list), else from the start (under a headline).
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
    // The line fades in; it is laid out so that nothing already on the
    // screen moves when it comes (the lanterns, and the title above them in
    // a frame that is filled from the foot): beside the lanterns where they
    // start a line, under them (hanging below, out of the layout) where they
    // stand in the middle of a card's or a list's place.
    final line = stage == WaitStage.slow
        ? TweenAnimationBuilder<double>(
            tween: Tween(begin: 0, end: 1),
            duration: Motion.within(context, Motion.settle),
            curve: Motion.curve,
            builder: (context, t, child) => Opacity(opacity: t, child: child),
            child: FitWords(
              BannerCopy.slow,
              textAlign: widget.centred ? TextAlign.center : TextAlign.start,
              style: style,
            ),
          )
        : null;
    final sign = WaitingSign(shown: stage != WaitStage.quiet);
    return Semantics(
      liveRegion: true,
      label: SpokenCopy.working,
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        spacing: Space.md,
        children: [
          if (widget.centred)
            Stack(
              alignment: Alignment.topCenter,
              clipBehavior: Clip.none,
              children: [
                Center(child: sign),
                if (line != null)
                  Positioned(
                    left: 0,
                    right: 0,
                    top: WaitingSign.height + Space.md,
                    child: line,
                  ),
              ],
            )
          else
            Row(
              spacing: Space.md,
              children: [
                sign,
                Expanded(child: line ?? const SizedBox.shrink()),
              ],
            ),
          if (stage == WaitStage.failing)
            Notice(
              message: BannerCopy.offline,
              action: widget.onRetry == null ? null : BannerCopy.tryAgain,
              onAction: widget.onRetry,
            ),
        ],
      ),
    );
  }
}

/// Three paper lanterns lifting one after another, over [Motion.waitLoop]:
/// calm, one idea, a short move. It fades in over [Motion.settle] when
/// [shown] turns true. With reduce motion they stand at rest, still in view.
class WaitingSign extends StatefulWidget {
  const WaitingSign({super.key, this.shown = true});

  final bool shown;

  /// The height the lanterns take, lifted or at rest.
  static const height = Sizes.waitLantern + Sizes.waitLift + Space.xxs;

  @override
  State<WaitingSign> createState() => _WaitingSignState();
}

class _WaitingSignState extends State<WaitingSign>
    with SingleTickerProviderStateMixin {
  late final AnimationController _loop = AnimationController(
    vsync: this,
    duration: Motion.waitLoop,
  );
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _sync();
  }

  @override
  void didUpdateWidget(WaitingSign oldWidget) {
    super.didUpdateWidget(oldWidget);
    _sync();
  }

  /// Turning only while it is in view and motion is allowed (an unseen sign
  /// asks for no frames).
  void _sync() {
    final turn = widget.shown && !MediaQuery.disableAnimationsOf(context);
    if (turn && !_loop.isAnimating) {
      unawaited(_loop.repeat());
    } else if (!turn && _loop.isAnimating) {
      _loop.stop();
      _loop.value = 0;
    }
  }

  @override
  void dispose() {
    _loop.dispose();
    super.dispose();
  }

  /// How far lantern [i] is lifted (0 to 1) at the loop's [t]: each rises
  /// and settles in its own third, one after another, so one idea moves at
  /// a time.
  static double lift(int i, double t) {
    final local = (t * 3 - i).clamp(0.0, 1.0);
    return local <= 0 || local >= 1
        ? 0
        : Curves.easeInOut.transform(local < 0.5 ? local * 2 : (1 - local) * 2);
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final ground = context.ground;
    final fill = ground.paper;
    final shadow = ground.elevation.raised.scaled(0.5);
    final radius = BorderRadius.circular(Sizes.waitLantern / 2);
    return AnimatedOpacity(
      opacity: widget.shown ? 1 : 0,
      duration: Motion.within(context, Motion.settle),
      curve: Motion.curve,
      child: ExcludeSemantics(
        child: AnimatedBuilder(
          animation: _loop,
          builder: (context, _) => SizedBox(
            height: WaitingSign.height,
            child: Row(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.end,
              spacing: Sizes.waitGap,
              children: [
                for (var i = 0; i < 3; i++)
                  Transform.translate(
                    offset: Offset(0, -Sizes.waitLift * lift(i, _loop.value)),
                    child: Container(
                      width: Sizes.waitLantern,
                      height: Sizes.waitLantern,
                      decoration: cutPaper(
                        context,
                        fill: fill,
                        radius: radius,
                        elevation: shadow,
                      ).copyWith(shape: BoxShape.rectangle),
                      foregroundDecoration: BoxDecoration(
                        borderRadius: radius,
                        border: Border.all(
                          color: ground.outline,
                          width: skin.shape.stroke,
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
