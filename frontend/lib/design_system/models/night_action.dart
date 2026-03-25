enum NightActionType {
  peekPlayer, // Seer option A
  peekCenter, // Seer option B, lone werewolf
  swapWithPlayer, // Robber
  swapWithCenter, // Drunk
  swapOthers, // Troublemaker
  seeTeam, // Werewolf, Mason, Minion
  none, // Villager, Tanner, Hunter (no action / waiting)
}

sealed class NightActionSelection {}

class PlayerTarget extends NightActionSelection {
  final String playerId;
  PlayerTarget(this.playerId);
}

class CenterTargets extends NightActionSelection {
  final List<int> indices;
  CenterTargets(this.indices);
}

class TwoPlayerTargets extends NightActionSelection {
  final String player1Id;
  final String player2Id;
  TwoPlayerTargets(this.player1Id, this.player2Id);
}

class NoAction extends NightActionSelection {}
