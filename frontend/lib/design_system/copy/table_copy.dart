part of 'copy.dart';

/// 02 Table.
abstract final class TableCopy {
  // Host.
  static const scan = Words._('Scan to join');

  /// Spoken only: Share is a glyph beside "Scan to join", since the deck's
  /// chip name ("Simple") takes its word in the host's 7.
  static const share = Words._('Share');

  /// On the deck strip. Spec: "Edit deck", which puts the host's 02 at 8
  /// words for a budget of 7; the strip it sits on names the deck.
  static const editDeck = Words._('Edit');

  /// The table's one primary button (owner, 23 November 2026: "Just say
  /// 'Start the game' or whatever"; it said "Deal to {n}"). When it cannot be
  /// taken it says what to do, and tapping it does it: [needPlayers],
  /// [needMore] (the friends are the way in: the code is above), or the deck's
  /// fix ([DeckCopy.addCard] and its kin, which opens 03). Never the same
  /// words dimmed.
  static const start = Words._('Start the game');
  static const needPlayers = Words._('Need 3 players');

  /// A table set for a number, fewer here: how many more it waits for.
  static const needMore = Template('Need {n} more');

  /// At a table set for a number: who is here of how many (02 and 03, host
  /// and guests), by the seats, the empty ones drawn. The one way the wait
  /// is said, never as card arithmetic.
  static const seated = Template('{d} of {n}');

  /// Fewer came than the table is set for: one tap sets the number to who
  /// is here.
  static const playWith = Template('Play with {n}');

  /// The host's way out, quiet and labelled, behind a confirm ([stay]
  /// keeps the table): one stray tap must not hand the table away.
  static const stay = Words._('Stay');

  /// Beside a practice player's name (a seat the server plays, switched on
  /// by the host's long press on 03's "Players"), at the table and in the
  /// vote, for everyone.
  static const practice = Words._('Practice');

  // Guest.
  static const hostDeals = Template('{host} deals');
}
