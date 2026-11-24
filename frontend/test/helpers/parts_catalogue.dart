import 'package:flutter/material.dart';
import 'package:midnight_village/design_system/copy/copy.dart';
import 'package:midnight_village/design_system/models/role.dart';
import 'package:midnight_village/design_system/primitives/candle_gauge.dart';
import 'package:midnight_village/design_system/primitives/chips.dart';
import 'package:midnight_village/design_system/primitives/count_badge.dart';
import 'package:midnight_village/design_system/primitives/dots.dart';
import 'package:midnight_village/design_system/primitives/fanned.dart';
import 'package:midnight_village/design_system/primitives/face_down_card.dart';
import 'package:midnight_village/design_system/primitives/icon_action.dart';
import 'package:midnight_village/design_system/primitives/notice.dart';
import 'package:midnight_village/design_system/primitives/panels.dart';
import 'package:midnight_village/design_system/primitives/paper_banner.dart';
import 'package:midnight_village/design_system/primitives/paper_card.dart';
import 'package:midnight_village/design_system/primitives/paper_lantern.dart';
import 'package:midnight_village/design_system/primitives/paper_mark.dart';
import 'package:midnight_village/design_system/primitives/paper_pin.dart';
import 'package:midnight_village/design_system/primitives/paper_piece.dart';
import 'package:midnight_village/design_system/primitives/paper_seal.dart';
import 'package:midnight_village/design_system/primitives/player_row.dart';
import 'package:midnight_village/design_system/primitives/player_token.dart';
import 'package:midnight_village/design_system/primitives/primary_button.dart';
import 'package:midnight_village/design_system/primitives/progress_pips.dart';
import 'package:midnight_village/design_system/primitives/qr_picture.dart';
import 'package:midnight_village/design_system/primitives/role_card.dart';
import 'package:midnight_village/design_system/primitives/role_sheet_body.dart';
import 'package:midnight_village/design_system/primitives/rule.dart';
import 'package:midnight_village/design_system/primitives/scrap_label.dart';
import 'package:midnight_village/design_system/primitives/secondary_button.dart';
import 'package:midnight_village/design_system/primitives/sheet_scaffold.dart';
import 'package:midnight_village/design_system/primitives/skin_field.dart';
import 'package:midnight_village/design_system/primitives/tag_chip.dart';
import 'package:midnight_village/design_system/primitives/text_action.dart';
import 'package:midnight_village/design_system/primitives/text_backing.dart';
import 'package:midnight_village/design_system/primitives/value_stepper.dart';
import 'package:midnight_village/design_system/primitives/you_tag.dart';
import 'package:midnight_village/design_system/primitives/band.dart';
import 'package:midnight_village/design_system/primitives/viewfinder.dart';
import 'package:midnight_village/design_system/primitives/waiting_sign.dart';
import 'package:midnight_village/design_system/primitives/world_timer.dart';
import 'package:midnight_village/design_system/skin/dress_style.dart';
import 'package:midnight_village/design_system/skin/skin.dart';
import 'package:midnight_village/design_system/teach/hold_cue.dart';
import 'package:midnight_village/design_system/faces/held_face.dart';

import 'end_parts_catalogue.dart';
import 'talk_parts_catalogue.dart';
import 'sheet/sheet_data.dart';

/// The states a component is shown in on the parts page.
enum PartState { rest, pressed, picked, locked, focused }

/// One component in one state: the parts page shows it, and the stroke test
/// paints it in paper dress.
class PartSample {
  const PartSample(this.entry, this.state, this.build);

  /// The inventory entry's name (`dress_inventory.dart`).
  final String entry;
  final PartState state;
  final WidgetBuilder build;
}

Widget _field(BuildContext context) => SizedBox(
  width: 220,
  child: SkinField.paper(hint: 'Your name', semanticLabel: 'Name'),
);

/// Every component of the inventory, in every state it has. Built from the
/// primitives alone; the recorded game gives the one card face.
final List<PartSample> partsCatalogue = [
  // ---- Actions
  for (final state in PartState.values)
    PartSample(
      'PrimaryButton',
      state,
      (c) => switch (state) {
        PartState.locked => PrimaryButton.locked(
          label: Words.forTest('Ready'),
          onLockedTap: () {},
        ),
        PartState.picked => const PrimaryButton.done(
          label: Words.forTest('Locked'),
        ),
        _ => PrimaryButton(
          label: Words.forTest('Start the game'),
          onPressed: () {},
        ),
      },
    ),
  PartSample(
    'PrimaryButton',
    PartState.locked,
    (c) => PrimaryButton.locked(
      label: Words.forTest('Choose a card'),
      onLockedTap: () {},
      slot: true,
    ),
  ),
  PartSample(
    'PrimaryButton',
    PartState.locked,
    (c) => const PrimaryButton.waiting(
      label: Words.forTest('Need 3 players'),
      reason: 'Waiting',
    ),
  ),
  PartSample(
    'PrimaryButton',
    PartState.rest,
    (c) => PrimaryButton.quiet(
      label: Words.forTest('Ready to vote'),
      onPressed: () {},
    ),
  ),
  for (final state in [
    PartState.rest,
    PartState.pressed,
    PartState.locked,
    PartState.focused,
  ])
    PartSample(
      'SecondaryButton',
      state,
      (c) => switch (state) {
        PartState.locked => const SecondaryButton.waiting(
          label: Words.forTest('Take out'),
          reason: 'Waiting',
        ),
        _ => SecondaryButton(
          label: Words.forTest('Take out'),
          onPressed: () {},
        ),
      },
    ),
  PartSample(
    'TextAction',
    PartState.rest,
    (c) => TextAction(label: 'Leave', onPressed: () {}),
  ),
  const PartSample('TextAction', PartState.locked, _inertTextAction),
  for (final state in [
    PartState.rest,
    PartState.pressed,
    PartState.focused,
    PartState.locked,
  ])
    PartSample(
      'IconAction',
      state,
      (c) => IconAction(
        icon: Icons.ios_share,
        label: 'Share',
        onPressed: state == PartState.locked ? null : () {},
      ),
    ),
  for (final state in [PartState.rest, PartState.picked, PartState.locked])
    PartSample(
      'GlyphButton',
      state,
      (c) => GlyphButton(
        glyph: (ink) => Icon(Icons.flashlight_on, color: ink),
        semanticLabel: 'Torch',
        onPressed: state == PartState.locked ? null : () {},
        lit: state == PartState.picked,
        size: ButtonSize.regular,
      ),
    ),
  for (final state in [PartState.rest, PartState.pressed, PartState.locked])
    PartSample(
      'ValueStepper',
      state,
      // On the panel it always lies on (a well is paper sunk into a panel).
      (c) => OutlinePanel(
        child: ValueStepper(
          value: '5',
          widest: '10',
          lowerLabel: 'Fewer',
          higherLabel: 'More',
          onLower: state == PartState.locked ? null : () {},
          onHigher: () {},
        ),
      ),
    ),
  PartSample(
    'HoldRing',
    PartState.rest,
    (c) => const HoldCue(teaching: true, size: 96),
  ),
  PartSample(
    'HoldToReveal',
    PartState.rest,
    (c) => const SizedBox(
      width: 78,
      height: 106,
      child: FaceDownCard(size: FaceDownSize.player),
    ),
  ),
  // ---- Chips, tags, badges
  for (final state in [PartState.rest, PartState.picked, PartState.pressed])
    PartSample(
      'PresetChip',
      state,
      (c) => PresetChip(
        label: 'Classic',
        selected: state == PartState.picked,
        onTap: () {},
      ),
    ),
  PartSample('TagChip', PartState.rest, (c) => const TagChip('Village')),
  PartSample(
    'TagChip',
    PartState.rest,
    (c) => const TagChip.danger('Werewolf', small: true),
  ),
  PartSample(
    'YouTag',
    PartState.rest,
    // As it is used: on the bone slip of a row.
    (c) => PaperPiece(
      part: PaperPart.scrap,
      id: 'row',
      child: Padding(
        padding: const EdgeInsets.all(8),
        child: YouTag(ink: c.skin.paper.text),
      ),
    ),
  ),
  PartSample('CountBadge', PartState.rest, (c) => const CountBadge(2)),
  PartSample(
    'SeatDot / SlotMark',
    PartState.rest,
    // Seats lie in the players' panel (wells in it); the slots on the page.
    (c) => Row(
      mainAxisSize: MainAxisSize.min,
      spacing: 6,
      children: [
        OutlinePanel(
          child: Row(
            mainAxisSize: MainAxisSize.min,
            spacing: 6,
            children: [
              for (final taken in [true, false])
                SeatDot(
                  taken: taken,
                  side: 18,
                  ink: c.ground.text,
                  outline: c.ground.outline,
                  stroke: 2,
                ),
            ],
          ),
        ),
        for (final filled in [true, false])
          SlotMark(
            filled: filled,
            size: const Size(10, 16),
            ink: c.ground.text,
            outline: c.ground.outline,
          ),
      ],
    ),
  ),
  PartSample(
    'ProgressPips',
    PartState.rest,
    (c) => const SizedBox(
      width: 220,
      child: ProgressPips(done: 2, total: 5, label: '2 of 5 ready'),
    ),
  ),
  PartSample('ScrapLabel', PartState.rest, (c) => const ScrapLabel('Edit')),
  // ---- Rows, slips, cards
  for (final state in [PartState.rest, PartState.picked, PartState.pressed])
    PartSample(
      'PlayerRow',
      state,
      (c) => SizedBox(
        width: 220,
        child: PlayerRow(
          token: null,
          name: 'Bartholomew',
          own: state == PartState.rest,
          picked: state == PartState.picked,
          onTap: () {},
        ),
      ),
    ),
  PartSample('PlayerToken', PartState.rest, (c) => const PlayerToken(null)),
  for (final state in [PartState.rest, PartState.locked])
    PartSample(
      'RoleCard',
      state,
      (c) => RoleCard(
        role: RoleId.seer,
        size: RoleCardSize.thumbSmall,
        count: 2,
        lit: state == PartState.rest,
        onTap: () {},
      ),
    ),
  PartSample(
    'Fanned',
    PartState.rest,
    (c) => SizedBox(
      width: 160,
      child: Row(
        spacing: 6,
        children: [
          for (final (i, role) in [
            RoleId.seer,
            RoleId.robber,
            RoleId.drunk,
          ].indexed)
            Expanded(
              child: Fanned(
                index: i,
                count: 3,
                child: RoleCard(
                  role: role,
                  size: RoleCardSize.thumbSmall,
                  count: 1,
                  onTap: () {},
                ),
              ),
            ),
        ],
      ),
    ),
  ),
  for (final state in [PartState.rest, PartState.picked, PartState.locked])
    PartSample(
      'FaceDownCard',
      state,
      (c) => SizedBox(
        width: 78,
        height: 170,
        child: FaceDownCard(
          size: FaceDownSize.player,
          ownerName: 'Ben',
          selected: state == PartState.picked,
          dimmed: state == PartState.locked,
        ),
      ),
    ),
  PartSample(
    'PaperCard',
    PartState.rest,
    (c) => SizedBox(
      width: 200,
      child: PaperCard(
        pinned: true,
        id: #parts,
        lift: PaperLift.slab,
        child: Text(
          'A pinned notice',
          style: TextStyle(color: c.skin.paper.text),
        ),
      ),
    ),
  ),
  PartSample(
    'HeldFace',
    PartState.rest,
    (c) => SizedBox(
      width: 240,
      height: 340,
      child: HeldFace(content: Viewer.seer.card, page: 0),
    ),
  ),
  PartSample(
    'RoleSheetBody',
    PartState.rest,
    (c) => const SizedBox(width: 280, child: RoleSheetBody(RoleId.seer)),
  ),
  PartSample(
    'PeekBox',
    PartState.rest,
    (c) => const SizedBox(
      width: 260,
      child: PeekBox(title: 'My night', teaching: false),
    ),
  ),
  for (final state in [PartState.rest, PartState.pressed])
    PartSample(
      'OutlinePanel',
      state,
      (c) => SizedBox(
        width: 220,
        child: OutlinePanel(
          onTap: () {},
          semanticLabel: 'Edit',
          child: const Text('Classic, talk 5 min'),
        ),
      ),
    ),
  // ---- Notices, fields, sheets
  PartSample(
    'Notice',
    PartState.rest,
    (c) => SizedBox(
      width: 260,
      child: Notice(message: 'Not sent.', action: 'Try again', onAction: () {}),
    ),
  ),
  PartSample(
    'QrPicture',
    PartState.rest,
    (c) => PaperCard(
      child: QrPicture(data: 'https://midnight.example/join/ABCDEF', side: 100),
    ),
  ),
  const PartSample('SkinField', PartState.rest, _field),
  PartSample(
    'SheetScaffold',
    PartState.rest,
    (c) => SizedBox(
      width: 300,
      child: SheetScaffold(
        actions: [
          const Spacer(),
          SheetClose(label: Words.forTest('Close'), onPressed: () {}),
        ],
        child: const Text('Words on a sheet'),
      ),
    ),
  ),
  PartSample(
    'Rule / SideRule',
    PartState.rest,
    (c) => SizedBox(
      width: 200,
      child: Column(
        children: [
          const Rule(),
          SideRule(
            color: c.ground.hairline,
            width: 2,
            padding: const EdgeInsets.all(8),
            child: const Text('A line of the night'),
          ),
        ],
      ),
    ),
  ),
  // ---- Banners, timer, marks
  PartSample(
    'PaperBanner',
    PartState.rest,
    (c) => PaperBanner(id: #parts, child: (c) => const Text('Look at cards')),
  ),
  PartSample(
    'TextBacking',
    PartState.rest,
    (c) => const TextBacking(child: Text('Words over the village')),
  ),
  PartSample(
    'TimerBand',
    PartState.rest,
    (c) => SizedBox(
      width: 260,
      child: TimerBand.bar(secondsLeft: 40, remaining: 0.6, title: 'Talk'),
    ),
  ),
  PartSample(
    'WorldTimer',
    PartState.rest,
    (c) => const WorldTimer.candle(secondsLeft: 14),
  ),
  PartSample('PaperMark', PartState.rest, (c) => const PaperMark(size: 30)),
  PartSample(
    'PaperSeal',
    PartState.rest,
    (c) => const PaperSeal(size: 34, lands: false),
  ),
  PartSample(
    'PaperPin',
    PartState.rest,
    (c) => PaperPin(ink: c.skin.paper.text, size: 12),
  ),
  // ---- Waiting
  PartSample(
    'Pending / BusyMark',
    PartState.rest,
    (c) => const BusyMark(size: 24),
  ),
  PartSample('Waiting', PartState.rest, (c) => const WaitingSign()),
  PartSample(
    'PaperLantern',
    PartState.rest,
    (c) => const PaperLantern(width: 20, lit: 1),
  ),
  PartSample(
    'CandleGauge',
    PartState.rest,
    (c) =>
        const SizedBox(width: 60, child: CandleGauge(share: 0.6, height: 90)),
  ),
  // ---- Scanner
  PartSample(
    'Viewfinder / ShutteredWindow',
    PartState.rest,
    (c) => const SizedBox(
      width: 150,
      height: 150,
      child: Viewfinder(child: ShutteredWindow()),
    ),
  ),
  // ---- The end board
  ...endPartsCatalogue,
  ...talkPartsCatalogue,
];

Widget _inertTextAction(BuildContext context) =>
    const TextAction(label: CommonCopy.leave, onPressed: null);

/// A sample as the parts page and the stroke test lay it down: forced into its
/// state where the state is the paper's own (pressed, focused).
Widget sampleOf(PartSample sample) => Builder(
  builder: (context) => PaperStateOverride(
    pressed: sample.state == PartState.pressed,
    focused: sample.state == PartState.focused,
    child: Builder(builder: sample.build),
  ),
);
