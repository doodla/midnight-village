import '../../../design_system/copy/copy.dart';
import '../../../design_system/models/game_result.dart';
import '../../../design_system/models/role.dart';
import 'game_outcome.dart';
import 'outcome_view.dart';

// The end board's banner: two sentences, who was hanged and what it means for
// THIS player, from the results body and who "you" are (the results do not
// say). Pure Dart: the widget breaks the words into lines (`BannerSlice`),
// this only says which sentences, longest first, and which paper.
//
// Shortened by rule, never by cutting a name: the whole sentence; the second
// part short ("You win." / "You lose."); the first part as a count ("Three
// hanged."), the second whole; both short. A player's name is only ever whole
// or left out of the sentence (the tags and ribbons on the board say who).

/// What the banner says, and on which paper.
class EndBanner {
  const EndBanner({required this.forms, required this.red});

  /// The whole sentence first, each next one shorter; never empty.
  final List<String> forms;

  /// Red paper: the Werewolf team won, or the Tanner did (and the village did
  /// not). Never because this player lost.
  final bool red;

  /// The sentence a screen reader says.
  String get spoken => forms.first;
}

/// The banner for the viewer [viewerId] of [outcome].
EndBanner endBannerOf(GameOutcome outcome, int viewerId) {
  final seats = endSeatsOf(outcome);
  final deaths = deathsOf(seats);
  final you = seats.where((s) => s.seat.id == viewerId).firstOrNull;
  final teams = outcome.result.winningTeams;

  final first = _hanged(deaths);
  final count = _count(deaths);
  final second = _you(you, teams);
  final short = you == null
      ? second
      : (you.won ? EndCopy.youWinShort : EndCopy.youLoseShort);
  final forms = <String>[];
  for (final (a, b) in [
    (first, second),
    (first, short),
    (count, second),
    (count, short),
  ]) {
    final form = '$a $b';
    if (!forms.contains(form)) forms.add(form);
  }
  return EndBanner(forms: forms, red: _isRed(teams));
}

/// Red for the Werewolf team, and for the Tanner when the village did not
/// win too.
bool _isRed(List<TeamId> winners) =>
    winners.contains(TeamId.werewolf) ||
    (winners.contains(TeamId.independent) && !winners.contains(TeamId.village));

/// Who died, in the order they died: the vote's dead in seat order, then the
/// Hunter's pick.
class Deaths {
  const Deaths(this.voted, this.chosen);

  final List<EndSeat> voted;
  final List<EndSeat> chosen;

  bool get nobody => voted.isEmpty && chosen.isEmpty;
  List<EndSeat> get all => [...voted, ...chosen];
}

Deaths deathsOf(List<EndSeat> seats) => Deaths(
  [
    for (final s in seats)
      if (s.diedBy == EliminationReason.vote) s,
  ],
  [
    for (final s in seats)
      if (s.diedBy == EliminationReason.hunterChain) s,
  ],
);

String _hanged(Deaths deaths) {
  if (deaths.nobody) return EndCopy.nobodyHanged;
  final names = _join([for (final s in deaths.voted) s.seat.name]);
  if (deaths.voted.isEmpty) {
    return EndCopy.hanged.fill({'names': names});
  }
  if (deaths.chosen.isEmpty) return EndCopy.hanged.fill({'names': names});
  return EndCopy.hangedToo.fill({
    'names': names,
    'chosen': _join([for (final s in deaths.chosen) s.seat.name]),
  });
}

String _count(Deaths deaths) {
  final n = deaths.all.length;
  if (n == 0) return EndCopy.nobodyHanged;
  return EndCopy.hangedCount.fill({'n': n});
}

String _you(EndSeat? you, List<TeamId> winners) {
  if (winners.isEmpty) return EndCopy.nobodyWins;
  if (you != null && you.won) {
    return switch (you.team) {
      TeamId.village => EndCopy.youWinVillage,
      TeamId.werewolf => EndCopy.youWinWerewolves,
      TeamId.independent => EndCopy.youWinAlone,
    };
  }
  return switch (winners.first) {
    TeamId.village => EndCopy.youLoseVillage,
    TeamId.werewolf => EndCopy.youLoseWerewolves,
    TeamId.independent => EndCopy.youLoseTanner,
  };
}

/// "Ana", "Ana and Ben", "Ana, Ben and Cleo".
String _join(List<String> names) => names.length < 2
    ? names.join()
    : EndCopy.andThen.fill({
        'first': names.sublist(0, names.length - 1).join(EndCopy.listComma),
        'last': names.last,
      });
