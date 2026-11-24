import 'package:flutter/material.dart';

import '../../../../design_system/copy/copy.dart';
import '../../../../design_system/primitives/fit_line.dart';
import '../../../../design_system/primitives/screen_frame.dart';
import '../../../../design_system/primitives/sliced_art.dart';
import '../../../../design_system/primitives/square_sky.dart';
import '../../../../design_system/skin/dress.dart';
import '../../../../design_system/primitives/waiting_sign.dart';
import '../../../../design_system/skin/art_set.dart';
import '../../../../design_system/skin/ground.dart';
import '../../../../design_system/skin/skin.dart';

// The frames a game screen has while its `/me/` is not here (issue 10): each
// is the screen's own frame (ground, header, headline), so what arrives
// lands on a screen already there, with the one waiting body ([Waiting]) where
// the screen's content will be. The shell crossfades them into the screen.

/// A game screen the table names with no game to draw it from (the screen
/// table never says so): the night's ground and the wait.
class GameWait extends StatelessWidget {
  const GameWait({super.key, required this.failing, required this.onRetry});

  final bool failing;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => ScreenFrame(
    ground: GroundKind.night,
    body: Align(
      alignment: Alignment.topCenter,
      child: Waiting(failing: failing, onRetry: onRetry, centred: true),
    ),
  );
}

/// Where the lanterns hang on a screen whose header is the night's village
/// laid as a backdrop (04 and the end board's wait): from the picture's lower
/// edge, measured from the top of the body.
const double hangsFromVillage = 322;

/// 04 while its `/me/` loads: the frame the card is laid in, the headline
/// and, where the card will be, the wait.
class CardWait extends StatelessWidget {
  const CardWait({super.key, required this.failing, required this.onRetry});

  final bool failing;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => ScreenFrame(
    ground: GroundKind.night,
    topScene: LayeredSceneId.nightVillage,
    topArtLayout: TopArtLayout.backdrop,
    fitsHeight: true,
    body: Stack(
      children: [
        Align(
          alignment: Alignment.topLeft,
          child: Semantics(
            header: true,
            child: FitLine(
              CardCopy.headline,
              style: context.skin.typography.screenTitle,
            ),
          ),
        ),
        // Hung from the village's lower edge, where the card will be.
        Positioned(
          top: hangsFromVillage,
          left: 0,
          right: 0,
          child: Waiting(failing: failing, onRetry: onRetry, centred: true),
        ),
      ],
    ),
  );
}

/// 08 while its `/me/` loads: the frame the talk is laid in, the sky with its
/// dotted path and the headline, no number yet and no sun: where the talk is
/// is not known until `/me/` says, and a sun drawn at the start would leave
/// as the real one arrived (a player who opens the app mid-talk). The wait
/// is where the card and "Ready to vote" will be.
class TalkWait extends StatelessWidget {
  const TalkWait({super.key, required this.failing, required this.onRetry});

  final bool failing;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => ScreenFrame(
    ground: GroundKind.night,
    dress: Dress.paper,
    bleed: true,
    topSlot: const SquareSky(secondsLeft: null, title: TalkCopy.headline),
    fitsHeight: true,
    minBodyHeight: context.skin.parts.squareLeastBody,
    // On the board, where the square will be.
    body: BoardFrame(
      child: Align(
        alignment: Alignment.topCenter,
        child: Waiting(failing: failing, onRetry: onRetry, centred: true),
      ),
    ),
  );
}

/// 09 while its `/me/` loads: the vote's sky with no number yet, and the
/// wait on the board, where the slips will be.
class VoteWait extends StatelessWidget {
  const VoteWait({super.key, required this.failing, required this.onRetry});

  final bool failing;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) => ScreenFrame(
    ground: GroundKind.night,
    dress: Dress.paper,
    bleed: true,
    topSlot: const SquareSky(
      secondsLeft: null,
      title: VoteCopy.headline,
      clock: SkyClock.vote,
    ),
    fitsHeight: true,
    minBodyHeight: context.skin.parts.squareLeastBody,
    body: BoardFrame(
      child: Align(
        alignment: Alignment.topCenter,
        child: Waiting(failing: failing, onRetry: onRetry, centred: true),
      ),
    ),
  );
}

/// The end board before the results have loaded: the night's village as the
/// header and the wait ([Waiting]: the lanterns, a plain line when it is
/// slow, "One moment" while the fetch is failing; it is made again by itself
/// until it succeeds), so the board arrives into a place.
class EndWaiting extends StatelessWidget {
  const EndWaiting({super.key, required this.failing});

  final bool failing;

  @override
  Widget build(BuildContext context) => ScreenFrame(
    ground: GroundKind.night,
    topScene: LayeredSceneId.nightVillage,
    topArtLayout: TopArtLayout.backdrop,
    fitsHeight: true,
    // Hung from the picture's lower edge.
    body: Stack(
      children: [
        Positioned(
          top: hangsFromVillage,
          left: 0,
          right: 0,
          child: Waiting(failing: failing, centred: true),
        ),
      ],
    ),
  );
}
