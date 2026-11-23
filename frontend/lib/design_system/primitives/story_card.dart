import 'package:flutter/widgets.dart';

import '../models/role.dart';
import '../skin/card_back_scope.dart';
import '../skin/dress.dart';
import '../skin/skin.dart';
import '../skin/werewolf_portrait.dart';
import 'art_picture.dart';
import 'fit_line.dart';
import 'paper_light.dart';

/// A card of a night's picture story (08's My night, held): a tab with whose
/// it is ("You", a name, "Left", "Now") in the name face, never cut (it
/// wraps between words, the card as tall as it needs), then the portrait of
/// the role it showed with the role's name on a strip at its foot, or, face
/// down ([role] null), the game's card back. Bone paper, the Werewolf
/// team's red for a face-up card of that team, the card back's dark rim
/// for one face down. Plain, it is its words. It says nothing to a screen
/// reader: the story says the whole picture at once.
class StoryCardFace extends StatelessWidget {
  const StoryCardFace({
    super.key,
    required this.label,
    required this.role,
    required this.width,
    required this.windowHeight,
    required this.headerHeight,
    required this.stripHeight,
  });

  final String label;

  /// The role shown; null: face down.
  final RoleId? role;

  /// The card's width; the window is [inset] in from each side.
  final double width;
  final double windowHeight;
  final double headerHeight;
  final double stripHeight;

  /// The card's paper round the window.
  static const inset = 4.0;

  /// The tab's words are this far in from the card's sides.
  static const tabPad = 6.0;

  /// The card's height for a window and its tab and strip.
  static double heightOf(double window, double header, double strip) =>
      header + window + strip;

  bool get _red => role?.team == TeamId.werewolf;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final type = skin.typography;
    final parts = skin.parts;
    final up = role;
    if (!context.dress.isPaper) {
      return ExcludeSemantics(
        child: Text(
          up == null ? label : '$label · ${up.displayName}',
          style: type.name.copyWith(color: context.ground.text),
        ),
      );
    }
    final fill = up == null
        ? parts.cardRim
        : _red
        ? parts.werewolfLostPaper
        : parts.winnerPaper;
    final ink = up == null || _red ? parts.onTeamTag : skin.paper.text;
    final picture = up == null
        ? ArtPicture(
            context.cardBack,
            inset: CardBackScope.of(context).frameInset,
          )
        : ArtPicture(context.roleArt(up));
    return ExcludeSemantics(
      child: DecoratedBox(
        decoration: ShapeDecoration(
          color: fill,
          shadows: context.ground.elevation.card.boxShadowsLeaning(
            PaperLight.of(context),
          ),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(skin.shape.radiusTiny),
          ),
        ),
        child: SizedBox(
          width: width,
          height: heightOf(windowHeight, headerHeight, stripHeight),
          child: Column(
            children: [
              SizedBox(
                height: headerHeight,
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: tabPad),
                  child: Center(
                    // Wrapped between words, else set smaller: never
                    // broken inside a word, never cut.
                    child: FitWords(
                      label,
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      style: type.name.copyWith(color: ink),
                    ),
                  ),
                ),
              ),
              Padding(
                padding: const EdgeInsets.symmetric(horizontal: inset),
                child: SizedBox(
                  width: width - 2 * inset,
                  height: up == null
                      ? windowHeight + stripHeight - inset
                      : windowHeight,
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(skin.shape.radiusTiny),
                    child: picture,
                  ),
                ),
              ),
              if (up != null)
                SizedBox(
                  height: stripHeight,
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: inset),
                    child: Center(
                      child: FitLine(
                        up.displayName,
                        style: type.tag.copyWith(color: ink),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}
