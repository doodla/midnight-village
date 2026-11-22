/// The five card backs. One is drawn for a whole game ([CardBack.forGame]),
/// the same on every card and every phone at the table; outside a game it is
/// [CardBack.fallback].
enum CardBack {
  /// A crescent moon over low rooftops with one lit window. The calm one,
  /// and the one every picture outside a game shows.
  moon('moon'),

  /// A dark cottage gable with one lit window.
  window('window'),

  /// A border of wolf's teeth round a calm middle.
  teeth('teeth'),

  /// A wolf's eye.
  eye('eye'),

  /// A star quilt.
  quilt('quilt');

  const CardBack(this.fileName);

  /// The picture's name in the skin's `scenes/` folder after `card_back_`.
  final String fileName;

  /// The back outside a game: the deck on the table and set-up screens, the
  /// join screen, the galleries and the screens tool, so those pictures are
  /// stable.
  static const fallback = moon;

  /// The back for the game [gameId], or [fallback] for no game.
  ///
  /// Backs must not tell one card from another: a card is swapped
  /// and looked at during the night, and a player who could tell two cards
  /// apart by their backs could follow one. So the back is a choice of the
  /// whole game, never of a card or a player, and it is made from the game's
  /// id: a value every phone at the table already holds (it is in the
  /// address of the game, and the server names it to every player alike),
  /// that is not secret and differs from one game to the next (a new deal is
  /// a new game, so Play again usually, one time in five not, shows another
  /// back). No randomness: the same id is the same back on every phone and
  /// at every restart.
  ///
  /// The hash is djb2 over the id's UTF-16 units, kept under 2^31 at every
  /// step so it is the same on the web (where integers are doubles) as on a
  /// phone. (`String.hashCode` is not: it is not stable across platforms.)
  static CardBack forGame(String? gameId) {
    if (gameId == null || gameId.isEmpty) return fallback;
    var hash = 5381;
    for (final unit in gameId.codeUnits) {
      hash = (hash * 33 + unit) & 0x7fffffff;
    }
    return values[hash % values.length];
  }
}
