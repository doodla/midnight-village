import 'package:flutter/material.dart';
import 'package:midnight_village/design_system/tokens/app_tokens.dart';

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
  doppelganger,
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

  Color teamColor(AppColorTokens colors) => switch (team) {
        TeamId.werewolf => colors.werewolfTeam,
        TeamId.village => colors.villageTeam,
        TeamId.independent => colors.independentTeam,
      };

  IconData get placeholderIcon => switch (this) {
        RoleId.werewolf => Icons.pets,
        RoleId.minion => Icons.sentiment_very_dissatisfied,
        RoleId.villager => Icons.person,
        RoleId.seer => Icons.visibility,
        RoleId.robber => Icons.swap_horiz,
        RoleId.troublemaker => Icons.shuffle,
        RoleId.drunk => Icons.local_bar,
        RoleId.insomniac => Icons.nightlight_round,
        RoleId.mason => Icons.handshake,
        RoleId.hunter => Icons.gps_fixed,
        RoleId.tanner => Icons.work,
        RoleId.doppelganger => Icons.content_copy,
      };
}
