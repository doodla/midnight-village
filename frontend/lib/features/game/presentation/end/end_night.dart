import 'dart:async';

import 'package:flutter/widgets.dart';

import '../../../../design_system/layout/space.dart';
import '../../../../design_system/primitives/art_picture.dart';
import '../../../../design_system/primitives/paper_piece.dart';
import '../../../../design_system/skin/dress_style.dart';
import '../../../../design_system/copy/copy.dart';
import '../../../../design_system/skin/art_set.dart';
import '../../../../design_system/skin/skin.dart';
import '../../domain/end_board.dart';
import '../../domain/end_story.dart';
import '../../domain/night_timeline.dart';
import 'end_reveal.dart';

export 'end_night_board.dart';

// What happened, on the board (docs/specs/frontend/end-board.md, section 8):
// the night replayed on the cards where they lie. [EndNight] is which step
// the board shows and the clock of that step's motion; the board's pieces
// read it through [EndNightScope]. The settled board is never rebuilt for the
// night: it is hidden as it is ([NightHides]) and shown again exactly as it
// was, and the night is a layer of its own over it.

/// The night of What happened: off (the settled board), or at one step of
/// [story], with the clock of that step's motion. Step 0 is the deal (every
/// card turns to the face it was dealt); step i is the story's i-th. A
/// player steps through at their own pace: [next] (a tap, a swipe) finishes
/// the motion playing, else plays the next step, and after the last goes
/// back to the result; [back] shows the step before. Nothing advances by
/// itself.
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

  /// The first time only: the cue on the board's lower edge that the board
  /// goes on, until the first tap ([taught] is then told, once).
  bool cue = false;
  VoidCallback? taught;

  void _learned() {
    if (!cue) return;
    cue = false;
    taught?.call();
  }

  int? _step;

  /// The step shown (0: the deal); null when the night is off.
  int? get step => _step;
  bool get on => _step != null;

  /// The deal: the cards turning from the result to the faces dealt.
  bool get opening => _step == 0;

  /// The story's step shown; null at the deal and by day.
  StoryStep? get current {
    final s = story, i = _step;
    if (s == null || i == null || i == 0 || i > s.steps.length) return null;
    return s.steps[i - 1];
  }

  /// The step's line, for the banner: the deal's, or the step's.
  String get line => current?.line ?? StoryCopy.dealt;

  /// The faces before the step shown, and after it.
  StoryFaces get before {
    final i = _step ?? 0;
    return i <= 1 ? story!.dealt : story!.before(i - 1);
  }

  StoryFaces get after => current?.after ?? story!.dealt;

  /// Where each card the night shows is drawn, by its place (a player's
  /// card on the board, a middle card in the foot): what the thread to a
  /// middle card is tied between, and what the tests find.
  GlobalKey placeKey(CardPlace place) =>
      _keys.putIfAbsent(place, GlobalKey.new);
  final _keys = <CardPlace, GlobalKey>{};

  /// Every place given a key so far.
  Iterable<CardPlace> get placed => _keys.keys;

  /// The board as it was last planned (its window's room): what the foot
  /// reads to know whether the step's middle cards are lifted onto the
  /// board or stay in the foot ([nightInFoot]).
  final laidOut = ValueNotifier<EndBoardPlan?>(null);

  /// How far the board's window has scrolled: a thread down to the foot
  /// follows the board.
  final scrolled = ValueNotifier<double>(0);

  /// The night falls: the cards turn to the deal.
  void open() {
    if (story == null) return;
    _step = 0;
    _play();
    notifyListeners();
  }

  void next() {
    if (!on) return;
    _learned();
    if (clock.isAnimating) {
      clock.value = 1;
      return;
    }
    if (_step! >= story!.steps.length) return close();
    _step = _step! + 1;
    _play();
    notifyListeners();
  }

  /// The step before, shown done; before the deal, the result.
  void back() {
    if (!on) return;
    _learned();
    if (_step == 0) return close();
    _step = _step! - 1;
    clock.value = 1;
    notifyListeners();
  }

  /// Back to the result: the settled board, exactly as it was.
  void close() {
    if (!on) return;
    _step = null;
    clock.value = 0;
    notifyListeners();
  }

  void _play() {
    clock.duration = opening ? Motion.scene : Motion.settle + Motion.quick;
    if (cut) {
      clock.value = 1;
    } else {
      unawaited(clock.forward(from: 0));
    }
  }

  double _span(double from, double to) =>
      ((clock.value - from) / (to - from)).clamp(0.0, 1.0);

  /// How far every card has turned from the result to the deal.
  double dealTurn() => opening ? _span(0, 1) : 1;

  /// How much of the step's twine is drawn.
  double drawn() => _span(0, 0.6);

  /// How far the cards the step moved have turned to their new faces.
  double moveTurn() => _span(0.45, 1);

  @override
  void dispose() {
    clock.dispose();
    laidOut.dispose();
    scrolled.dispose();
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

/// The sky at night, over the dawn: a veil of the night's ground over all
/// of it (the moon, under the hills and the roofs, is in the sky's own
/// layers: [NightMoon]). It comes and goes over a scene's length (a cut
/// with reduce motion), and is nothing at all by day.
class NightSky extends StatelessWidget {
  const NightSky({super.key});

  @override
  Widget build(BuildContext context) {
    final night = EndNightScope.maybeOf(context);
    final mood = context.skin.mood;
    return IgnorePointer(
      child: ExcludeSemantics(
        child: AnimatedOpacity(
          opacity: night?.on ?? false ? 1 : 0,
          duration: _sceneOf(context, night),
          child: ColoredBox(
            color: mood.nightBase.withValues(alpha: mood.veilFromAlpha),
          ),
        ),
      ),
    );
  }
}

Duration _sceneOf(BuildContext context, EndNight? night) =>
    night?.cut ?? true ? Duration.zero : Motion.within(context, Motion.scene);

/// The moon at night, between the sky plate and the hills and roofs (the
/// dawn sky's slot): the night's ground laid over the plate and the moon up
/// at the left, where the lantern is not, at the skin's size. Nothing by
/// day.
class NightMoon extends StatelessWidget {
  const NightMoon({super.key});

  @override
  Widget build(BuildContext context) {
    final night = EndNightScope.maybeOf(context);
    final skin = context.skin;
    final mood = skin.mood;
    final scene = skin.art.layeredScene(LayeredSceneId.nightVillage);
    final moon = scene.layers.whereType<SceneLayer>().firstWhere(
      (l) => l.file == 'moon',
    );
    final width = skin.parts.nightMoonWidth;
    return IgnorePointer(
      child: ExcludeSemantics(
        child: AnimatedOpacity(
          opacity: night?.on ?? false ? 1 : 0,
          duration: _sceneOf(context, night),
          child: Stack(
            children: [
              Positioned.fill(
                child: ColoredBox(
                  color: mood.nightBase.withValues(alpha: mood.veilMidAlpha),
                ),
              ),
              Positioned(
                left: skin.parts.nightMoonAt.dx,
                top: skin.parts.nightMoonAt.dy,
                width: width,
                height: width * moon.size.height / moon.size.width,
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

/// The first time only, while the night plays: "Go on" on a small scrap of
/// bone paper on the board's lower edge (the foot's lip), until the first
/// tap. Its middle is where it is put.
class NightCue extends StatelessWidget {
  const NightCue({super.key});

  @override
  Widget build(BuildContext context) {
    final night = EndNightScope.maybeOf(context);
    if (night == null || !night.on || !night.cue) {
      return const SizedBox.shrink();
    }
    return IgnorePointer(
      child: FractionalTranslation(
        translation: const Offset(0, -0.5),
        child: PaperPiece(
          part: PaperPart.scrap,
          id: StoryCopy.goOn,
          child: Padding(
            padding: const EdgeInsets.symmetric(
              horizontal: Space.sm,
              vertical: Space.xxs,
            ),
            child: Text(
              StoryCopy.goOn,
              maxLines: 1,
              style: context.skin.typography.name.copyWith(
                color: PaperPiece.inkOf(context, PaperPart.scrap),
              ),
            ),
          ),
        ),
      ),
    );
  }
}
