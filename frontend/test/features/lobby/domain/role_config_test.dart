import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/models/role.dart';
import 'package:midnight_village/features/lobby/domain/role_config.dart';

void main() {
  group('RoleConfig', () {
    group('stepSize', () {
      test('returns 2 for Mason', () {
        expect(RoleConfig.stepSize(RoleId.mason), 2);
      });

      test('returns 1 for all non-Mason roles', () {
        for (final role in RoleId.values) {
          if (role == RoleId.mason) continue;
          expect(
            RoleConfig.stepSize(role),
            1,
            reason: '${role.name} step size',
          );
        }
      });
    });

    group('maxCount', () {
      test('returns 3 for Villager', () {
        expect(RoleConfig.maxCount(RoleId.villager), 3);
      });

      test('returns 2 for Werewolf', () {
        expect(RoleConfig.maxCount(RoleId.werewolf), 2);
      });

      test('returns 2 for Mason', () {
        expect(RoleConfig.maxCount(RoleId.mason), 2);
      });

      test('returns 1 for all other roles', () {
        final multipleRoles = {RoleId.villager, RoleId.werewolf, RoleId.mason};
        for (final role in RoleId.values) {
          if (multipleRoles.contains(role)) continue;
          expect(
            RoleConfig.maxCount(role),
            1,
            reason: '${role.name} max count',
          );
        }
      });
    });

    group('presetsForPlayerCount', () {
      test('returns presets for 3 players', () {
        final presets = RoleConfig.presetsForPlayerCount(3);
        expect(presets, isNotEmpty);
        expect(presets.containsKey('Starter'), isTrue);
      });

      test('returns presets for 5 players with three difficulty levels', () {
        final presets = RoleConfig.presetsForPlayerCount(5);
        expect(presets.length, 3);
        expect(presets.containsKey('Starter'), isTrue);
        expect(presets.containsKey('Intermediate'), isTrue);
        expect(presets.containsKey('Advanced'), isTrue);
      });

      test('every preset holds a card for each player and three more', () {
        // The recommended setups' own size (the server checks any deck).
        for (var count = 3; count <= 10; count++) {
          final presets = RoleConfig.presetsForPlayerCount(count);
          for (final entry in presets.entries) {
            expect(
              entry.value.values.fold(0, (a, b) => a + b),
              count + 3,
              reason: '${entry.key} preset for $count players',
            );
          }
        }
      });

      test('returns empty map for invalid player count', () {
        expect(RoleConfig.presetsForPlayerCount(2), isEmpty);
        expect(RoleConfig.presetsForPlayerCount(11), isEmpty);
      });

      test('5-player Intermediate matches recommended setup', () {
        final presets = RoleConfig.presetsForPlayerCount(5);
        final intermediate = presets['Intermediate']!;
        expect(intermediate[RoleId.werewolf], 2);
        expect(intermediate[RoleId.seer], 1);
        expect(intermediate[RoleId.robber], 1);
        expect(intermediate[RoleId.troublemaker], 1);
        expect(intermediate[RoleId.drunk], 1);
        expect(intermediate[RoleId.insomniac], 1);
        expect(intermediate[RoleId.villager], 1);
      });

      test('6-player Full Info includes Masons', () {
        final presets = RoleConfig.presetsForPlayerCount(6);
        final fullInfo = presets['Full Info']!;
        expect(fullInfo[RoleId.mason], 2);
      });
    });
  });
}
