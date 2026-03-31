import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/models/role.dart';
import 'package:midnight_village/features/lobby/domain/role_config.dart';

void main() {
  group('RoleConfig', () {
    group('isValid', () {
      test('returns true when total cards equals playerCount + 3', () {
        // 3 players need 6 cards
        final roles = {
          RoleId.werewolf: 2,
          RoleId.seer: 1,
          RoleId.robber: 1,
          RoleId.troublemaker: 1,
          RoleId.villager: 1,
        };
        expect(RoleConfig.isValid(roles, 3), isTrue);
      });

      test('returns false when total cards does not equal playerCount + 3', () {
        // 3 players need 6 cards, but only 5 provided
        final roles = {
          RoleId.werewolf: 2,
          RoleId.seer: 1,
          RoleId.robber: 1,
          RoleId.troublemaker: 1,
        };
        expect(RoleConfig.isValid(roles, 3), isFalse);
      });

      test('returns false when player count is below 3', () {
        final roles = {
          RoleId.werewolf: 2,
          RoleId.seer: 1,
          RoleId.robber: 1,
          RoleId.troublemaker: 1,
        };
        expect(RoleConfig.isValid(roles, 2), isFalse);
      });

      test('returns false when player count is above 10', () {
        final roles = {
          RoleId.werewolf: 2,
          RoleId.seer: 1,
          RoleId.robber: 1,
          RoleId.troublemaker: 1,
          RoleId.villager: 3,
          RoleId.mason: 2,
          RoleId.drunk: 1,
          RoleId.insomniac: 1,
          RoleId.tanner: 1,
          RoleId.hunter: 1,
        };
        expect(RoleConfig.isValid(roles, 11), isFalse);
      });

      test('returns false when Mason count is 1', () {
        final roles = {
          RoleId.werewolf: 2,
          RoleId.seer: 1,
          RoleId.mason: 1, // invalid -- masons come in pairs
          RoleId.troublemaker: 1,
          RoleId.villager: 1,
        };
        expect(RoleConfig.isValid(roles, 3), isFalse);
      });

      test('returns true when Mason count is 0', () {
        final roles = {
          RoleId.werewolf: 2,
          RoleId.seer: 1,
          RoleId.robber: 1,
          RoleId.troublemaker: 1,
          RoleId.villager: 1,
        };
        // mason count is implicitly 0 (not in map)
        expect(RoleConfig.isValid(roles, 3), isTrue);
      });

      test('returns true when Mason count is 2', () {
        // 5 players need 8 cards
        final roles = {
          RoleId.werewolf: 2,
          RoleId.seer: 1,
          RoleId.robber: 1,
          RoleId.troublemaker: 1,
          RoleId.mason: 2,
          RoleId.villager: 1,
        };
        expect(RoleConfig.isValid(roles, 5), isTrue);
      });

      test(
        'returns true for empty roles with valid player count when total matches',
        () {
          // Edge case: technically impossible since 0 != playerCount + 3 for any valid count
          expect(RoleConfig.isValid({}, 3), isFalse);
        },
      );
    });

    group('validationError', () {
      test('returns null for valid configuration', () {
        final roles = {
          RoleId.werewolf: 2,
          RoleId.seer: 1,
          RoleId.robber: 1,
          RoleId.troublemaker: 1,
          RoleId.villager: 1,
        };
        expect(RoleConfig.validationError(roles, 3), isNull);
      });

      test('returns descriptive error for wrong total', () {
        final roles = {RoleId.werewolf: 2, RoleId.seer: 1};
        final error = RoleConfig.validationError(roles, 3);
        expect(error, isNotNull);
        expect(error, contains('6'));
        expect(error, contains('3'));
      });

      test('returns descriptive error for invalid player count', () {
        expect(RoleConfig.validationError({}, 2), contains('between 3 and 10'));
        expect(
          RoleConfig.validationError({}, 11),
          contains('between 3 and 10'),
        );
      });

      test('returns descriptive error for Mason count of 1', () {
        final roles = {
          RoleId.werewolf: 2,
          RoleId.seer: 1,
          RoleId.mason: 1,
          RoleId.troublemaker: 1,
          RoleId.villager: 1,
        };
        final error = RoleConfig.validationError(roles, 3);
        expect(error, isNotNull);
        expect(error, contains('Mason'));
        expect(error, contains('pairs'));
      });

      test('returns descriptive error for negative count', () {
        final roles = {RoleId.werewolf: -1};
        final error = RoleConfig.validationError(roles, 3);
        expect(error, isNotNull);
        expect(error, contains('negative'));
      });

      test('returns descriptive error when count exceeds max', () {
        final roles = {RoleId.seer: 2}; // max is 1
        final error = RoleConfig.validationError(roles, 3);
        expect(error, isNotNull);
        expect(error, contains('Seer'));
        expect(error, contains('exceed'));
      });
    });

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

    group('totalCards', () {
      test('returns sum of all role counts', () {
        final roles = {
          RoleId.werewolf: 2,
          RoleId.seer: 1,
          RoleId.robber: 1,
          RoleId.troublemaker: 1,
          RoleId.villager: 1,
        };
        expect(RoleConfig.totalCards(roles), 6);
      });

      test('returns 0 for empty map', () {
        expect(RoleConfig.totalCards({}), 0);
      });
    });

    group('presetsForPlayerCount', () {
      test('returns presets for 3 players', () {
        final presets = RoleConfig.presetsForPlayerCount(3);
        expect(presets, isNotEmpty);
        expect(presets.containsKey('Starter'), isTrue);
        // Verify preset is valid: 3 players + 3 center = 6 cards
        expect(RoleConfig.totalCards(presets['Starter']!), 6);
        expect(RoleConfig.isValid(presets['Starter']!, 3), isTrue);
      });

      test('returns presets for 5 players with three difficulty levels', () {
        final presets = RoleConfig.presetsForPlayerCount(5);
        expect(presets.length, 3);
        expect(presets.containsKey('Starter'), isTrue);
        expect(presets.containsKey('Intermediate'), isTrue);
        expect(presets.containsKey('Advanced'), isTrue);
      });

      test('all presets are valid for their player count', () {
        for (var count = 3; count <= 10; count++) {
          final presets = RoleConfig.presetsForPlayerCount(count);
          for (final entry in presets.entries) {
            expect(
              RoleConfig.isValid(entry.value, count),
              isTrue,
              reason: '${entry.key} preset for $count players should be valid',
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
