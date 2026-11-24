import '../../../core/update/new_build.dart' show Moment;
import 'screen_table.dart';

/// THE rule for when the app reloads itself to run a newer build (owner,
/// 23 November 2026: an open app must not go on running old code; 24 November
/// 2026: "Reload only when nobody waits"). One place; `NewBuild` asks it and
/// nothing else decides.
///
/// Never while the player has something on its way or half done: [busy] (a
/// night action, a vote or any `playerRequest` in flight, a tap not sent yet)
/// or [halfTyped] (text typed on the first screen, or the scanner open).
/// Otherwise, by what is shown ([place]: an [AppScreen], or one of
/// `HomeGate`'s own names):
///
/// - On the first screen (01), at once: nobody waits there, and its form is
///   kept across the reload.
/// - On every other screen (the table 02 and the set-up page 03, "You're at
///   another table.", and a running game: your card 04, the night board, the
///   talk 08, the vote 09, the end board), NEVER because a screen changed or
///   a build was learned of or on the timer: friends wait for a table, and a
///   restart ("play again") must not stall on a full reload. Only when the
///   app comes back after a while away (the tab visible again after being
///   hidden for more than a few seconds, `NewBuild.awayFor`:
///   [Moment.resumed]). A phone left open at the table across several games
///   keeps the old build until then; the owner accepted that cost.
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
    // The first screen (`HomeGate`'s own name for it is 'join').
    AppScreen.join || 'join' => true,
    AppScreen.table ||
    AppScreen.deck ||
    AppScreen.yourCard ||
    AppScreen.nightBoard ||
    AppScreen.talk ||
    AppScreen.vote ||
    AppScreen.end ||
    'elsewhere' => cameBack,
    _ => false,
  };
}
