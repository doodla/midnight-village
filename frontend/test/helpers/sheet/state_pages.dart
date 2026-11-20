import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:midnight_village/design_system/copy/copy.dart';
import 'package:midnight_village/design_system/faces/face_content.dart';
import 'package:midnight_village/design_system/faces/held_face.dart';
import 'package:midnight_village/design_system/layout/space.dart';
import 'package:midnight_village/design_system/models/role.dart';
import 'package:midnight_village/design_system/primitives/chips.dart';
import 'package:midnight_village/design_system/primitives/count_badge.dart';
import 'package:midnight_village/design_system/primitives/face_down_card.dart';
import 'package:midnight_village/design_system/primitives/paper_card.dart';
import 'package:midnight_village/design_system/primitives/player_row.dart';
import 'package:midnight_village/design_system/primitives/player_token.dart';
import 'package:midnight_village/design_system/primitives/primary_button.dart';
import 'package:midnight_village/design_system/primitives/progress_pips.dart';
import 'package:midnight_village/design_system/primitives/screen_frame.dart';
import 'package:midnight_village/design_system/primitives/secondary_button.dart';
import 'package:midnight_village/design_system/primitives/tag_chip.dart';
import 'package:midnight_village/design_system/skin/art_set.dart';
import 'package:midnight_village/design_system/skin/ground.dart';
import 'package:midnight_village/design_system/skin/skin.dart';
import 'package:midnight_village/design_system/teach/learned_store.dart';
import 'package:midnight_village/design_system/teach/teach_once.dart';

import '../component_sheet.dart';
import 'sheet_data.dart';

// The state pages: primitives in each state, for the sheet's readers (the
// headings here are notes for whoever reads the sheet, not player copy).

/// A state page: [children] down a screen on [ground].
class StatePage extends StatelessWidget {
  const StatePage({super.key, required this.ground, required this.children});

  final GroundKind ground;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) => ScreenFrame(
    ground: ground,
    body: Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: Space.md,
      children: children,
    ),
  );
}

/// A note naming what follows on a state page.
class Note extends StatelessWidget {
  const Note(this.text, {super.key});

  final String text;

  @override
  Widget build(BuildContext context) => Text(
    text,
    style: context.skin.typography.caption.copyWith(
      color: context.ground.quietText,
    ),
  );
}

class ButtonsPage extends StatelessWidget {
  const ButtonsPage({super.key, required this.ground});

  final GroundKind ground;

  @override
  Widget build(BuildContext context) => StatePage(
    ground: ground,
    children: [
      const Note('Primary: ready, large; pressed; busy'),
      PrimaryButton(
        label: JoinCopy.startTable,
        onPressed: () {},
        size: ButtonSize.large,
      ),
      PrimaryButton(
        key: pressedKey,
        label: VoteCopy.lockIn.fill({'name': cleo.name}),
        icon: Icons.lock_outline,
        onPressed: () {},
      ),
      PrimaryButton(
        label: TableCopy.deal.fill({'n': 5}),
        onPressed: () {},
        busy: true,
      ),
      const Note('Waiting; a locked gate; done'),
      const PrimaryButton(label: TableCopy.needPlayers, onPressed: null),
      PrimaryButton.locked(label: CardCopy.ready, onLockedTap: () {}),
      const PrimaryButton.done(label: CommonCopy.readyDone),
      const Note('Secondary: rest, off, paper'),
      Row(
        spacing: Space.smPlus,
        children: [
          Expanded(
            child: SecondaryButton(label: TableCopy.share, onPressed: () {}),
          ),
          const Expanded(
            child: SecondaryButton(label: JoinCopy.joinTable, onPressed: null),
          ),
          SecondaryButton.paper(label: JoinCopy.join, onPressed: () {}),
        ],
      ),
      const Note('Paper, tags, chips, counts'),
      const PaperCard(child: Text(RoleCopy.shared)),
      Wrap(
        spacing: Space.sm,
        runSpacing: Space.sm,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const TagChip(RoleCopy.village),
          TagChip.danger(RoleId.werewolf.displayName),
          const TagChip(RoleCopy.alone, small: true),
          const CountBadge(2),
          const CountBadge(2, size: BadgeSize.large),
          for (final (i, chip) in DeckCopy.chips.indexed)
            PresetChip(label: chip, selected: i == 0, onTap: () {}),
        ],
      ),
    ],
  );
}

class PlayersPage extends StatelessWidget {
  const PlayersPage({super.key, required this.ground});

  final GroundKind ground;

  @override
  Widget build(BuildContext context) => StatePage(
    ground: ground,
    children: [
      const Note('Tokens: all ten, an unknown one, one away'),
      Wrap(
        spacing: Space.smPlus,
        runSpacing: Space.smPlus,
        children: [
          for (final t in TokenId.values) PlayerToken(t),
          const PlayerToken(null),
          const PlayerToken(TokenId.bell, away: true),
        ],
      ),
      const Note('Rows: own, away, a long name'),
      PlayerRow(token: ana.token, name: ana.name, own: true),
      PlayerRow(token: dev.token, name: dev.name, away: true),
      const PlayerRow(token: TokenId.antler, name: 'Florentyna-Bartholomew'),
      const Note('The vote: picked; locked, all alike'),
      PlayerRow(
        token: cleo.token,
        name: cleo.name,
        size: PlayerRowSize.large,
        picked: true,
        onTap: () {},
      ),
      PlayerRow(
        token: ben.token,
        name: ben.name,
        size: PlayerRowSize.large,
        dimmed: true,
        onTap: () {},
      ),
      const Note('The count: voters by name'),
      PlayerRow(
        token: dev.token,
        name: dev.name,
        size: PlayerRowSize.count,
        detail: nameList([ana.name, ben.name, cleo.name]),
        trailing: const Tally(3),
      ),
      ProgressPips(
        done: 2,
        total: 5,
        label: TalkCopy.progress.fill({'d': 2, 'n': 5}),
      ),
    ],
  );
}

/// The teach-once states: the `hold` cue showing on a device that has not
/// learned it, then learned, and a locked gate tapped on a device that has:
/// the cue replays for 3 s.
class GatesPage extends StatelessWidget {
  const GatesPage({super.key, required this.ground});

  final GroundKind ground;

  @override
  Widget build(BuildContext context) => StatePage(
    ground: ground,
    children: [
      for (final (note, learned, key) in [
        ('Not learned: the cue', const <Cue>{}, null),
        ('Learned: the glyph', Cue.values.toSet(), null),
        (
          'Learned, gate tapped: the cue again',
          Cue.values.toSet(),
          replayedGateKey,
        ),
      ]) ...[
        Note(note),
        ProviderScope(
          overrides: learnedOverrides(learned),
          child: _Gate(gateKey: key),
        ),
      ],
    ],
  );
}

/// A card that teaches the hold, and its locked gate.
class _Gate extends StatefulWidget {
  const _Gate({this.gateKey});

  final Key? gateKey;

  @override
  State<_Gate> createState() => _GateState();
}

class _GateState extends State<_Gate> {
  final _replay = CueReplay();

  @override
  void dispose() {
    _replay.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) => Row(
    spacing: Space.lg,
    children: [
      SizedBox(
        width: FaceDownSize.player.mock.width,
        child: TeachOnce(
          cue: Cue.hold,
          replay: _replay,
          builder: (context, teaching) => FaceDownCard(hold: teaching),
        ),
      ),
      Expanded(
        child: PrimaryButton.locked(
          key: widget.gateKey,
          label: CardCopy.ready,
          onLockedTap: _replay.replay,
        ),
      ),
    ],
  );
}

/// Held faces at their one size: the role text (04), and the night's.
class FacesPage extends StatelessWidget {
  const FacesPage({super.key, required this.night});

  /// The night's faces; else the role text's.
  final bool night;

  @override
  Widget build(BuildContext context) => StatePage(
    ground: GroundKind.night,
    children: [
      for (final (content, page)
          in night
              ? [
                  // The Doppelganger's follow-up, and her My night's
                  // window-1 page (game 8).
                  (Viewer.doppelgangerFollowUp.you, 0),
                  (Viewer.doppelganger.myNight, 1),
                ]
              : [
                  (FaceContent.roleText(RoleId.minion), 0),
                  (FaceContent.roleText(RoleId.seer), 0),
                ])
        HeldFace(content: content, page: page),
    ],
  );
}
