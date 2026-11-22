import 'package:flutter/foundation.dart';

import 'night_pick.dart';

/// One entry of the prompt's `shapes`: `{"players": n}`, `{"center": n}` or
/// `{"any": 1}`, a set of picks the server says would do something.
@immutable
class PickShape {
  const PickShape._(this._kind, this.size);

  factory PickShape.fromJson(Map<String, dynamic> json) {
    if (json.length != 1) throw FormatException('A shape has one key', json);
    final MapEntry(:key, :value) = json.entries.single;
    final kind = switch (key) {
      'players' => _Kind.players,
      'center' => _Kind.center,
      'any' => _Kind.any,
      _ => throw FormatException('Unknown shape', json),
    };
    if (value is! int || value < 1 || value > maxPicks) {
      throw FormatException('A shape takes 1 or 2 cards', json);
    }
    return PickShape._(kind, value);
  }

  final _Kind _kind;

  /// How many cards it takes.
  final int size;

  bool _takes(NightPick pick) => switch (_kind) {
    _Kind.players => pick is PlayerPick,
    _Kind.center => pick is CenterPick,
    _Kind.any => true,
  };

  /// [picks] are this shape so far: none of the wrong kind, none too many.
  bool begunBy(List<NightPick> picks) =>
      picks.length <= size && picks.every(_takes);

  bool fits(List<NightPick> picks) => picks.length == size && begunBy(picks);
}

enum _Kind { players, center, any }

/// The most picks a choose sends.
const maxPicks = 2;

/// What the server's prompt lets this phone choose, read from it
/// ([PickRule.fromPrompt]): its `shapes`, and the cards in `valid_targets`.
/// "You" alone (doing nothing) is always a choice, for every prompt: the
/// server records it as choosing nothing and applies its own rule (a Drunk
/// still gets the seeded swap). The phone holds no rules: it compares the
/// picks with the shapes, nothing more, so a slip cannot waste a turn.
@immutable
class PickRule {
  const PickRule._({
    required this.shapes,
    required this.players,
    required this.centers,
  });

  /// `/me/`'s `action_prompt`.
  factory PickRule.fromPrompt(Map<String, dynamic> prompt) {
    final targets = prompt['valid_targets'] as Map<String, dynamic>;
    Set<int> ids(String key) => {...?(targets[key] as List?)?.cast<int>()};
    return PickRule._(
      shapes: [
        for (final shape in prompt['shapes'] as List)
          PickShape.fromJson(shape as Map<String, dynamic>),
      ],
      players: ids('player_ids'),
      centers: ids('center_indices'),
    );
  }

  final List<PickShape> shapes;

  /// The other players' ids the prompt allows.
  final Set<int> players;

  /// The center cards (0 Left, 1 Middle, 2 Right) the prompt allows.
  final Set<int> centers;

  bool _allowed(NightPick pick) => switch (pick) {
    SelfPick() => false,
    PlayerPick(:final playerId) => players.contains(playerId),
    CenterPick(:final index) => centers.contains(index),
  };

  static bool _alone(List<NightPick> picks) =>
      picks.length == 1 && picks.single is SelfPick;

  bool _begun(List<NightPick> picks) =>
      _alone(picks) ||
      picks.every(_allowed) && shapes.any((s) => s.begunBy(picks));

  /// A tap on [pick] selects it: it is "You", or some shape can hold it.
  bool canPick(NightPick pick) => _begun([pick]);

  /// [card] cannot join [picks]: tapping it would not add to the pick but
  /// replace it (a Robber's centre card, a Seer's second player). The board
  /// dims such a card. "You" is never one, a card already picked is not, and
  /// "You" alone picked leaves the pick empty. It reads the `shapes` only,
  /// so a board with `{"any": 1}` (a sleeper's) dims nothing.
  bool dims(NightPick card, List<NightPick> picks) {
    if (card is SelfPick || picks.contains(card)) return false;
    final held = _alone(picks) ? const <NightPick>[] : picks;
    return !(_allowed(card) &&
        held.every(_allowed) &&
        shapes.any((shape) => shape.begunBy([...held, card])));
  }

  /// [picks] are "You" alone or a whole shape: Choose can send them.
  bool fits(List<NightPick> picks) =>
      _alone(picks) ||
      picks.every(_allowed) && shapes.any((s) => s.fits(picks));

  /// [picks] after a tap on [tapped]: a chosen card is unchosen; another is
  /// added, the oldest picks given up as far as a shape needs, so the picks
  /// are always "You", a shape or the start of one. A card no shape can hold
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
