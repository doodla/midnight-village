import 'package:flutter/widgets.dart';

import '../layout/space.dart';
import '../primitives/art_picture.dart';
import '../primitives/paper_piece.dart';
import '../primitives/paper_pin.dart';
import '../primitives/screen_frame.dart';
import '../primitives/story_card.dart';
import '../primitives/twine.dart';
import '../skin/dress_style.dart';
import '../skin/skin.dart';
import '../skin/skin_tilt.dart';
import 'night_story.dart';
import 'story_plan.dart';

/// A [NightStory] drawn: its cards from the top, the threads between them,
/// and its one sentence on a pinned slip under them (names in the names'
/// face, the sentence wrapping, never cut). The cards are as large as lets
/// the whole fit the room; where even the smallest do not (a short phone,
/// large text) it scrolls. A screen reader hears the sentence, then every
/// card ([NightStory.spoken]).
class NightStoryView extends StatefulWidget {
  const NightStoryView({super.key, required this.story});

  final NightStory story;

  @override
  State<NightStoryView> createState() => _NightStoryViewState();
}

class _NightStoryViewState extends State<NightStoryView> {
  /// What the plan was laid out for: the story (by value), the room, the
  /// text scale and the skin. Anything else (a clock's tick above it) is
  /// not a reason to lay the story out again.
  ({NightStory story, Size room, TextScaler scaler, Skin skin})? _laidFor;
  StoryPlan? _plan;

  StoryPlan _planIn(BuildContext context, Size room) {
    final key = (
      story: widget.story,
      room: room,
      scaler: MediaQuery.textScalerOf(context),
      skin: context.skin,
    );
    if (_laidFor != key) {
      _plan = StoryPlan.of(context, widget.story, room);
      _laidFor = key;
    }
    return _plan!;
  }

  @override
  Widget build(BuildContext context) => Semantics(
    container: true,
    liveRegion: true,
    label: widget.story.spoken,
    child: ExcludeSemantics(
      // Its own layer: nothing above it repaints the picture.
      child: RepaintBoundary(
        child: LayoutBuilder(
          builder: (context, box) {
            final plan = _planIn(context, box.biggest);
            final picture = _picture(context, plan);
            return plan.fits ? picture : FadingScroll(child: picture);
          },
        ),
      ),
    ),
  );

  Widget _picture(BuildContext context, StoryPlan plan) {
    final skin = context.skin;
    final ink = PaperPiece.inkOf(context, PaperPart.scrap);
    return SizedBox(
      width: plan.size.width,
      height: plan.size.height,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          if (plan.scene case final scene?)
            Positioned.fromRect(
              rect: scene,
              child: ClipRRect(
                borderRadius: BorderRadius.circular(skin.shape.radiusTiny),
                // Its moon and roofs, the rooftop wolf left out of the cut.
                child: Transform.scale(
                  scale: StoryMetrics.sceneZoom,
                  alignment: StoryMetrics.sceneFocus,
                  child: ArtPicture(skin.art.sleepingVillage),
                ),
              ),
            ),
          for (final (ref, rect) in plan.cards)
            Positioned.fromRect(
              rect: rect,
              child: Transform.rotate(
                angle: skin.tilt.angle(
                  Tilt.seededRow(widget.story.cardAt(ref).label),
                ),
                child: StoryCardFace(
                  label: widget.story.cardAt(ref).label,
                  role: widget.story.cardAt(ref).role,
                  width: rect.width,
                  windowHeight: plan.window,
                  headerHeight: plan.headers[ref.row],
                  stripHeight: plan.strip,
                ),
              ),
            ),
          for (final (route, kind, head) in plan.threads)
            Positioned.fill(
              child: Twine(route: route, kind: kind, head: head),
            ),
          Positioned.fromRect(
            rect: plan.slip,
            child: PaperPiece(
              part: PaperPart.scrap,
              id: ('story', widget.story.line.text),
              child: Stack(
                clipBehavior: Clip.none,
                alignment: Alignment.topCenter,
                children: [
                  Padding(
                    padding: StoryPlan.slipPadding,
                    // Laid out exactly as the plan measured it (no inherited
                    // style), so it wraps where the plan said.
                    child: Center(
                      child: RichText(
                        text: StoryPlan.sentence(context, widget.story, ink),
                        textAlign: TextAlign.center,
                        textScaler: MediaQuery.textScalerOf(context),
                      ),
                    ),
                  ),
                  Positioned(
                    top: -Space.xxs,
                    child: PaperPin(ink: ink),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}
