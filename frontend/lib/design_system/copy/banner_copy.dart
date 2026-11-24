part of 'copy.dart';

/// System banners (their own budget: 6 words with the button).
abstract final class BannerCopy {
  static const lobbyNotFound = Words._('No table with that code.');
  static const lobbyFull = Words._('That table is full.');
  static const lobbyClosed = Words._('That table is playing now.');
  static const alreadyInLobby = Words._("You're at another table.");
  static const goThere = Words._('Go there');
  static const tableClosed = Words._('This table has closed.');
  static const goHome = Words._('Go home');
  static const notSent = Words._('Not sent.');
  static const tryAgain = Words._('Try again');
  static const offline = Words._('One moment');

  /// A wait that has lasted (`Motion.slowAfter`) while nothing has failed:
  /// the answer is slow, not lost.
  static const slow = Words._('Still on its way.');
  static const leftGame = Words._('You left this game.');

  /// 02's Share copied the link (no share sheet on this device).
  static const copied = Words._('Copied');

  /// Why the deal cannot happen (the server's `deal` or its refusal): the
  /// deck does not fit the table; any other reason.
  static const deckDoesNotFit = Words._('The deck does not fit.');
  static const cannotDeal = Words._("Can't deal yet.");

  /// A leave the server refused for a reason with no words of its own.
  static const cannotLeave = Words._("Can't leave now.");
}
