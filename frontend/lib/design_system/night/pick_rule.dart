import 'package:flutter/foundation.dart';

import 'night_pick.dart';

/// One set of cards a prompt lets a phone choose (first-time play spec,
/// section 8). From the server's prompt: `skip` is [self]; a Seer's
/// `peek_player` and `peek_center` are [onePlayer] and [twoCenter]; a
/// Robber's swap and the Doppelganger's look are [onePlayer]; the
/// Troublemaker's `swap_others` is [twoPlayers]; the Drunk's swap and a lone
/// Werewolf's look are [oneCenter]; no action at all is [anyOne].
enum PickShape {
  /// "You": deliberately doing nothing.
  self(1),
  onePlayer(1),
  oneCenter(1),
  twoCenter(2),
  twoPlayers(2),

  /// Any one card, "You" included: nothing to choose tonight.
  anyOne(1);

  const PickShape(this.size);

  /// How many cards it takes.
  final int size;

  bool _takes(NightPick pick) => switch (this) {
    self => pick is SelfPick,
    onePlayer || twoPlayers => pick is PlayerPick,
    oneCenter || twoCenter => pick is CenterPick,
    anyOne => true,
  };

  /// [picks] are this shape so far: none of the wrong kind, none too many.
  bool begunBy(List<NightPick> picks) =>
      picks.length <= size && picks.every(_takes);

  bool fits(List<NightPick> picks) => picks.length == size && begunBy(picks);
}

/// What the server's prompt lets this phone choose in one turn, as plain
/// data: the [shapes] it allows and the cards each may hold (the prompt's
/// [players] and [centers]; [PickShape.anyOne] takes every card). The phone
/// holds no rules: it compares the picks with these shapes, nothing more, so
/// a slip cannot waste a turn.
@immutable
class PickRule {
  const PickRule({
    required this.shapes,
    this.players = const {},
    this.centers = const {},
  });

  /// Nothing to choose: any one card.
  const PickRule.anyCard()
    : shapes = const {PickShape.anyOne},
      players = const {},
      centers = const {};

  final Set<PickShape> shapes;

  /// The other players' ids the prompt allows.
  final Set<int> players;

  /// The center cards (0 Left, 1 Middle, 2 Right) the prompt allows.
  final Set<int> centers;

  bool _allowed(NightPick pick) =>
      shapes.contains(PickShape.anyOne) ||
      switch (pick) {
        SelfPick() => true,
        PlayerPick(:final playerId) => players.contains(playerId),
        CenterPick(:final index) => centers.contains(index),
      };

  bool _begun(List<NightPick> picks) =>
      picks.every(_allowed) && shapes.any((s) => s.begunBy(picks));

  /// A tap on [pick] selects it: some shape can hold it.
  bool canPick(NightPick pick) => _begun([pick]);

  /// [picks] are a whole shape: Choose can send them.
  bool fits(List<NightPick> picks) =>
      picks.every(_allowed) && shapes.any((s) => s.fits(picks));

  /// [picks] after a tap on [tapped]: a chosen card is unchosen; another is
  /// added, the oldest picks given up as far as a shape needs, so the picks
  /// are always a shape or the start of one. A card no shape can hold
  /// changes nothing.
  List<NightPick> tap(List<NightPick> picks, NightPick tapped) {
    if (picks.contains(tapped)) return [...picks]..remove(tapped);
    if (!canPick(tapped)) return picks;
    for (var keep = picks.length; keep > 0; keep--) {
      final next = [...picks.sublist(picks.length - keep), tapped];
      if (_begun(next)) return next;
    }
    return [tapped];
  }
}
