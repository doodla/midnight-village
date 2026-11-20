enum TeamId { werewolf, village, independent }

enum RoleId {
  werewolf,
  minion,
  villager,
  seer,
  robber,
  troublemaker,
  drunk,
  insomniac,
  mason,
  hunter,
  tanner,
  doppelganger;

  /// The role the server names [name] ("Werewolf", "Doppelganger"), or null
  /// for a name it does not use.
  static RoleId? fromServer(String name) =>
      values.where((role) => role.displayName == name).firstOrNull;
}

extension RoleIdX on RoleId {
  TeamId get team => switch (this) {
    RoleId.werewolf => TeamId.werewolf,
    RoleId.minion => TeamId.werewolf,
    RoleId.tanner => TeamId.independent,
    _ => TeamId.village,
  };

  String get displayName => switch (this) {
    RoleId.werewolf => 'Werewolf',
    RoleId.minion => 'Minion',
    RoleId.villager => 'Villager',
    RoleId.seer => 'Seer',
    RoleId.robber => 'Robber',
    RoleId.troublemaker => 'Troublemaker',
    RoleId.drunk => 'Drunk',
    RoleId.insomniac => 'Insomniac',
    RoleId.mason => 'Mason',
    RoleId.hunter => 'Hunter',
    RoleId.tanner => 'Tanner',
    RoleId.doppelganger => 'Doppelganger',
  };
}
