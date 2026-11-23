import 'dart:async';
import 'dart:math' as math;
import 'dart:ui' show lerpDouble;

import 'package:flutter/widgets.dart';

import '../../../../design_system/layout/space.dart';
import '../../../../design_system/primitives/art_picture.dart';
import '../../../../design_system/primitives/paper_scrap.dart';
import '../../../../design_system/skin/art_set.dart';
import '../../../../design_system/skin/skin.dart';
import '../../domain/end_board_metrics.dart';
import '../../domain/end_story.dart';
import 'end_reveal.dart';

export 'end_night_board.dart';

// What happened, on the board (docs/specs/frontend/end-board.md, section 8):
// the night replayed on the cards where they lie. [EndNight] is which step
// the board shows and the clock of that step's motion; the board's pieces
// read it through [EndNightScope]. The settled board is never rebuilt for the
// night: it is hidden as it is ([NightHides]) and shown again exactly as it
// was, and the night is a layer of its own over it.

/// The night of What happened: off (the settled board), or at one step of
/// [story], with the clock of that step's motion. A player steps through at
/// their own pace: [next] (a tap, a swipe) finishes the motion playing, else
/// plays the next step, and after the last goes back to the result; [back]
/// shows the step before. Nothing advances by itself.
class EndNight extends ChangeNotifier {
  EndNight({required TickerProvider vsync})
    : clock = AnimationController(vsync: vsync);

  /// The motion of the step shown: 0 as it starts, 1 when it is done.
  final AnimationController clock;

  /// The clock as the reveal's pieces read one ([RevealTurn], `revealPaint`).
  late final driver = EndRevealDriver(clock);

  EndStory? story;

  /// Every change is a cut (reduce motion, a screen reader).
  bool cut = false;

  int? _step;

  /// The step shown; null when the night is off.
  int? get step => _step;
  bool get on => _step != null;

  /// The step shown played straight after the cards turned to the deal.
  bool get opening => _opening;
  var _opening = false;

  StoryStep? get current {
    final s = story, i = _step;
    if (s == null || i == null || i >= s.steps.length) return null;
    return s.steps[i];
  }

  /// The faces before the step shown, and after it.
  StoryFaces get before =>
      story!.steps.isEmpty ? story!.dealt : story!.before(_step ?? 0);
  StoryFaces get after => current?.after ?? story!.dealt;

  /// The night falls: the cards turn to the deal and the first step plays.
  void open() {
    if (story == null) return;
    _step = 0;
    _opening = true;
    _play();
    notifyListeners();
  }

  void next() {
    if (!on) return;
    if (clock.isAnimating) {
      clock.value = 1;
      return;
    }
    final last = math.max(0, story!.steps.length - 1);
    if (_step! >= last) return close();
    _step = _step! + 1;
    _opening = false;
    _play();
    notifyListeners();
  }

  /// The step before, shown done; before the first, the result.
  void back() {
    if (!on) return;
    if (_step == 0) return close();
    _step = _step! - 1;
    _opening = false;
    clock.value = 1;
    notifyListeners();
  }

  /// Back to the result: the settled board, exactly as it was.
  void close() {
    if (!on) return;
    _step = null;
    _opening = false;
    clock.value = 0;
    notifyListeners();
  }

  void _play() {
    clock.duration = _opening
        ? Motion.scene + Motion.settle
        : Motion.settle + Motion.quick;
    if (cut) {
      clock.value = 1;
    } else {
      unawaited(clock.forward(from: 0));
    }
  }

  double _span(double from, double to) =>
      ((clock.value - from) / (to - from)).clamp(0.0, 1.0);

  /// How far every card has turned from the result to the deal (opening).
  double dealTurn() => _opening ? _span(0, 0.4) : 1;

  /// How much of the step's twine is drawn.
  double drawn() => _opening ? _span(0.4, 0.8) : _span(0, 0.6);

  /// How far the cards the step moved have turned to their new faces.
  double moveTurn() => _opening ? _span(0.65, 1) : _span(0.45, 1);

  /// How far the step's slips have landed.
  double landed() => _opening ? _span(0.4, 0.75) : _span(0, 0.55);

  @override
  void dispose() {
    clock.dispose();
    super.dispose();
  }
}

/// The night of the board below; its dependents are built again when the
/// step changes (never on a tick of the clock).
class EndNightScope extends InheritedNotifier<EndNight> {
  const EndNightScope({
    super.key,
    required EndNight night,
    required super.child,
  }) : super(notifier: night);

  /// The night, and a rebuild when its step changes.
  static EndNight? maybeOf(BuildContext context) =>
      context.dependOnInheritedWidgetOfExactType<EndNightScope>()?.notifier;

  /// The night, without a rebuild.
  static EndNight? read(BuildContext context) =>
      context.getInheritedWidgetOfExactType<EndNightScope>()?.notifier;
}

/// [child] as it is, hidden while the night plays: not painted and not
/// read out, and kept, so the result comes back exactly as it was.
class NightHides extends StatelessWidget {
  const NightHides({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final night = EndNightScope.maybeOf(context);
    if (night == null) return child;
    return ExcludeSemantics(
      excluding: night.on,
      child: RevealPaint(
        clock: night,
        opacity: () => night.on ? 0 : 1,
        child: child,
      ),
    );
  }
}

/// The moon's place in the sky: up at the left, where the lantern is not.
const _moonLeft = Space.xl;
const _moonTop = Space.sm;
const _moonWidth = 40.0;

/// The sky at night, over the dawn: the night's ground laid over it and the
/// moon up. It comes and goes over a scene's length (a cut with reduce
/// motion), and is nothing at all by day.
class NightSky extends StatelessWidget {
  const NightSky({super.key});

  @override
  Widget build(BuildContext context) {
    final night = EndNightScope.maybeOf(context);
    final skin = context.skin;
    final mood = skin.mood;
    final scene = skin.art.layeredScene(LayeredSceneId.nightVillage);
    final moon = scene.layers.whereType<SceneLayer>().firstWhere(
      (l) => l.file == 'moon',
    );
    final on = night?.on ?? false;
    return IgnorePointer(
      child: ExcludeSemantics(
        child: AnimatedOpacity(
          opacity: on ? 1 : 0,
          duration: night?.cut ?? true
              ? Duration.zero
              : Motion.within(context, Motion.scene),
          child: Stack(
            children: [
              Positioned.fill(
                child: ColoredBox(
                  color: mood.nightBase.withValues(alpha: mood.veilMidAlpha),
                ),
              ),
              Positioned(
                left: _moonLeft,
                top: _moonTop,
                width: _moonWidth,
                height: _moonWidth * moon.size.height / moon.size.width,
                child: ArtPicture(
                  skin.art.layer(LayeredSceneId.nightVillage, moon),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

/// The step's words on one slip pinned to the board's bottom rail, always in
/// the same place, landing as the step plays; read out as each step comes
/// (a live region), and a screen reader's way on to the next step.
class NightCaption extends StatelessWidget {
  const NightCaption({super.key, required this.width});

  /// The board's width: the slip wraps inside it.
  final double width;

  @override
  Widget build(BuildContext context) {
    final night = EndNightScope.maybeOf(context);
    final step = night?.current;
    if (night == null || step == null) return const SizedBox.shrink();
    final slip = PaperSlip(
      label: step.line,
      id: step.number,
      maxLines: 3,
      maxWidth: width - 2 * Space.lg,
    );
    return Semantics(
      liveRegion: true,
      button: true,
      label: step.line,
      onTap: night.next,
      excludeSemantics: true,
      child: revealPaint(
        night.driver,
        opacity: () => math.min(1, night.landed() * 3),
        transform: (size) => about(
          size.center(Offset.zero),
          // The landing's overshoot stops at its own size: its words are never
          // drawn smaller.
          scaled(
            math.max(
              1.0,
              lerpDouble(_slipFrom, 1, Motion.land.transform(night.landed()))!,
            ),
          ),
        ),
        child: slip,
      ),
    );
  }
}

const _slipFrom = 1.3;

/// How much of the board's foot the caption keeps: what a step brings into
/// view stays above it.
const nightCaptionRoom = EndMetrics.lip + PaperScrap.paperHeight + Space.md;
