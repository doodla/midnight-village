// Example: widget testing a screen part built from the skin's primitives.
//
// Pattern: pumpSkinned (test/helpers/pump_skinned.dart) puts a widget in a
// skin's theme, on a ground (night, day or paper), as a ScreenFrame would.
// Loop over skinsUnderTest so the test holds in every skin of the registry,
// and read values through the skin (context.skin, context.ground, Space),
// never literals: a test that pins "#e3a13a" or "56 px" breaks the day a skin
// changes, and says nothing about whether the part works.
//
// To adapt for your part:
//   1. Build it from primitives (lib/design_system/primitives/).
//   2. Pump it with pumpSkinned, on the ground its screen has.
//   3. Find it by text or semantics, as a player (or a screen reader) would.
//   4. Test each state that matters: enabled, disabled, busy, picked.

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/primitives/player_row.dart';
import 'package:midnight_village/design_system/primitives/primary_button.dart';
import 'package:midnight_village/design_system/skin/art_set.dart';
import 'package:midnight_village/design_system/skin/ground.dart';

import '../../helpers/pump_skinned.dart';

/// A small part of the vote screen (S09): the rows to pick from and the
/// button that locks the pick in.
class _VoteChoice extends StatefulWidget {
  const _VoteChoice({required this.onLockIn});

  final ValueChanged<String> onLockIn;

  @override
  State<_VoteChoice> createState() => _VoteChoiceState();
}

class _VoteChoiceState extends State<_VoteChoice> {
  String? _picked;

  @override
  Widget build(BuildContext context) => Column(
    mainAxisSize: MainAxisSize.min,
    children: [
      for (final (token, name) in [
        (TokenId.key, 'Ben'),
        (TokenId.moth, 'Cleo'),
      ])
        PlayerRow(
          token: token,
          name: name,
          size: PlayerRowSize.large,
          picked: _picked == name,
          onTap: () => setState(() => _picked = name),
        ),
      if (_picked case final picked?)
        PrimaryButton(
          label: Words.forTest('Lock in $picked'),
          onPressed: () => widget.onLockIn(picked),
        )
      else
        const PrimaryButton.waiting(
          label: Words.forTest('Pick a player'),
          reason: 'Pick a player first',
        ),
    ],
  );
}

void main() {
  for (final MapEntry(key: skinName, value: skin) in skinsUnderTest.entries) {
    group(skinName, () {
      testWidgets('nothing can be locked in until a player is picked', (
        tester,
      ) async {
        final lockedIn = <String>[];
        await pumpSkinned(
          tester,
          skin: skin,
          ground: GroundKind.day,
          SizedBox(width: 340, child: _VoteChoice(onLockIn: lockedIn.add)),
        );

        await tester.tap(find.text('Pick a player'));
        expect(lockedIn, isEmpty);

        await tester.tap(find.text('Cleo'));
        await tester.pump();
        await tester.tap(find.text('Lock in Cleo'));
        expect(lockedIn, ['Cleo']);
      });

      testWidgets('the pick is read out as selected', (tester) async {
        final semantics = tester.ensureSemantics();
        await pumpSkinned(
          tester,
          skin: skin,
          ground: GroundKind.day,
          SizedBox(width: 340, child: _VoteChoice(onLockIn: (_) {})),
        );
        await tester.tap(find.text('Ben'));
        await tester.pump();

        expect(
          tester.getSemantics(find.widgetWithText(PlayerRow, 'Ben')),
          containsSemantics(isButton: true, isSelected: true),
        );
        semantics.dispose();
      });
    });
  }
}
