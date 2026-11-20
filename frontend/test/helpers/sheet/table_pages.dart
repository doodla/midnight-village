import 'package:flutter/material.dart';
import 'package:midnight_village/design_system/copy/copy.dart';
import 'package:midnight_village/design_system/layout/space.dart';
import 'package:midnight_village/design_system/models/role.dart';
import 'package:midnight_village/design_system/primitives/chips.dart';
import 'package:midnight_village/design_system/primitives/fit_line.dart';
import 'package:midnight_village/design_system/primitives/panels.dart';
import 'package:midnight_village/design_system/primitives/paper_card.dart';
import 'package:midnight_village/design_system/primitives/player_row.dart';
import 'package:midnight_village/design_system/primitives/primary_button.dart';
import 'package:midnight_village/design_system/primitives/role_card.dart';
import 'package:midnight_village/design_system/primitives/role_sheet_body.dart';
import 'package:midnight_village/design_system/primitives/screen_frame.dart';
import 'package:midnight_village/design_system/primitives/secondary_button.dart';
import 'package:midnight_village/design_system/primitives/sheet_scaffold.dart';
import 'package:midnight_village/design_system/primitives/skin_field.dart';
import 'package:midnight_village/design_system/primitives/world_timer.dart';
import 'package:midnight_village/design_system/skin/ground.dart';
import 'package:midnight_village/design_system/skin/ground_scope.dart';
import 'package:midnight_village/design_system/skin/skin.dart';

import '../painted_text.dart';
import 'sheet_data.dart';

// 01 Join, 02 Table, 03 Deck and 03b the role sheet, to the first-time play
// spec.

/// The table's code, as the server gives it.
const _code = 'K7QX4M';

/// 01: a name first. Both ways in are outlined and of equal weight, locked
/// until a name is typed; "Join a table" gives way to the code and an amber
/// "Join". With [code], a name typed and "Join a table" opened.
class JoinPage extends StatefulWidget {
  const JoinPage({super.key, this.code = false});

  final bool code;

  @override
  State<JoinPage> createState() => _JoinPageState();
}

class _JoinPageState extends State<JoinPage> {
  late final _name = TextEditingController(text: widget.code ? ana.name : '');

  @override
  void dispose() {
    _name.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final type = skin.typography;
    final named = widget.code;
    return ScreenFrame(
      ground: GroundKind.night,
      topArt: skin.art.streetDoor,
      body: Builder(
        builder: (context) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: Space.lgPlus,
          children: [
            FitLine(JoinCopy.title, style: type.heroTitle),
            SkinField.paper(
              controller: _name,
              semanticLabel: JoinCopy.nameHint,
              hint: JoinCopy.nameHint,
            ),
            SecondaryButton(
              label: JoinCopy.startTable,
              onPressed: named ? () {} : null,
              size: ButtonSize.large,
            ),
            if (widget.code)
              Row(
                spacing: Space.smPlus,
                children: [
                  const Expanded(
                    child: SkinField.code(
                      semanticLabel: JoinCopy.codeHint,
                      hint: JoinCopy.codeHint,
                    ),
                  ),
                  PrimaryButton(
                    label: JoinCopy.join,
                    onPressed: () {},
                    size: ButtonSize.compact,
                  ),
                ],
              )
            else
              SecondaryButton(
                label: JoinCopy.joinTable,
                onPressed: null,
                size: ButtonSize.large,
              ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              spacing: Space.xs,
              children: [
                for (final line in [
                  JoinCopy.online.fill({'n': 23}),
                  JoinCopy.lastLost,
                ])
                  Text(
                    line,
                    style: type.lede.copyWith(color: context.ground.text),
                  ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

/// 02: the host's table (guests scan the code) or a guest's ([guest]).
class TablePage extends StatelessWidget {
  const TablePage({super.key, this.guest = false});

  final bool guest;

  @override
  Widget build(BuildContext context) {
    final skin = context.skin;
    final type = skin.typography;
    return ScreenFrame(
      ground: GroundKind.night,
      body: Builder(
        builder: (context) => Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          spacing: Space.md,
          children: [
            if (guest) ...[
              Text(
                TableCopy.hostDeals.fill({'host': ana.name}),
                style: type.screenTitle,
              ),
              Text(
                _code,
                style: type.code.copyWith(color: context.ground.text),
              ),
            ] else ...[
              Text(TableCopy.scan, style: type.screenTitle),
              const _JoinCode(),
              Align(
                alignment: Alignment.center,
                child: SecondaryButton(
                  label: TableCopy.share,
                  onPressed: () {},
                ),
              ),
            ],
            for (final seat in fiveSeats)
              PlayerRow(
                token: seat.token,
                name: seat.name,
                own: seat == (guest ? ben : ana),
                away: seat == dev,
              ),
            if (!guest)
              OutlinePanel(
                onTap: () {},
                semanticLabel: TableCopy.editDeck,
                child: Row(
                  spacing: Space.smPlus,
                  children: [
                    Expanded(child: deckStrip(RoleCardSize.thumbSmall)),
                    Text(
                      TableCopy.editDeck,
                      style: type.action.copyWith(color: context.ground.text),
                    ),
                  ],
                ),
              ),
          ],
        ),
      ),
      actions: [
        if (guest)
          SecondaryButton(label: CommonCopy.leave, onPressed: () {})
        else
          PrimaryButton(
            label: TableCopy.deal.fill({'n': fiveSeats.length}),
            onPressed: () {},
          ),
      ],
    );
  }
}

/// Where the QR code for /join/{code} goes (it is built with the join
/// route, later), with the code printed under it.
class _JoinCode extends StatelessWidget {
  const _JoinCode();

  static const _side = 128.0;

  @override
  Widget build(BuildContext context) => Center(
    child: PaperCard(
      lift: PaperLift.slab,
      child: Builder(
        builder: (context) => Column(
          spacing: Space.xs,
          children: [
            Icon(Icons.qr_code_2, size: _side, color: context.ground.text),
            Text(
              _code,
              style: context.skin.typography.code.copyWith(
                color: context.ground.text,
              ),
            ),
          ],
        ),
      ),
    ),
  );
}

/// Tonight's deck as a strip of thumbnails, which shrink to fit the row.
Widget deckStrip(RoleCardSize size) => Row(
  spacing: size == RoleCardSize.thumbSmall ? Space.sm : Space.smPlus,
  children: [
    for (final MapEntry(key: role, value: count) in deckCounts.entries)
      Flexible(
        child: RoleCard(role: role, size: size, count: count),
      ),
  ],
);

/// 03's body: the chips, the grid of roles, the paces.
class _DeckBody extends StatelessWidget {
  const _DeckBody({this.withPace = true});

  final bool withPace;

  @override
  Widget build(BuildContext context) {
    final type = context.skin.typography;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      spacing: Space.mdPlus,
      children: [
        Align(
          alignment: AlignmentDirectional.centerStart,
          child: FitLine(DeckCopy.headline, style: type.headline),
        ),
        _chips(DeckCopy.chips, selected: 1),
        GridView.count(
          crossAxisCount: 3,
          shrinkWrap: true,
          physics: const NeverScrollableScrollPhysics(),
          mainAxisSpacing: Space.mdPlus,
          crossAxisSpacing: Space.md,
          childAspectRatio: 0.66,
          children: [
            for (final role in deckOrder)
              RoleCard(
                role: role,
                count: deckCounts[role] ?? 0,
                lit: deckCounts.containsKey(role),
                onTap: () {},
                onLongPress: () {},
              ),
          ],
        ),
        if (withPace) ...[
          _chips(DeckCopy.paces, selected: 1),
          // Four tiles that share the row and grow with their text; "Copy"
          // only when the Doppelganger is in the deck (it is not, here).
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              spacing: Space.sm,
              children: [
                for (final (label, seconds) in [
                  (DeckCopy.talk, 300),
                  (DeckCopy.vote, 90),
                  (DeckCopy.night, 30),
                ])
                  Expanded(
                    child: PaceTile(
                      label: label,
                      value: WorldTimer.format(seconds),
                      onTap: () {},
                    ),
                  ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _chips(List<String> labels, {required int selected}) => Wrap(
    spacing: Space.sm,
    runSpacing: Space.sm,
    children: [
      for (final (i, label) in labels.indexed)
        PresetChip(label: label, selected: i == selected, onTap: () {}),
    ],
  );
}

/// 03: the deck stays automatic (a chip) until a card is edited.
class DeckPage extends StatelessWidget {
  const DeckPage({super.key});

  @override
  Widget build(BuildContext context) => ScreenFrame(
    ground: GroundKind.night,
    body: const _DeckBody(),
    actions: [PrimaryButton(label: DeckCopy.useDeck, onPressed: () {})],
  );
}

/// 03b over 03: the role text and "Close".
class RoleSheetPage extends StatelessWidget {
  const RoleSheetPage({super.key});

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      const BehindScrim(
        child: ScreenFrame(
          ground: GroundKind.night,
          body: _DeckBody(withPace: false),
        ),
      ),
      Positioned.fill(child: ColoredBox(color: context.skin.scrim)),
      Align(
        alignment: Alignment.bottomCenter,
        child: GroundScope(
          ground: GroundKind.night,
          child: SheetScaffold(
            actions: [
              const Spacer(),
              PrimaryButton(
                label: RoleSheetCopy.close,
                onPressed: () {},
                size: ButtonSize.compact,
              ),
            ],
            child: const RoleSheetBody(RoleId.troublemaker),
          ),
        ),
      ),
    ],
  );
}
