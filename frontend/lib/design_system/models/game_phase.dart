enum GamePhase {
  lobby('Lobby'),
  night('Night'),
  discussion('Discussion'),
  voting('Voting'),
  results('Results');

  const GamePhase(this.displayName);
  final String displayName;
}
