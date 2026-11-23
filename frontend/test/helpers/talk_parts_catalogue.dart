import 'package:flutter/material.dart';
import 'package:midnight_village/design_system/models/role.dart';
import 'package:midnight_village/design_system/primitives/deck_pile.dart';
import 'package:midnight_village/design_system/primitives/name_tag.dart';
import 'package:midnight_village/design_system/primitives/primary_button.dart';
import 'package:midnight_village/design_system/primitives/sealed_note.dart';
import 'package:midnight_village/design_system/primitives/square_sky.dart';
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
      label: 'Ready to vote',
      detail: '2 of 6 ready',
      onPressed: () {},
    ),
  ),
  PartSample(
    'PrimaryButton',
    PartState.rest,
    (c) => PrimaryButton.on(
      label: 'Ready ✓',
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
      child: SquareSky(secondsLeft: 192, title: 'The village wakes'),
    ),
  ),
];
