import 'package:flutter/material.dart';
import 'package:midnight_village/features/game/domain/outcome_view.dart';
import 'package:midnight_village/features/game/presentation/shell/count_screen.dart';
import 'package:midnight_village/features/game/presentation/shell/results_screen.dart';

import '../outcome_samples.dart';
import 'sheet_data.dart';

// 10 The count and 11 Results on the component sheet: the screens' own views
// (CountView, ResultsView) fed by a results body (test/helpers/
// outcome_samples.dart), so the sheet's contrast, amber and fit sweeps
// measure the real thing. No recorded game ends game 7 (a recorder gap), so
// these pages are the `results` game unless they say: Ana the Seer, Ben the
// Robber, Cleo and Esme the Werewolves, Dev the Troublemaker, Fin the Hunter.

/// Which results body a page shows.
enum EndGame {
  /// Fin, the Hunter, is voted out and takes Esme: the village wins.
  hunter,

  /// Derived: Ana's card moved; she dies; the Werewolves win.
  werewolves,

  /// Derived: nobody dies; the Werewolves win.
  nobody,

  /// The Tanner is voted out and wins alone.
  tanner,

  /// Ten at the table with long names (the Doppelganger's game, widened).
  tenLong;

  Map<String, dynamic> get body => switch (this) {
    hunter => recordedResults('results'),
    werewolves => derivedWerewolvesWin(),
    nobody => derivedNobodyDies(),
    tanner => recordedResults('results_tanner'),
    tenLong => widened(
      recordedResults('results_doppelganger'),
      add: 2,
      rename: longEndNames,
    ),
  };

  /// The host's name at that table.
  String get host => this == tenLong ? 'Christopher' : 'Ana';
}

/// [viewer]'s seat at the end of [game]: the player of the same name where
/// the game has one (Ana the Seer, Ben the Robber), else the host. The
/// sleeper (game 7's Esme, a Villager) is Fin, the Hunter: the `results`
/// game has no Villager, and its Esme is a Werewolf, which would tell a cold
/// reader they had been one.
int endViewerId(EndGame game, Viewer viewer) {
  final outcome = outcomeOf(game.body);
  final name = switch (viewer) {
    Viewer.seer => ana.name,
    Viewer.robber => ben.name,
    Viewer.villager => 'Fin',
    _ => game.host,
  };
  return (outcome.seats.where((s) => s.name == name).firstOrNull ??
          outcome.seats.firstWhere((s) => s.name == game.host))
      .id;
}

/// 10, run to its end (the rows landed, the card turned).
class CountPage extends StatelessWidget {
  const CountPage({super.key, this.game = EndGame.hunter});

  final EndGame game;

  @override
  Widget build(BuildContext context) => MediaQuery(
    // The sheet shows the screen as it rests, not mid-motion.
    data: MediaQuery.of(context).copyWith(disableAnimations: true),
    child: CountView(
      count: TheCount.of(outcomeOf(game.body)),
      onSeeWhoWon: () {},
    ),
  );
}

/// 11 on [viewer]'s phone: the host's buttons, or a guest's line and
/// "Leave"; [nightOpen] with the night unfolded.
class ResultsPage extends StatelessWidget {
  const ResultsPage({
    super.key,
    required this.viewer,
    this.game = EndGame.hunter,
    this.guest = false,
    this.nightOpen = false,
  });

  final Viewer viewer;
  final EndGame game;
  final bool guest;
  final bool nightOpen;

  @override
  Widget build(BuildContext context) => ResultsView(
    outcome: outcomeOf(game.body),
    viewerId: endViewerId(game, viewer),
    hostName: guest ? game.host : null,
    nightOpen: nightOpen,
    onPlayAgain: () {},
    onEditDeck: () {},
    onLeave: () {},
    onTryAgain: () {},
  );
}
