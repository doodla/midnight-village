import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/models/role.dart';
import 'package:midnight_village/design_system/primitives/chips.dart';
import 'package:midnight_village/design_system/primitives/deck_pile.dart';
import 'package:midnight_village/design_system/primitives/face_down_card.dart';
import 'package:midnight_village/design_system/primitives/panels.dart';
import 'package:midnight_village/design_system/primitives/player_row.dart';
import 'package:midnight_village/design_system/primitives/role_card.dart';
import 'package:midnight_village/design_system/primitives/value_stepper.dart';
import 'package:midnight_village/design_system/primitives/viewfinder.dart';
import 'package:midnight_village/design_system/primitives/vote_slip.dart';
import 'package:midnight_village/design_system/skin/art_set.dart';
import 'package:midnight_village/design_system/skin/ground.dart';

import 'press_parts_harness.dart';

// Press piece 2's parts: the rest of the kit's tappable primitives (a vote's
// row and slip, a preset chip, the deck on 08, a stepper's sign, the
// table's panel, a role card and its minus, the scan glyph, and a card on the
// night board). The checks are press_parts_harness.dart's. Each part's
// layers at rest are origin/main's from before it pressed through
// `Pressable` (read off 36340426).

/// A role card in the deck builder's grid, room for its name under it.
Widget _gridCard(VoidCallback tap) => SizedBox(
  width: 100,
  child: RoleCard(
    role: RoleId.seer,
    count: 2,
    onTap: tap,
    onRemove: tap,
    removeLabel: 'Take one out',
  ),
);

final _parts = [
  for (final paper in [false, true]) ...[
    PressPart(
      'player row',
      (tap) => SizedBox(
        width: 320,
        child: PlayerRow(
          token: TokenId.crow,
          name: 'Ada Lovelace',
          size: PlayerRowSize.large,
          onTap: tap,
        ),
      ),
      root: PlayerRow,
      paper: paper,
      ground: GroundKind.day,
      restLayers: const [RenderAnimatedOpacity, RenderOpacity],
    ),
    PressPart(
      'vote slip',
      (tap) => SizedBox(
        width: 320,
        child: VoteSlip(
          token: TokenId.moth,
          name: 'Grace',
          size: PlayerRowSize.large,
          onTap: tap,
        ),
      ),
      root: VoteSlip,
      paper: paper,
      ground: GroundKind.day,
      restLayers: const [RenderAnimatedOpacity, RenderOpacity],
    ),
    PressPart(
      'preset chip',
      (tap) => PresetChip(label: 'Classic', selected: false, onTap: tap),
      root: PresetChip,
      paper: paper,
      ground: GroundKind.paper,
    ),
    PressPart(
      'preset chip, selected',
      (tap) => PresetChip(label: 'Simple', selected: true, onTap: tap),
      root: PresetChip,
      paper: paper,
      ground: GroundKind.paper,
      // The paper mark on its corner.
      restLayers: [if (paper) RenderRepaintBoundary],
    ),
    PressPart(
      'deck pile',
      (tap) => DeckPile(
        role: RoleId.villager,
        count: 3,
        label: '3 Villagers',
        portraitWidth: 72,
        stripHeight: 24,
        onOpen: tap,
      ),
      root: DeckPile,
      paper: paper,
      ground: GroundKind.day,
    ),
    PressPart(
      'stepper sign',
      (tap) => ValueStepper(
        value: '5',
        widest: '10',
        lowerLabel: 'Fewer',
        higherLabel: 'More',
        onLower: tap,
        onHigher: tap,
      ),
      root: ValueStepper,
      paper: paper,
      ground: GroundKind.paper,
      target: () => find.bySemanticsLabel('More'),
    ),
    PressPart(
      'outline panel',
      (tap) => SizedBox(
        width: 320,
        child: OutlinePanel(
          onTap: tap,
          semanticLabel: 'Edit',
          child: const SizedBox(height: 64),
        ),
      ),
      root: OutlinePanel,
      paper: paper,
      ground: GroundKind.paper,
    ),
    PressPart(
      'role card, in the grid',
      _gridCard,
      root: RoleCard,
      paper: paper,
      ground: GroundKind.paper,
      restLayers: [RenderAnimatedOpacity, if (paper) RenderRepaintBoundary],
    ),
    PressPart(
      'role card, its minus',
      _gridCard,
      root: RoleCard,
      paper: paper,
      ground: GroundKind.paper,
      restLayers: [RenderAnimatedOpacity, if (paper) RenderRepaintBoundary],
      target: () => find.bySemanticsLabel('Take one out'),
    ),
    PressPart(
      'role card, a thumbnail',
      (tap) => RoleCard(
        role: RoleId.werewolf,
        size: RoleCardSize.thumbSmall,
        count: 2,
        onTap: tap,
        onLongPress: tap,
      ),
      root: RoleCard,
      paper: paper,
      ground: GroundKind.paper,
      restLayers: const [RenderAnimatedOpacity],
    ),
    PressPart(
      'scan glyph',
      (tap) => GlyphButton(
        glyph: (ink) => Icon(Icons.qr_code, color: ink),
        semanticLabel: 'Scan',
        onPressed: tap,
      ),
      root: GlyphButton,
      paper: paper,
      ground: GroundKind.paper,
    ),
    PressPart(
      'night board card',
      (tap) => FaceDownCard(
        size: FaceDownSize.board,
        cardWidth: 96,
        owner: TokenId.bell,
        ownerName: 'Ada',
        semanticLabel: 'Ada',
        onTap: tap,
      ),
      root: FaceDownCard,
      paper: paper,
      // The card's own layer, its picture's, and its dim.
      restLayers: const [
        RenderRepaintBoundary,
        RenderRepaintBoundary,
        RenderAnimatedOpacity,
        RenderOpacity,
      ],
    ),
    PressPart(
      'night board centre card',
      (tap) => FaceDownCard(
        size: FaceDownSize.board,
        cardWidth: 80,
        caption: 'Left',
        semanticLabel: 'Left',
        onTap: tap,
      ),
      root: FaceDownCard,
      paper: paper,
      restLayers: const [
        RenderRepaintBoundary,
        RenderRepaintBoundary,
        RenderAnimatedOpacity,
      ],
    ),
  ],
];

void main() => pressPartTests(_parts);
