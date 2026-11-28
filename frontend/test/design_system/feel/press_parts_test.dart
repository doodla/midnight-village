import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:midnight_village/design_system/faces/face_content.dart';
import 'package:midnight_village/design_system/models/role.dart';
import 'package:midnight_village/design_system/primitives/face_down_card.dart';
import 'package:midnight_village/design_system/primitives/hold_to_reveal.dart';
import 'package:midnight_village/design_system/primitives/icon_action.dart';
import 'package:midnight_village/design_system/primitives/paper_scrap.dart';
import 'package:midnight_village/design_system/primitives/primary_button.dart';
import 'package:midnight_village/design_system/primitives/secondary_button.dart';
import 'package:midnight_village/design_system/primitives/text_action.dart';

import 'press_parts_harness.dart';

// Press piece 1's parts: the buttons, the scraps, the icon and text actions
// and your card on 04. The checks are press_parts_harness.dart's; the rest
// of the kit's tappable parts are in press_parts_board_test.dart. Each
// part's layers at rest are origin/main's from before it pressed through
// `Pressable` (read off 862770c9).

Words _w(String text) => Words.forTest(text);

final _parts = [
  for (final paper in [false, true]) ...[
    PressPart(
      'primary, ready',
      root: PrimaryButton,
      (tap) => PrimaryButton(label: _w('Deal the cards'), onPressed: tap),
      paper: paper,
    ),
    PressPart(
      'primary, locked',
      root: PrimaryButton,
      (tap) => PrimaryButton.locked(label: _w('Ready'), onLockedTap: tap),
      paper: paper,
    ),
    PressPart(
      'primary, waiting',
      root: PrimaryButton,
      (_) => const PrimaryButton.waiting(
        label: Words.forTest('Pick a name'),
        reason: 'Pick first',
      ),
      paper: paper,
      commits: false,
    ),
    PressPart(
      'secondary',
      root: SecondaryButton,
      (tap) => SecondaryButton(label: _w('Do nothing'), onPressed: tap),
      paper: paper,
    ),
    PressPart(
      'icon action',
      root: IconAction,
      (tap) =>
          IconAction(icon: Icons.ios_share, label: 'Share', onPressed: tap),
      paper: paper,
    ),
    PressPart(
      'text action',
      root: TextAction,
      (tap) => TextAction(label: 'Leave', onPressed: tap),
      paper: paper,
      // Its dim was an `AnimatedOpacity` on main, a layer at full ink too.
      restLayers: const [RenderAnimatedOpacity],
    ),
    PressPart(
      'scrap',
      root: PaperScrap,
      (tap) => PaperScrap(label: _w('Edit deck'), onTap: tap),
      paper: paper,
    ),
    PressPart(
      'your card (04)',
      root: HoldToReveal,
      (_) => HoldToReveal(
        inPlace: true,
        target: 'Your card',
        face: FaceContent.roleText(RoleId.seer),
        cover: const FaceDownCard(
          size: FaceDownSize.hero,
          cardWidth: 200,
          cardHeight: 266,
        ),
      ),
      paper: paper,
      commits: false,
      // The turn's back and its face, the card's own art, and the ring.
      restLayers: const [
        RenderRepaintBoundary,
        RenderRepaintBoundary,
        RenderRepaintBoundary,
        RenderAnimatedOpacity,
      ],
    ),
  ],
];

void main() => pressPartTests(_parts);
