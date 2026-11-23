// The end board's parts page: every part of piece 1 of the end board on the
// dawn ground, the lantern as the one light. The cards are stand-ins (a paper
// piece with a name and a portrait: the real card is piece 2's); everything
// else is the part itself.
import 'package:flutter/material.dart';
import 'package:midnight_village/design_system/models/role.dart';
import 'package:midnight_village/design_system/primitives/art_picture.dart';
import 'package:midnight_village/design_system/primitives/death_mark.dart';
import 'package:midnight_village/design_system/primitives/end_lantern.dart';
import 'package:midnight_village/design_system/primitives/mood.dart';
import 'package:midnight_village/design_system/primitives/one_light.dart';
import 'package:midnight_village/design_system/primitives/paper_pin.dart';
import 'package:midnight_village/design_system/primitives/paper_piece.dart';
import 'package:midnight_village/design_system/primitives/paper_scrap.dart';
import 'package:midnight_village/design_system/primitives/screen_frame.dart';
import 'package:midnight_village/design_system/primitives/sliced_art.dart';
import 'package:midnight_village/design_system/primitives/twine.dart';
import 'package:midnight_village/design_system/primitives/vote_tag.dart';
import 'package:midnight_village/design_system/primitives/you_seal.dart';
import 'package:midnight_village/design_system/skin/art_set.dart';
import 'package:midnight_village/design_system/skin/dress.dart';
import 'package:midnight_village/design_system/skin/dress_style.dart';
import 'package:midnight_village/design_system/skin/end_art.dart';
import 'package:midnight_village/design_system/skin/ground.dart';
import 'package:midnight_village/design_system/skin/skin.dart';

/// The page: a phone-wide column on the dawn, the lantern lighting it.
Widget endPartsPage() => ScreenFrame(
  ground: GroundKind.night,
  dress: Dress.paper,
  mood: MoodKind.dawn,
  moodLight: MoodLight.high,
  body: Builder(
    builder: (context) {
      final caption = context.skin.typography.caption.copyWith(
        color: context.ground.text,
      );
      Widget titled(String words, Widget child) => Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 6,
        children: [
          Text(words, style: caption),
          child,
        ],
      );
      return Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 18,
        children: [
          titled(
            'BannerSlice: bone, one and two lines; red; three lines',
            const Column(
              spacing: 8,
              children: [
                BannerSlice(lines: ['Cleo hanged.']),
                BannerSlice(
                  lines: ['Cleo hanged.', 'You and the village win.'],
                ),
                BannerSlice(
                  red: true,
                  lines: ['Cleo hanged.', 'You lose to the village.'],
                ),
                BannerSlice(
                  lines: [
                    'Maximilian, Rosa Maria and Cleo hanged.',
                    'You lose to',
                    'the Werewolves.',
                  ],
                  red: true,
                ),
              ],
            ),
          ),
          titled(
            'BoardRoof, BoardFrame (nine-slice), OneLight (the lantern), '
            'PaperScrap, VoteTag, Twine, YouSeal, DeathRibbon, InkStamp '
            '(cards are stand-ins)',
            const _Board(),
          ),
          titled(
            'PaperScrap (the paper 40, the touch 48; two lines 48), '
            'PaperSlip',
            Wrap(
              spacing: 16,
              runSpacing: 6,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                PaperScrap(label: 'What happened', onTap: () {}),
                PaperScrap(label: 'Back to\nthe result', onTap: () {}),
                PaperScrap(label: 'Edit deck', onTap: () {}, sends: true),
                const PaperSlip(label: 'Dev deals next.'),
              ],
            ),
          ),
          titled(
            'VoteTag: a short name, a long one, 20 letters in a narrow room',
            const Wrap(
              spacing: 12,
              runSpacing: 8,
              children: [
                VoteTag(name: 'Ana', token: TokenId.moth),
                VoteTag(name: 'Maximilian', token: TokenId.key),
                VoteTag(
                  name: 'Maximilianoooooooooo',
                  token: TokenId.scythe,
                  maxWidth: 200,
                ),
              ],
            ),
          ),
          titled(
            'Twine: a move (solid), a look (gapped), the Werewolf team (red)',
            const _Twines(),
          ),
          titled(
            'BoardFrame at three sizes, one corner',
            const Wrap(
              spacing: 12,
              children: [
                SizedBox(
                  width: 96,
                  height: 80,
                  child: BoardFrame(child: SizedBox.expand()),
                ),
                SizedBox(
                  width: 140,
                  height: 140,
                  child: BoardFrame(child: SizedBox.expand()),
                ),
                SizedBox(
                  width: 120,
                  height: 200,
                  child: BoardFrame(child: SizedBox.expand()),
                ),
              ],
            ),
          ),
        ],
      );
    },
  ),
);

/// The board: roof, frame, felt, the lantern, stand-in cards lit by it, and the
/// parts hung on them.
class _Board extends StatelessWidget {
  const _Board();

  static const _size = Size(358, 520);
  static const _frame = 19.0;

  @override
  Widget build(BuildContext context) {
    // Everything inside is in the board's coordinates (the felt's top left).
    final lantern = Rect.fromLTWH(
      _size.width - _frame * 2 - EndArt.lanternSize.width - 4,
      -2,
      EndArt.lanternSize.width,
      EndArt.lanternSize.height,
    );
    final light = OneLight.lantern(lantern);
    final cards = <_Stand>[
      const _Stand('Ana', RoleId.villager, Rect.fromLTWH(24, 22, 104, 92)),
      const _Stand('Dev', RoleId.troublemaker, Rect.fromLTWH(150, 20, 104, 92)),
      const _Stand('Cleo', RoleId.werewolf, Rect.fromLTWH(28, 250, 84, 74)),
      const _Stand('Ben', RoleId.werewolf, Rect.fromLTWH(178, 268, 84, 74)),
    ];
    final pin = cards[2].rect.bottomLeft + const Offset(8, -6);
    return SizedBox(
      width: _size.width,
      height: _size.height + 30,
      child: Column(
        children: [
          const BoardRoof(width: 358),
          Expanded(
            child: BoardFrame(
              child: OneLightScope(
                light: light,
                child: Stack(
                  clipBehavior: Clip.none,
                  children: [
                    Positioned.fromRect(
                      rect: lantern,
                      child: const EndLantern(),
                    ),
                    for (final card in cards) card.build(context, light),
                    // Ana's seal, on the card's right edge.
                    Positioned(
                      left: cards[0].rect.right - 14,
                      top: cards[0].rect.top + cards[0].rect.height * 0.44,
                      child: const YouSeal(token: TokenId.moth),
                    ),
                    // Cleo hanged: the ribbon on her top right corner.
                    Positioned.fromRect(
                      rect: DeathMark.ribbonRect(cards[2].rect, 64),
                      child: const DeathRibbon(width: 24),
                    ),
                    // The Hunter's pick: red thread between Dev and Ben.
                    Positioned.fill(
                      child: Twine(
                        werewolf: true,
                        route: TwineRoute.between(
                          cards[1].rect,
                          cards[3].rect,
                          avoid: [cards[1].rect, cards[3].rect],
                        ),
                      ),
                    ),
                    // Cleo's votes: a pin, a twine and three tags.
                    Positioned.fill(
                      child: Twine(
                        route: TwineRoute(
                          pin,
                          pin + const Offset(-10, 52),
                          pin + const Offset(0, 100),
                        ),
                      ),
                    ),
                    Positioned(
                      left: pin.dx - 5,
                      top: pin.dy - 5,
                      child: LitAt(
                        rect: Rect.fromLTWH(pin.dx, pin.dy, 10, 10),
                        child: PaperPin(ink: context.skin.paper.text, size: 10),
                      ),
                    ),
                    for (final (i, voter) in const [
                      ('Ana', TokenId.moth),
                      ('Dev', TokenId.scythe),
                      ('Maximilian', TokenId.key),
                    ].indexed)
                      Positioned(
                        left: pin.dx - 14 - (i == 2 ? 6 : 0),
                        top: pin.dy + 10 + i * 24,
                        child: LitAt(
                          rect: Rect.fromLTWH(
                            pin.dx,
                            pin.dy + 10 + i * 24,
                            120,
                            28,
                          ),
                          child: VoteTag(name: voter.$1, token: voter.$2),
                        ),
                      ),
                    // The slam frame's stamp, on Ben.
                    Positioned(
                      left: cards[3].rect.left + 6,
                      top: cards[3].rect.top + 38,
                      child: const InkStamp(label: 'HANGED'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// A stand-in for a card: a paper piece lit from the board's light, with a
/// name over a portrait. (The real one is piece 2's.)
class _Stand {
  const _Stand(this.name, this.role, this.rect);

  final String name;
  final RoleId role;
  final Rect rect;

  Widget build(BuildContext context, OneLight light) {
    final skin = context.skin;
    final red = role == RoleId.werewolf;
    return Positioned.fromRect(
      rect: rect,
      child: LitAt(
        rect: rect,
        child: PaperPiece(
          part: PaperPart.scrap,
          id: name,
          fill: red ? skin.parts.werewolfTag : null,
          child: Padding(
            padding: const EdgeInsets.all(5),
            child: Column(
              children: [
                Text(
                  name,
                  style: skin.typography.name.copyWith(
                    color: red ? skin.parts.onTeamTag : skin.paper.text,
                  ),
                ),
                const SizedBox(height: 3),
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(2),
                    child: SizedBox.expand(
                      child: ArtPicture(skin.art.role(role)),
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

/// The three kinds of twine, each between two small blocks.
class _Twines extends StatelessWidget {
  const _Twines();

  @override
  Widget build(BuildContext context) {
    Widget one(TwineKind kind, bool werewolf) => SizedBox(
      width: 110,
      height: 80,
      child: Stack(
        children: [
          Positioned.fill(
            child: Twine(
              kind: kind,
              werewolf: werewolf,
              route: TwineRoute.between(
                const Rect.fromLTWH(2, 2, 24, 20),
                const Rect.fromLTWH(84, 56, 24, 20),
              ),
            ),
          ),
          for (final at in const [Offset(2, 2), Offset(84, 56)])
            Positioned(
              left: at.dx,
              top: at.dy,
              child: SizedBox(
                width: 24,
                height: 20,
                child: PaperPiece(
                  part: PaperPart.scrap,
                  id: at,
                  child: const SizedBox.expand(),
                ),
              ),
            ),
        ],
      ),
    );
    return Wrap(
      spacing: 14,
      children: [
        one(TwineKind.move, false),
        one(TwineKind.look, false),
        one(TwineKind.look, true),
      ],
    );
  }
}
