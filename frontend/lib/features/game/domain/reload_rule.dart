import '../../../core/update/new_build.dart' show Moment;
import 'screen_table.dart';

/// THE rule for when the app reloads itself to run a newer build (owner,
/// 23 November 2026: an open app must not go on running old code). One
/// place; `NewBuild` asks it and nothing else decides.
///
/// Never while the player has something on its way or half written:
/// [busy] (a night action, a vote or any `playerRequest` in flight, a tap
/// not sent yet) or [halfTyped] (text typed into a field). Otherwise, by
/// what is shown ([place]: an [AppScreen], or one of `HomeGate`'s own
/// names):
///
/// - Where nothing is going on that a reload would lose, at once: 01, a
///   table before the deal (02, 03), the count and the results (10, 11),
///   "You're at another table.".
/// - In a running game (04, the night board, 08, 09), only when the game
///   moves on (the next phase or stage: [Moment.screenChanged]) or the app
///   has just come back ([Moment.resumed]), whichever is first.
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
  final atAMoment = moment != Moment.learned;
  return switch (place) {
    AppScreen.join ||
    AppScreen.table ||
    AppScreen.deck ||
    AppScreen.count ||
    AppScreen.results => true,
    AppScreen.yourCard ||
    AppScreen.nightBoard ||
    AppScreen.talk ||
    AppScreen.vote => atAMoment,
    // HomeGate's own names for what is not a table screen.
    'join' || 'elsewhere' => true,
    _ => false,
  };
}
