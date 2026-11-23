import 'package:flutter/widgets.dart';

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

/// The reading floor (first-time play spec, copy rule 7, as the owner's type
/// choice of 23 November 2026 set it): the smallest a player's words are drawn
/// at text scale 1.0, after any shrinking to fit. The screen gallery holds
/// every player screen to it.
abstract final class ReadingFloor {
  /// Anything a player reads to act or to know who is who: body, buttons and
  /// names.
  static const act = 14.0;

  /// Small labels: captions, tags, badges.
  static const caption = 12.0;
}

/// Fixed sizes of things that are not text, the same in every skin.
abstract final class Sizes {
  /// A QR code's side: never under [qrScannable] (a phone held across the
  /// table still reads it), at most [qrLargest].
  static const qrScannable = 160.0;
  static const qrLargest = 220.0;

  /// The scanner's window (01b), at most this wide and always square.
  static const viewfinderLargest = 320.0;

  /// The busy mark standing under the code in the scanner's window.
  static const viewfinderBusy = 32.0;

  /// The least room for 02's code beside its QR code; with less, they stack.
  static const joinCodeBeside = 100.0;

  /// Players at a table still about getting the others in (02 large).
  static const nearlyEmptyTable = 2;

  /// From this many at the table, 02's rows go two to a line where each
  /// half is at least [playerColumn] wide.
  static const twoUpPlayers = 5;
  static const playerColumn = 150.0;

  /// A role card in the deck builder's grid, width over height: the
  /// portrait and its name under it (S03).
  static const roleGridCell = 0.66;

  /// The smallest a control is to touch, both ways (the reading floor's 44:
  /// a stepper's glyphs, a grid card's minus).
  static const touch = 44.0;

  /// A glyph inside a round control, as a share of its disc (the grid card's
  /// minus, a stepper's minus and plus).
  static const glyphInDisc = 0.6;

  /// A seat at a table set for a number, drawn as a circle: taken, filled;
  /// empty, its outline (02, 03).
  static const seat = 18.0;

  /// The least a deck strip's thumbnail shrinks to, as a share of its size,
  /// before the strip takes a second line (02).
  static const thumbLeast = 0.6;

  /// A card's slot in 03's count, the players' and the centre's.
  static const deckSlot = Size(12, 16);

  /// The sign of life of a wait: three paper lanterns of this width, and the
  /// gap between them.
  static const waitLantern = 22.0;
  static const waitGap = 18.0;
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

  /// The dusk (the deal to the night) and the dawn (the night to the talk):
  /// the one scene change the whole table shares (`SceneSwitcher`). Nowhere
  /// else; the screen it arrives on takes touches from its first frame.
  static const scene = Duration(milliseconds: 500);

  /// A wait's sign of life (`WaitingSign`) comes in after this: an answer
  /// that arrives sooner shows no sign at all, so a quick load never
  /// flashes one. It delays the sign only, never what is loading.
  static const signAfter = Duration(milliseconds: 300);

  /// A wait that has lasted this long is named once, plainly
  /// (`BannerCopy.slow`): the server is slow, nothing is wrong.
  static const slowAfter = Duration(seconds: 5);

  /// One round of the sign of life: three paper lanterns lifting in turn.
  static const waitLoop = Duration(milliseconds: 1500);

  static const curve = Curves.easeOutCubic;

  /// [duration], or no time at all when the phone asks for reduced motion
  /// (the shell and the scene switcher read it here; a motion that checks
  /// the setting itself is to move to this).
  static Duration within(BuildContext context, Duration duration) =>
      MediaQuery.disableAnimationsOf(context) ? Duration.zero : duration;
}
