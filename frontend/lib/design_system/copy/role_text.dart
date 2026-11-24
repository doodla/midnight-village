import 'package:flutter/foundation.dart';

import '../models/role.dart';
import 'copy.dart';

/// One row of a role's text: a small [label] ("Night", "Vote", "Wins") and
/// its short [lines], one per case ("At dawn, see the other Werewolves." /
/// "Alone: you may see 1 center card.").
@immutable
class RolePart {
  const RolePart(this.label, this.lines);

  final String label;
  final List<String> lines;
}

/// One role's text: what the 04 face, the role sheet (03b) and the role card
/// say about it. Laid out as [tag] over the name; then [parts], a small label
/// beside each part's lines; then [RoleCopy.shared] set apart, a rule of the
/// game rather than of this role (first-time play spec, section 3, "Role
/// text"; drawn by `RoleRules`).
@immutable
class RoleText {
  const RoleText._(this.role, this.parts);

  /// The text for [role]: the one table every screen reads.
  factory RoleText.of(RoleId role) {
    const village = RolePart(RoleCopy.winsLabel, [
      RoleCopy.villageWins,
      RoleCopy.villageNoWerewolf,
    ]);
    RolePart night(List<String> lines) => RolePart(RoleCopy.nightLabel, lines);
    RolePart wins(List<String> lines) => RolePart(RoleCopy.winsLabel, lines);
    final parts = switch (role) {
      RoleId.werewolf => [
        night([RoleCopy.werewolfNight, RoleCopy.werewolfAlone]),
        wins([RoleCopy.werewolfWins]),
      ],
      RoleId.minion => [
        night([RoleCopy.minionNight, RoleCopy.minionUnseen]),
        wins([RoleCopy.minionWins, RoleCopy.minionNoWerewolf]),
      ],
      RoleId.mason => [
        night([RoleCopy.masonNight]),
        village,
      ],
      RoleId.seer => [
        night([RoleCopy.seerNight]),
        village,
      ],
      RoleId.robber => [
        night([RoleCopy.robberNight]),
        village,
      ],
      RoleId.troublemaker => [
        night([RoleCopy.troublemakerNight]),
        village,
      ],
      RoleId.drunk => [
        night([RoleCopy.drunkNight]),
        village,
      ],
      RoleId.insomniac => [
        night([RoleCopy.insomniacNight]),
        village,
      ],
      RoleId.hunter => [
        night([RoleCopy.sleep]),
        const RolePart(RoleCopy.voteLabel, [RoleCopy.hunterVote]),
        village,
      ],
      RoleId.villager => [
        night([RoleCopy.sleep]),
        village,
      ],
      RoleId.tanner => [
        night([RoleCopy.sleep]),
        wins([RoleCopy.tannerWins]),
      ],
      RoleId.doppelganger => [
        night([RoleCopy.doppelgangerNight]),
        wins([RoleCopy.doppelgangerWins]),
      ],
    };
    return RoleText._(role, parts);
  }

  final RoleId role;

  /// The rows, in reading order: "Night" (the Hunter's "Vote" after it),
  /// then "Wins".
  final List<RolePart> parts;

  /// The role's tag: its team, as the card in hand would play it, never the
  /// role's own name.
  String get tag => switch (role) {
    RoleId.doppelganger => RoleCopy.copies,
    _ => teamLabel(team),
  };

  /// The team the role's tag is coloured for, the same on every surface
  /// (`TagChip.team`): the Werewolf team's red, the Tanner's umber, else the
  /// Village's.
  TeamId get team => switch (role) {
    RoleId.werewolf || RoleId.minion => TeamId.werewolf,
    RoleId.tanner => TeamId.independent,
    _ => TeamId.village,
  };

  /// Every word on the card, in reading order: the tag, each label and its
  /// lines, the shared line.
  List<String> get lines => [
    tag,
    for (final part in parts) ...[part.label, ...part.lines],
    RoleCopy.shared,
  ];

  /// A team's tag on 10 and 11, from the server's `team`.
  static String teamTag(TeamId team) => switch (team) {
    TeamId.village => RoleCopy.village,
    TeamId.werewolf => RoleId.werewolf.displayName,
    TeamId.independent => RoleCopy.alone,
  };

  /// A team's tag beside a role's name (a card, a sheet, the count): never
  /// the name twice, so the Werewolf team's reads "Werewolf team".
  static String teamLabel(TeamId team) => switch (team) {
    TeamId.werewolf => CountCopy.werewolfTeam.fill({
      'role': teamTag(TeamId.werewolf),
    }),
    _ => teamTag(team),
  };
}
