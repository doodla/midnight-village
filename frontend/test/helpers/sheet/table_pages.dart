import 'package:flutter/material.dart';
import 'package:midnight_village/design_system/copy/copy.dart';
import 'package:midnight_village/design_system/layout/space.dart';
import 'package:midnight_village/design_system/models/role.dart';
import 'package:midnight_village/design_system/primitives/primary_button.dart';
import 'package:midnight_village/design_system/primitives/role_card.dart';
import 'package:midnight_village/design_system/primitives/role_sheet_body.dart';
import 'package:midnight_village/design_system/primitives/sheet_scaffold.dart';
import 'package:midnight_village/design_system/skin/ground.dart';
import 'package:midnight_village/design_system/skin/ground_scope.dart';
import 'package:midnight_village/design_system/skin/skin.dart';
import 'package:midnight_village/features/lobby/domain/lobby_state.dart';
import 'package:midnight_village/features/lobby/presentation/at_table_screen.dart';
import 'package:midnight_village/features/lobby/presentation/deck_screen.dart';
import 'package:midnight_village/features/lobby/presentation/home_numbers.dart';
import 'package:midnight_village/features/lobby/presentation/join_screen.dart';

import '../contract/from_sample.dart';
import '../painted_text.dart';
import '../table_setup.dart';
import 'sheet_data.dart';

// 01 Join, 02 Table, 03 Deck and 03b, to the first-time play spec: the
// app's own views (features/lobby) drawn from recorded lobby bodies, with
// states no lobby body carries yet (a dropped phone, dimmed with no words).

/// Ana's table of five, as the server recorded it (the Classic chip).
LobbyState _table() => FromSample.lobby(v2Lobby('detail_auto_deck_5'));

/// The table's join link, as the app makes it.
Uri _link(LobbyState lobby) =>
    joinLink(Uri.parse('https://midnight.example'), lobby.code);

/// 01: a name first. Both ways in are outlined and of equal weight, locked
/// until a name is typed; "Join a table" gives way to the code and an amber
/// "Join". With [code], a name typed and "Join a table" opened.
class JoinPage extends StatelessWidget {
  const JoinPage({super.key, this.code = false});

  final bool code;

  @override
  Widget build(BuildContext context) => JoinView(
    name: code ? ana.name : '',
    openCode: code,
    online: 23,
    lastWon: false,
    onStart: (_) {},
    onJoin: (_, _) {},
  );
}

/// 02: the host's table (guests scan the code) or a guest's ([guest]); Dev's
/// phone has dropped.
class TablePage extends StatelessWidget {
  const TablePage({super.key, this.guest = false});

  final bool guest;

  @override
  Widget build(BuildContext context) {
    final lobby = _table();
    final viewer = lobby.players[guest ? 1 : 0].id;
    return AtTableView(
      lobby: lobby,
      viewerId: viewer,
      link: _link(lobby),
      away: {lobby.players[3].id},
      onShare: (_) {},
      onEditDeck: () {},
      onDeal: () {},
      onLeave: () {},
    );
  }
}

/// Tonight's deck (game 7's, or [deck]) as a strip of thumbnails, which
/// shrink to fit the row.
Widget deckStrip(RoleCardSize size, [Map<RoleId, int>? deck]) => Row(
  spacing: size == RoleCardSize.thumbSmall ? Space.sm : Space.smPlus,
  children: [
    for (final MapEntry(key: role, value: count)
        in (deck ?? deckCounts).entries)
      Flexible(
        child: RoleCard(role: role, size: size, count: count),
      ),
  ],
);

/// 03 with the grid open on game 7's deck (eight cards for five).
Widget _deck() => DeckView(
  lobby: _table(),
  editing: deckCounts,
  onChip: (_) {},
  onPace: (_) {},
  onUse: (_) {},
);

/// 03: the chips, the grid of roles, the paces.
class DeckPage extends StatelessWidget {
  const DeckPage({super.key});

  @override
  Widget build(BuildContext context) => _deck();
}

/// 03b over 03: the role text and "Close".
class RoleSheetPage extends StatelessWidget {
  const RoleSheetPage({super.key});

  @override
  Widget build(BuildContext context) => Stack(
    children: [
      BehindScrim(child: _deck()),
      Positioned.fill(child: ColoredBox(color: context.skin.scrim)),
      Align(
        alignment: Alignment.bottomCenter,
        child: GroundScope(
          ground: GroundKind.night,
          child: SheetScaffold(
            actions: [
              const Spacer(),
              PrimaryButton.quiet(
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
