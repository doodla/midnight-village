@Tags(['golden'])
library;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/components/game/player_circle.dart';
import 'package:midnight_village/design_system/models/player_display.dart';

import '../../../helpers/golden_test_helper.dart';

void main() {
  group('PlayerCircle golden tests', () {
    testWidgets('default state renders correctly', (tester) async {
      final players = [
        const PlayerDisplay(id: 'p1', displayName: 'Alice', isCurrentPlayer: true),
        const PlayerDisplay(id: 'p2', displayName: 'Bob'),
        const PlayerDisplay(id: 'p3', displayName: 'Carol'),
      ];

      await tester.pumpWithGolden(
        Scaffold(
          body: Center(
            child: PlayerCircle(players: players),
          ),
        ),
        'goldens/player_circle_default.png',
      );
    });

    testWidgets('selected state renders correctly', (tester) async {
      final players = [
        const PlayerDisplay(id: 'p1', displayName: 'Alice', isCurrentPlayer: true),
        const PlayerDisplay(id: 'p2', displayName: 'Bob', isSelected: true),
        const PlayerDisplay(id: 'p3', displayName: 'Carol'),
      ];

      await tester.pumpWithGolden(
        Scaffold(
          body: Center(
            child: PlayerCircle(players: players),
          ),
        ),
        'goldens/player_circle_selected.png',
      );
    });

    testWidgets('eliminated state renders correctly', (tester) async {
      final players = [
        const PlayerDisplay(id: 'p1', displayName: 'Alice', isCurrentPlayer: true),
        const PlayerDisplay(
          id: 'p2',
          displayName: 'Bob',
          status: PlayerStatus.eliminated,
        ),
        const PlayerDisplay(id: 'p3', displayName: 'Carol'),
      ];

      await tester.pumpWithGolden(
        Scaffold(
          body: Center(
            child: PlayerCircle(players: players, showStatus: true),
          ),
        ),
        'goldens/player_circle_eliminated.png',
      );
    });
  });
}
