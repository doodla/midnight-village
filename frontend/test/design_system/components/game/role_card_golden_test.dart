// OLD LOOK: delete when 04 Your card, 06 Night action, 07 What you saw, 10 The count and 11 Results are rebuilt
@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/components/game/role_card.dart';
import 'package:midnight_village/design_system/models/role.dart';

import '../../../helpers/golden_test_helper.dart';

void main() {
  group('RoleCard golden tests', () {
    testWidgets('werewolf role renders correctly', (tester) async {
      await tester.pumpWithGolden(
        const Scaffold(
          body: Center(child: RoleCard(roleId: RoleId.werewolf)),
        ),
        'goldens/role_card_werewolf.png',
      );
    });

    testWidgets('villager role renders correctly', (tester) async {
      await tester.pumpWithGolden(
        const Scaffold(
          body: Center(child: RoleCard(roleId: RoleId.villager)),
        ),
        'goldens/role_card_villager.png',
      );
    });

    testWidgets('face-down state renders correctly', (tester) async {
      await tester.pumpWithGolden(
        const Scaffold(body: Center(child: RoleCard(roleId: null))),
        'goldens/role_card_face_down.png',
      );
    });
  });
}
