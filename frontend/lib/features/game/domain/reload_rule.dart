import '../../../core/update/new_build.dart' show Moment;
import 'screen_table.dart';

/// THE rule for when the app reloads itself to run a newer build (owner,
/// 23 November 2026: an open app must not go on running old code). One
/// place; `NewBuild` asks it and nothing else decides.
///
/// Never while the player has something on its way or half done: [busy] (a
/// night action, a vote or any `playerRequest` in flight, a tap not sent yet)
/// or [halfTyped] (text typed on the first screen, or the scanner open).
/// Otherwise, by what is shown ([place]: an [AppScreen], or one of
/// `HomeGate`'s own names):
///
/// - Where nothing is going on that a reload would lose, at once: 01 (its
///   form is kept across the reload), a table before the deal (02, 03), the
///   results (11), "You're at another table.".
/// - In a running game (your card 04, the night board 06, the talk 08, the
///   vote 09, the count 10) NEVER on a phase change or on the timer: a
///   player must not enter the night or the vote with a cold reload inside a
///   timed stage. Only when the app comes back (the tab visible again after
///   being hidden for more than a few seconds: [Moment.resumed]); otherwise
///   the reload waits for the results or the table.
/// - While the app is still finding out where it is (the opening): not yet;
///   the screen that follows is a moment.
///
/// The reload goes through the app's own opening: a seated player lands at
/// their seat on the same screen (`/me/table/`, the seat kept on the device).
bool mayReloadNow({
  required Object? place,
  required Moment moment,
  required bool busy,
  required bool halfTyped,
}) {
  if (busy || halfTyped) return false;
  final cameBack = moment == Moment.resumed;
  return switch (place) {
    AppScreen.join ||
    AppScreen.table ||
    AppScreen.deck ||
    AppScreen.results => true,
    AppScreen.yourCard ||
    AppScreen.nightBoard ||
    AppScreen.talk ||
    AppScreen.vote ||
    AppScreen.count => cameBack,
    // HomeGate's own names for what is not a table screen.
    'join' || 'elsewhere' => true,
    _ => false,
  };
}
