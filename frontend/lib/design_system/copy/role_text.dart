import 'package:flutter/foundation.dart';
import 'package:flutter/painting.dart';

import '../models/role.dart';
import 'copy.dart';

/// One role's text: what the 04 face, the role sheet (03b) and the role card
/// say about it. Laid out as [tag]; "Night:" [night]; "Wins:" [wins]; then
/// [RoleCopy.shared] (first-time play spec, section 3, "Role text").
@immutable
class RoleText {
  const RoleText._(this.role, {required this.night, required this.wins});

  /// The text for [role]: the one table every screen reads.
  factory RoleText.of(RoleId role) {
    final (night, wins) = switch (role) {
      RoleId.werewolf => (RoleCopy.werewolfNight, RoleCopy.werewolfWins),
      RoleId.minion => (RoleCopy.minionNight, RoleCopy.minionWins),
      RoleId.mason => (RoleCopy.masonNight, RoleCopy.villageWins),
      RoleId.seer => (RoleCopy.seerNight, RoleCopy.villageWins),
      RoleId.robber => (RoleCopy.robberNight, RoleCopy.villageWins),
      RoleId.troublemaker => (RoleCopy.troublemakerNight, RoleCopy.villageWins),
      RoleId.drunk => (RoleCopy.drunkNight, RoleCopy.villageWins),
      RoleId.insomniac => (RoleCopy.insomniacNight, RoleCopy.villageWins),
      RoleId.hunter => (RoleCopy.hunterNight, RoleCopy.villageWins),
      RoleId.villager => (RoleCopy.sleep, RoleCopy.villageWins),
      RoleId.tanner => (RoleCopy.sleep, RoleCopy.tannerWins),
      RoleId.doppelganger => (
        RoleCopy.doppelgangerNight,
        RoleCopy.doppelgangerWins,
      ),
    };
    return RoleText._(role, night: night, wins: wins);
  }

  final RoleId role;
  final String night;
  final String wins;

  /// The role's tag: its team, as the card in hand would play it.
  String get tag => switch (role) {
    RoleId.doppelganger => RoleCopy.copies,
    RoleId.tanner => RoleCopy.alone,
    RoleId.werewolf || RoleId.minion => teamTag(TeamId.werewolf),
    _ => RoleCopy.village,
  };

  /// The team the role's tag is coloured for, the same on every surface
  /// (`TagChip.team`): the Werewolf team's red, the Tanner's umber, else the
  /// Village's.
  TeamId get team => switch (role) {
    RoleId.werewolf || RoleId.minion => TeamId.werewolf,
    RoleId.tanner => TeamId.independent,
    _ => TeamId.village,
  };

  /// The four parts in reading order, labels included: tag, "Night: ...",
  /// "Wins: ...", the shared line.
  List<String> get lines => [
    tag,
    '${RoleCopy.nightLabel} $night',
    '${RoleCopy.winsLabel} $wins',
    RoleCopy.shared,
  ];

  /// A team's tag on 10 and 11, from the server's `team`.
  static String teamTag(TeamId team) => switch (team) {
    TeamId.village => RoleCopy.village,
    TeamId.werewolf => RoleId.werewolf.displayName,
    TeamId.independent => RoleCopy.alone,
  };

  /// One of the role's lines as words: its "Night:" or "Wins:" label in the
  /// strong face, the rest in [style]. The one way every card, sheet and
  /// page sets these lines, so the same words are in the same face
  /// everywhere.
  static TextSpan lineSpan(String line, TextStyle style, TextStyle strong) {
    for (final label in [RoleCopy.nightLabel, RoleCopy.winsLabel]) {
      if (line.startsWith('$label ')) {
        return TextSpan(
          style: style,
          children: [
            TextSpan(
              text: '$label ',
              style: strong.copyWith(color: style.color),
            ),
            TextSpan(text: line.substring(label.length + 1)),
          ],
        );
      }
    }
    return TextSpan(text: line, style: style);
  }
}
