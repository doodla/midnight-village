part of 'copy.dart';

/// System banners (their own budget: 6 words with the button).
abstract final class BannerCopy {
  static const lobbyNotFound = 'No table with that code.';
  static const lobbyFull = 'That table is full.';
  static const lobbyClosed = 'That table is playing now.';
  static const alreadyInLobby = "You're at another table.";
  static const goThere = 'Go there';
  static const tableClosed = 'This table has closed.';
  static const goHome = 'Go home';
  static const notSent = 'Not sent.';
  static const tryAgain = 'Try again';
  static const offline = 'One moment';

  /// A wait that has lasted (`Motion.slowAfter`) while nothing has failed:
  /// the answer is slow, not lost.
  static const slow = 'Still on its way.';
  static const leftGame = 'You left this game.';

  /// 02's Share copied the link (no share sheet on this device).
  static const copied = 'Copied';

  /// Why the deal cannot happen (the server's `deal` or its refusal): the
  /// deck does not fit the table; any other reason.
  static const deckDoesNotFit = 'The deck does not fit.';
  static const cannotDeal = "Can't deal yet.";

  /// A leave the server refused for a reason with no words of its own.
  static const cannotLeave = "Can't leave now.";
}
