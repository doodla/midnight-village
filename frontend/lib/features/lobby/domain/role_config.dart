import 'package:midnight_village/design_system/models/role.dart';

/// How the deck grid steps a role (03) and the debug toolbar's presets.
///
/// The phone holds no deck rule: whether a deck can be dealt is the server's
/// `deal` (`DealState`).
class RoleConfig {
  RoleConfig._();

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
