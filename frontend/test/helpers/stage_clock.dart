// Guard file: a change here needs its line in the pull request (tool/guard_edits.py).
import 'package:flutter/widgets.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/primitives/band.dart';
import 'package:midnight_village/design_system/primitives/face_down_card.dart';
import 'package:midnight_village/design_system/primitives/square_sky.dart';
import 'package:midnight_village/design_system/primitives/world_timer.dart';
import 'package:midnight_village/features/game/domain/game_me.dart';
import 'package:midnight_village/features/game/domain/screen_table.dart';
import 'package:midnight_village/features/game/presentation/live_game.dart';
import 'package:midnight_village/features/game/presentation/shell/table_shell.dart';
import 'package:midnight_village/features/game/presentation/table_screen.dart';
import 'package:midnight_village/features/lobby/domain/lobby_state.dart';

import 'screen_sweep.dart';

// A stage the server times is a stage the phone counts down (the owner, 24
// November 2026: "there's no timer in some stages, even though there's one
// under the hood"; 04 had a deadline and no clock). Two halves:
// - [stageClockProblems], a rule the screen sweep holds every catalogue state
//   to (sweep_run.dart): a game screen the shell shows from a `/me/` that
//   carries a `deadline` draws a clock with its number, on the screen, and a
//   night candle lies on no card and no main button;
// - [clockOf], what each timer the table can set (`Length`, every one the
//   server reads) shows, decided once per timer: a new timer does not build
//   until it is placed here.

/// What a timer the table sets shows on the phones.
sealed class TimerShown {
  const TimerShown();
}

/// The stage's clock, counted down on [screen] from the `/me/` deadline.
class StageClock extends TimerShown {
  const StageClock(this.screen);
  final AppScreen screen;
}

/// No phone counts it down, on purpose, and [why].
class NoClock extends TimerShown {
  const NoClock(this.why);
  final String why;
}

/// What [length] shows: the exception list is the [NoClock] cases.
TimerShown clockOf(Length length) => switch (length) {
  Length.look => const StageClock(AppScreen.yourCard),
  Length.night || Length.doppelganger => const StageClock(AppScreen.nightBoard),
  Length.talk => const StageClock(AppScreen.talk),
  Length.vote => const StageClock(AppScreen.vote),
  Length.nightMinimum => const NoClock(
    'not a clock of its own: the shortest a night window may run, folded '
    "into that window's deadline, which the night board counts",
  ),
  Length.droppedPhone => const NoClock(
    'the grace a dropped phone has to come back: the spec shows only the '
    'offline banner on that phone and no dropped-player copy to the others '
    '(first-time-play.md, sections 4 and 08); never a stage deadline in /me/',
  ),
  Length.hostAway => const NoClock(
    "how long the host may be away before the seat's duty passes: the spec "
    'hides it on purpose (no countdown on any phone); never a stage deadline '
    'in /me/',
  ),
};

/// The phase a game screen is built from: a `/me/` of another phase means
/// the shell is waiting for this one's, and shows its wait.
GamePhase? _phaseOf(AppScreen screen) => switch (screen) {
  AppScreen.join || AppScreen.table || AppScreen.deck => null,
  AppScreen.yourCard || AppScreen.nightBoard => GamePhase.night,
  AppScreen.talk => GamePhase.discussion,
  AppScreen.vote => GamePhase.voting,
  AppScreen.end => GamePhase.results,
};

/// The clocks drawn: (the widget, the seconds it shows).
Iterable<(Element, int?)> _clocks() sync* {
  for (final e in find.byType(WorldTimer).evaluate()) {
    yield (e, (e.widget as WorldTimer).secondsLeft);
  }
  for (final e in find.byType(SquareSky).evaluate()) {
    yield (e, (e.widget as SquareSky).secondsLeft);
  }
  for (final e in find.byType(TimerBand).evaluate()) {
    yield (e, (e.widget as TimerBand).secondsLeft);
  }
}

/// The `/me/` deadline of the game screen the shell shows, or null (no
/// shell, no game screen, its `/me/` not loaded or of another phase, an
/// untimed stage). The waits while `/me/` loads have none: there is no
/// deadline to count from, and none is assumed.
DateTime? shownDeadline() {
  final shells = find.byType(TableShell).evaluate();
  if (shells.isEmpty) return null;
  final container = ProviderScope.containerOf(shells.first);
  final shown = container.read(tableScreenProvider).value;
  final gameId = shown?.gameId;
  final phase = shown == null ? null : _phaseOf(shown.screen);
  if (gameId == null || phase == null) return null;
  final me = container.read(liveGameProvider(gameId)).value?.me;
  if (me == null || me.phase != phase) return null;
  return me.deadline;
}

/// The rule: what is wrong with the shown stage's clock, one line each.
List<String> stageClockProblems(WidgetTester tester, Size screen) {
  if (shownDeadline() == null) return const [];
  final counting = [
    for (final (e, seconds) in _clocks())
      if (seconds != null) e,
  ];
  if (counting.isEmpty) {
    return [
      'the stage has a deadline in /me/ and no clock counts it down '
          '(WorldTimer, SquareSky or TimerBand with its seconds)',
    ];
  }
  final problems = <String>[];
  for (final e in counting) {
    final r = ownRect(e);
    if (!onScreen(r, screen)) {
      problems.add('the clock is off the screen: ${e.widget.runtimeType} $r');
    }
  }
  // The night's candle stands among the cards: it covers none of them (04's
  // card turns over in that same frame), nor the main button. A face held
  // on the night board shows above the finger, over anything, only while
  // it is held: not a card at rest.
  final candles = find.byType(WorldTimer);
  problems.addAll(
    apartProblems(
      Apart.from('the clock and a card', candles, find.byType(FaceDownCard)),
    ),
  );
  for (final button in actingMainButtons()) {
    final b = paintedRect(button);
    for (final c in paintedRects(candles)) {
      if (liesOn(c, b)) problems.add('the clock lies on the main button');
    }
  }
  return problems;
}
