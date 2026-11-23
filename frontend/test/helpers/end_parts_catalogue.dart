import 'package:flutter/material.dart';
import 'package:midnight_village/design_system/models/role.dart';
import 'package:midnight_village/design_system/primitives/board_pieces.dart';
import 'package:midnight_village/design_system/primitives/death_mark.dart';
import 'package:midnight_village/design_system/primitives/end_lantern.dart';
import 'package:midnight_village/design_system/primitives/furled_scroll.dart';
import 'package:midnight_village/design_system/primitives/paper_scrap.dart';
import 'package:midnight_village/design_system/primitives/sliced_art.dart';
import 'package:midnight_village/design_system/primitives/twine.dart';
import 'package:midnight_village/design_system/primitives/vote_tag.dart';
import 'package:midnight_village/design_system/primitives/you_seal.dart';
import 'package:midnight_village/design_system/skin/art_set.dart';

import 'parts_catalogue.dart';

/// The end board's parts, one sample each, for the parts page and the kit's
/// tests (they are spread into `partsCatalogue`). The words are the test's own:
/// the screen's are in `copy.dart`.
final List<PartSample> endPartsCatalogue = [
  PartSample(
    'PaperScrap / PaperSlip',
    PartState.rest,
    (c) => PaperScrap(label: 'What happened', onTap: () {}),
  ),
  PartSample(
    'PaperScrap / PaperSlip',
    PartState.locked,
    (c) => PaperScrap(label: 'Back to\nthe result', onTap: () {}),
  ),
  PartSample(
    'PaperScrap / PaperSlip',
    PartState.picked,
    (c) => const PaperSlip(label: 'Dev deals next.'),
  ),
  PartSample(
    'VoteTag',
    PartState.rest,
    (c) => const VoteTag(name: 'Ana', token: TokenId.crow),
  ),
  PartSample(
    'VoteTag',
    PartState.locked,
    (c) => const VoteTag(
      name: 'Maximilianoooooooo',
      token: TokenId.key,
      maxWidth: 170,
    ),
  ),
  PartSample(
    'Twine',
    PartState.rest,
    (c) => SizedBox(
      width: 150,
      height: 70,
      child: Twine(
        route: TwineRoute.between(
          const Rect.fromLTWH(4, 2, 30, 24),
          const Rect.fromLTWH(116, 40, 30, 24),
        ),
      ),
    ),
  ),
  PartSample(
    'Twine',
    PartState.locked,
    (c) => SizedBox(
      width: 150,
      height: 70,
      child: Twine(
        kind: TwineKind.look,
        werewolf: true,
        route: TwineRoute.between(
          const Rect.fromLTWH(4, 2, 30, 24),
          const Rect.fromLTWH(116, 40, 30, 24),
        ),
      ),
    ),
  ),
  PartSample(
    'YouSeal',
    PartState.rest,
    (c) => const YouSeal(token: TokenId.crow, size: 44),
  ),
  PartSample(
    'InkStamp / DeathRibbon',
    PartState.rest,
    (c) => const Padding(
      padding: EdgeInsets.all(14),
      child: InkStamp(label: 'HANGED'),
    ),
  ),
  PartSample(
    'BoardCardBack',
    PartState.rest,
    (c) => const BoardCardBack(
      name: 'Maximilian',
      size: Size(110, 80),
      portraitWidth: 64,
      rect: Rect.fromLTWH(0, 0, 110, 80),
    ),
  ),
  PartSample(
    'FurledScroll',
    PartState.rest,
    (c) => const Padding(
      padding: EdgeInsets.all(8),
      child: FurledScroll(width: 160),
    ),
  ),
  PartSample(
    'InkStamp / DeathRibbon',
    PartState.locked,
    (c) => const SizedBox(width: 60, height: 70, child: _Ribbon()),
  ),
  PartSample(
    'BannerSlice / BoardFrame / BoardRoof',
    PartState.rest,
    (c) => const SizedBox(
      width: 340,
      child: BannerSlice(lines: ['Cleo hanged.', 'You and the village win.']),
    ),
  ),
  PartSample(
    'BannerSlice / BoardFrame / BoardRoof',
    PartState.locked,
    (c) => const SizedBox(
      width: 340,
      child: BannerSlice(
        lines: ['Cleo hanged.', 'You lose to the village.'],
        red: true,
      ),
    ),
  ),
  PartSample(
    'BannerSlice / BoardFrame / BoardRoof',
    PartState.picked,
    (c) => const SizedBox(
      width: 200,
      height: 160,
      child: BoardFrame(child: SizedBox.expand()),
    ),
  ),
  PartSample(
    'BannerSlice / BoardFrame / BoardRoof',
    PartState.focused,
    (c) => const SizedBox(width: 300, child: BoardRoof()),
  ),
  PartSample('EndLantern', PartState.rest, (c) => const EndLantern()),
  PartSample(
    'BoardCard / DealtCard / BoardLight / BoardFoot',
    PartState.rest,
    (c) => SizedBox(
      width: 200,
      height: 120,
      child: Stack(
        children: [
          BoardCard(
            name: 'Ana',
            role: RoleId.seer,
            strip: 'Seer',
            paper: BoardPaper.winner,
            size: const Size(98, 94),
            portraitWidth: 90,
            rect: const Rect.fromLTWH(0, 0, 98, 94),
          ),
          const Positioned(
            left: 110,
            child: BoardCard(
              name: 'Cleo',
              role: RoleId.werewolf,
              strip: 'Werewolf',
              paper: BoardPaper.werewolfLost,
              size: Size(80, 74),
              portraitWidth: 64,
              rect: Rect.fromLTWH(110, 0, 80, 74),
              raised: true,
            ),
          ),
        ],
      ),
    ),
  ),
  PartSample(
    'BoardCard / DealtCard / BoardLight / BoardFoot',
    PartState.picked,
    (c) => const SizedBox(
      width: 200,
      height: 80,
      child: Stack(
        children: [
          BoardLight(
            size: Size(200, 80),
            light: Offset(150, 20),
            pools: [Rect.fromLTWH(10, 10, 60, 60)],
          ),
          Positioned(
            left: 100,
            child: DealtCard(
              role: RoleId.robber,
              size: Size(30, 39),
              rect: Rect.fromLTWH(100, 0, 30, 39),
            ),
          ),
        ],
      ),
    ),
  ),
  PartSample(
    'BoardCard / DealtCard / BoardLight / BoardFoot',
    PartState.focused,
    (c) => const SizedBox(width: 200, height: 70, child: BoardFoot(height: 70)),
  ),
];

class _Ribbon extends StatelessWidget {
  const _Ribbon();

  @override
  Widget build(BuildContext context) =>
      const Align(alignment: Alignment.topRight, child: DeathRibbon(width: 30));
}
