import 'package:flutter/material.dart';
import 'package:midnight_village/design_system/models/role.dart';
import 'package:midnight_village/design_system/primitives/deck_pile.dart';
import 'package:midnight_village/design_system/primitives/name_tag.dart';
import 'package:midnight_village/design_system/primitives/primary_button.dart';
import 'package:midnight_village/design_system/primitives/sealed_note.dart';
import 'package:midnight_village/design_system/primitives/square_foot.dart';
import 'package:midnight_village/design_system/primitives/square_sky.dart';
import 'package:midnight_village/design_system/primitives/story_card.dart';
import 'package:midnight_village/design_system/primitives/twine.dart';
import 'package:midnight_village/design_system/primitives/vote_slip.dart';
import 'package:midnight_village/design_system/skin/art_set.dart';

import 'parts_catalogue.dart';

/// The square's parts (08), one sample each, for the parts page and the
/// kit's tests (spread into `partsCatalogue`). The words are the test's own:
/// the screen's are in `copy.dart`.
final List<PartSample> talkPartsCatalogue = [
  PartSample(
    'PrimaryButton',
    PartState.rest,
    (c) => PrimaryButton(
      label: Words.forTest('Ready to vote'),
      detail: '2 of 6 ready',
      onPressed: () {},
    ),
  ),
  PartSample(
    'PrimaryButton',
    PartState.rest,
    (c) => PrimaryButton.on(
      label: Words.forTest('Ready ✓'),
      detail: '3 of 6 ready',
      onPressed: () {},
    ),
  ),
  PartSample(
    'NameTag',
    PartState.rest,
    (c) => const NameTag(name: 'Ana', token: TokenId.crow),
  ),
  PartSample(
    'NameTag',
    PartState.picked,
    (c) => const NameTag(name: 'Rosa Maria', token: TokenId.key, you: true),
  ),
  // The vote's board (09) shares the square's parts.
  PartSample(
    'VoteSlip',
    PartState.rest,
    (c) => VoteSlip(token: TokenId.hare, name: 'Ben', onTap: () {}),
  ),
  PartSample(
    'VoteSlip',
    PartState.picked,
    (c) => VoteSlip(
      token: TokenId.spindle,
      name: 'Cleo',
      picked: true,
      onTap: () {},
    ),
  ),
  PartSample(
    'VoteSlip',
    PartState.picked,
    (c) => const VoteSlip(
      token: TokenId.spindle,
      name: 'Cleo',
      picked: true,
      sealed: true,
    ),
  ),
  PartSample(
    'SquareFoot',
    PartState.rest,
    (c) => SizedBox(
      height: 120,
      child: SquareFoot(
        action: PrimaryButton(
          label: Words.forTest('Lock in Cleo'),
          detail: '1 of 5 locked',
          onPressed: () {},
        ),
      ),
    ),
  ),
  PartSample(
    'DeckPile',
    PartState.rest,
    (c) => DeckPile(
      role: RoleId.villager,
      count: 3,
      label: '3 Villagers',
      portraitWidth: 64,
      stripHeight: 17,
      onOpen: () {},
    ),
  ),
  PartSample(
    'DeckPile',
    PartState.locked,
    (c) => const DeckPile(
      role: RoleId.werewolf,
      count: 2,
      label: '2 Werewolves',
      portraitWidth: 64,
      stripHeight: 17,
    ),
  ),
  PartSample(
    'SealedNote',
    PartState.rest,
    (c) => const SealedNote(label: 'My night', token: TokenId.crow),
  ),
  PartSample(
    'SealedNote',
    PartState.pressed,
    (c) =>
        const SealedNote(label: 'My night', token: TokenId.crow, pressed: true),
  ),
  PartSample(
    'SquareSky',
    PartState.rest,
    (c) => const SizedBox(
      width: 340,
      child: SquareSky(
        countdown: Countdown.held(192),
        title: 'The village wakes',
      ),
    ),
  ),
  // My night held: a story's cards and its threads with heads.
  PartSample(
    'StoryCardFace',
    PartState.rest,
    (c) => const StoryCardFace(
      label: 'You',
      role: RoleId.seer,
      width: 96,
      windowHeight: 96,
      headerHeight: 22,
      stripHeight: 18,
    ),
  ),
  PartSample(
    'StoryCardFace',
    PartState.picked,
    (c) => const StoryCardFace(
      label: 'Rosa Maria',
      role: RoleId.werewolf,
      width: 96,
      windowHeight: 96,
      headerHeight: 22,
      stripHeight: 18,
    ),
  ),
  PartSample(
    'StoryCardFace',
    PartState.locked,
    (c) => const StoryCardFace(
      label: 'Left',
      role: null,
      width: 96,
      windowHeight: 96,
      headerHeight: 22,
      stripHeight: 18,
    ),
  ),
  PartSample(
    'Twine',
    PartState.picked,
    (c) => const SizedBox(
      width: 150,
      height: 70,
      child: Twine(
        kind: TwineKind.look,
        head: true,
        route: TwineRoute(Offset(10, 10), Offset(75, 20), Offset(140, 60)),
      ),
    ),
  ),
  PartSample(
    'Twine',
    PartState.pressed,
    (c) => const SizedBox(
      width: 150,
      height: 70,
      child: Twine(
        head: true,
        route: TwineRoute(Offset(10, 60), Offset(75, 0), Offset(140, 60)),
      ),
    ),
  ),
];
