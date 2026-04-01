import 'package:midnight_village/design_system/models/role.dart';

/// Utility class for role configuration validation and recommended presets.
///
/// This is pure UI convenience logic -- the server re-validates all role
/// configurations on game start. These checks let us disable the start
/// button and show helpful error messages without a round-trip.
class RoleConfig {
  RoleConfig._();

  /// Validates that a role configuration is legal for the given player count.
  ///
  /// Rules:
  /// - Player count must be 3-10.
  /// - Total cards must equal playerCount + 3 (players + 3 center cards).
  /// - Each role count must be >= 0.
  /// - Mason count must be 0 or 2 (they come in pairs).
  static bool isValid(Map<RoleId, int> roles, int playerCount) {
    return validationError(roles, playerCount) == null;
  }

  /// Returns a human-readable error message, or null if the configuration
  /// is valid.
  static String? validationError(Map<RoleId, int> roles, int playerCount) {
    if (playerCount < 3 || playerCount > 10) {
      return 'Player count must be between 3 and 10';
    }

    for (final entry in roles.entries) {
      if (entry.value < 0) {
        return '${entry.key.displayName} count cannot be negative';
      }
      if (entry.value > maxCount(entry.key)) {
        return '${entry.key.displayName} count cannot exceed ${maxCount(entry.key)}';
      }
    }

    final masonCount = roles[RoleId.mason] ?? 0;
    if (masonCount != 0 && masonCount != 2) {
      return 'Masons must be included in pairs (0 or 2)';
    }

    final total = totalCards(roles);
    final expected = playerCount + 3;
    if (total != expected) {
      return 'Need exactly $expected cards ($playerCount players + 3 center), '
          'currently have $total';
    }

    return null;
  }

  /// Returns the step size for incrementing/decrementing a role.
  ///
  /// Mason increments by 2 (must always be 0 or 2). All others by 1.
  static int stepSize(RoleId role) => role == RoleId.mason ? 2 : 1;

  /// Maximum count per role.
  ///
  /// - Villager: up to 3
  /// - Werewolf: up to 2
  /// - Mason: up to 2
  /// - All others: up to 1
  static int maxCount(RoleId role) => switch (role) {
    RoleId.villager => 3,
    RoleId.werewolf => 2,
    RoleId.mason => 2,
    _ => 1,
  };

  /// Sum of all role counts.
  static int totalCards(Map<RoleId, int> roles) {
    return roles.values.fold(0, (sum, count) => sum + count);
  }

  /// Returns named preset configurations for the given player count.
  ///
  /// Presets are sourced from the official ONUW recommended setups
  /// (docs/specs/onuw/recommended-setups.md). Only base-game setups
  /// are included.
  static Map<String, Map<RoleId, int>> presetsForPlayerCount(int count) {
    return _presets[count] ?? {};
  }

  static const Map<int, Map<String, Map<RoleId, int>>> _presets = {
    3: {
      'Starter': {
        RoleId.werewolf: 2,
        RoleId.seer: 1,
        RoleId.robber: 1,
        RoleId.troublemaker: 1,
        RoleId.villager: 1,
      },
    },
    4: {
      'Starter': {
        RoleId.werewolf: 2,
        RoleId.seer: 1,
        RoleId.robber: 1,
        RoleId.troublemaker: 1,
        RoleId.villager: 2,
      },
    },
    5: {
      'Starter': {
        RoleId.werewolf: 2,
        RoleId.seer: 1,
        RoleId.robber: 1,
        RoleId.troublemaker: 1,
        RoleId.villager: 3,
      },
      'Intermediate': {
        RoleId.werewolf: 2,
        RoleId.seer: 1,
        RoleId.robber: 1,
        RoleId.troublemaker: 1,
        RoleId.drunk: 1,
        RoleId.insomniac: 1,
        RoleId.villager: 1,
      },
      'Advanced': {
        RoleId.werewolf: 2,
        RoleId.minion: 1,
        RoleId.seer: 1,
        RoleId.robber: 1,
        RoleId.troublemaker: 1,
        RoleId.tanner: 1,
        RoleId.villager: 1,
      },
    },
    6: {
      'Classic': {
        RoleId.werewolf: 2,
        RoleId.minion: 1,
        RoleId.seer: 1,
        RoleId.robber: 1,
        RoleId.troublemaker: 1,
        RoleId.villager: 3,
      },
      'Chaotic': {
        RoleId.werewolf: 2,
        RoleId.seer: 1,
        RoleId.robber: 1,
        RoleId.troublemaker: 1,
        RoleId.drunk: 1,
        RoleId.insomniac: 1,
        RoleId.tanner: 1,
        RoleId.villager: 1,
      },
      'Full Info': {
        RoleId.werewolf: 2,
        RoleId.seer: 1,
        RoleId.robber: 1,
        RoleId.troublemaker: 1,
        RoleId.mason: 2,
        RoleId.insomniac: 1,
        RoleId.villager: 1,
      },
    },
    7: {
      'Standard': {
        RoleId.werewolf: 2,
        RoleId.minion: 1,
        RoleId.seer: 1,
        RoleId.robber: 1,
        RoleId.troublemaker: 1,
        RoleId.mason: 2,
        RoleId.drunk: 1,
        RoleId.insomniac: 1,
      },
      'With Tanner': {
        RoleId.werewolf: 2,
        RoleId.minion: 1,
        RoleId.tanner: 1,
        RoleId.seer: 1,
        RoleId.robber: 1,
        RoleId.troublemaker: 1,
        RoleId.mason: 2,
        RoleId.insomniac: 1,
      },
    },
    8: {
      'Standard': {
        RoleId.werewolf: 2,
        RoleId.minion: 1,
        RoleId.seer: 1,
        RoleId.robber: 1,
        RoleId.troublemaker: 1,
        RoleId.mason: 2,
        RoleId.drunk: 1,
        RoleId.insomniac: 1,
        RoleId.villager: 1,
      },
      'With Tanner': {
        RoleId.werewolf: 2,
        RoleId.minion: 1,
        RoleId.tanner: 1,
        RoleId.seer: 1,
        RoleId.robber: 1,
        RoleId.troublemaker: 1,
        RoleId.mason: 2,
        RoleId.insomniac: 1,
        RoleId.villager: 1,
      },
    },
    9: {
      'All-in': {
        RoleId.werewolf: 2,
        RoleId.minion: 1,
        RoleId.tanner: 1,
        RoleId.hunter: 1,
        RoleId.seer: 1,
        RoleId.robber: 1,
        RoleId.troublemaker: 1,
        RoleId.mason: 2,
        RoleId.drunk: 1,
        RoleId.insomniac: 1,
      },
      'With Doppelganger': {
        RoleId.doppelganger: 1,
        RoleId.werewolf: 2,
        RoleId.minion: 1,
        RoleId.seer: 1,
        RoleId.robber: 1,
        RoleId.troublemaker: 1,
        RoleId.mason: 2,
        RoleId.drunk: 1,
        RoleId.insomniac: 1,
        RoleId.tanner: 1,
      },
    },
    10: {
      'All-in': {
        RoleId.werewolf: 2,
        RoleId.minion: 1,
        RoleId.tanner: 1,
        RoleId.hunter: 1,
        RoleId.seer: 1,
        RoleId.robber: 1,
        RoleId.troublemaker: 1,
        RoleId.mason: 2,
        RoleId.drunk: 1,
        RoleId.insomniac: 1,
        RoleId.villager: 1,
      },
      'With Doppelganger': {
        RoleId.doppelganger: 1,
        RoleId.werewolf: 2,
        RoleId.minion: 1,
        RoleId.seer: 1,
        RoleId.robber: 1,
        RoleId.troublemaker: 1,
        RoleId.mason: 2,
        RoleId.drunk: 1,
        RoleId.insomniac: 1,
        RoleId.tanner: 1,
        RoleId.villager: 1,
      },
    },
  };
}
