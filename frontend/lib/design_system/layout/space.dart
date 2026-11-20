import 'package:flutter/animation.dart';

/// Spacing: the gaps and margins of the mocks, the same in every skin (a skin
/// may change art, colours, type and shape, never where things sit; design
/// brief section 2). Read it as `Space.md`, with no skin in reach.
///
/// The mocks' odd gaps snap to the nearest step: 5 to [xs], 7 to [sm], 22 and
/// 26 to [xl], 30 to [screenBottom] (docs/design/mock-to-skin.md lists each).
abstract final class Space {
  /// Between a label and the value under it (a pace tile).
  static const hairline = 2.0;
  static const xxs = 4.0;
  static const xs = 6.0;
  static const sm = 8.0;
  static const smPlus = 10.0;
  static const md = 12.0;
  static const mdPlus = 14.0;
  static const lg = 16.0;
  static const lgPlus = 18.0;
  static const xl = 24.0;
  static const xxl = 32.0;

  /// Left and right margin of a screen.
  static const gutter = 24.0;

  /// Above the first thing on a screen with no top picture or band.
  static const screenTop = 40.0;

  /// Below the pinned actions.
  static const screenBottom = 28.0;
}

/// The reading floor (first-time play spec, copy rule 7): the smallest a
/// player's words are drawn at text scale 1.0, after any shrinking to fit.
/// The screen gallery holds every player screen to it.
abstract final class ReadingFloor {
  /// Anything a player reads to act.
  static const act = 16.0;

  /// Captions under cards and tokens.
  static const caption = 14.0;
}

/// How long things take to move: the same in every skin.
abstract final class Motion {
  /// A button going down or coming back up.
  static const press = Duration(milliseconds: 90);

  /// Small state changes: a pick, a ring, a count.
  static const quick = Duration(milliseconds: 160);

  /// A part of the screen arriving or leaving.
  static const settle = Duration(milliseconds: 260);

  /// A card turning over.
  static const reveal = Duration(milliseconds: 400);

  /// Between one row and the next arriving in a list that lands (the
  /// count's votes, the night's lines on 11).
  static const stagger = Duration(milliseconds: 150);

  /// A beat held before the moment a screen is about (the count's cards
  /// turning). A tap skips it; nothing waits on it.
  static const beat = Duration(milliseconds: 1200);

  static const curve = Curves.easeOutCubic;
}
