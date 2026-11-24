import 'package:flutter/foundation.dart';

import '../copy/copy.dart';
import '../copy/template.dart';
import '../faces/face_content.dart';
import '../faces/night_report.dart';
import '../models/role.dart';

// A night as a picture story (08's My night, held; the end board's "What
// happened" can draw its own from the results): rows of cards, your own on
// top; threads between them; one sentence. A face-up card is one its
// player saw, a face-down card one they did not. Nothing here is about a
// screen: sizes and paper are the view's (`night_story_view.dart`).

/// Who held a card of a story, as its tab says it.
enum StoryWho {
  /// This phone's own card, as dealt.
  you,

  /// Another player's card.
  player,

  /// A center card (Left, Middle, Right).
  center,

  /// This phone's own card at the end of the night (the Insomniac's look).
  now,
}

/// One card of a story: whose, its tab's words, and its role when it was
/// seen (null: face down).
@immutable
class StoryCard {
  const StoryCard._(this.who, this.label, this.role);

  final StoryWho who;

  /// The tab's words: "You", a player's name, "Left", "Now".
  final String label;

  /// The role shown face up; null for a card not seen.
  final RoleId? role;

  bool get faceUp => role != null;

  /// What a screen reader hears of it.
  String get spoken => role == null
      ? NightStoryCopy.cardDown.fill({'who': label})
      : NightStoryCopy.cardUp.fill({'who': label, 'role': role!.displayName});

  @override
  bool operator ==(Object other) =>
      other is StoryCard &&
      other.who == who &&
      other.label == label &&
      other.role == role;

  @override
  int get hashCode => Object.hash(who, label, role);

  @override
  String toString() => '$label:${role?.name ?? 'down'}';
}

/// A card's place in a story: its row (0 is your own's) and its place in it.
typedef StoryRef = ({int row, int col});

/// What a thread says. A [look] is gapped with a head at the card looked at;
/// [see] is gapped with no head (a team saw each other); a [swap] is two
/// solid threads with a head each (the cards traded places); [act] is a
/// solid thread from your card to the middle of a swap between two other
/// cards ([StoryLink.pair]): you swapped them.
enum StoryLinkKind { look, see, swap, act }

@immutable
class StoryLink {
  const StoryLink._(this.kind, this.from, this.to, [this.pair]);

  final StoryLinkKind kind;
  final StoryRef from;
  final StoryRef to;

  /// For [StoryLinkKind.act]: the other card of the swap [to] is in.
  final StoryRef? pair;

  /// A gapped thread (a look), else a solid one (a move).
  bool get gapped => kind == StoryLinkKind.look || kind == StoryLinkKind.see;

  @override
  bool operator ==(Object other) =>
      other is StoryLink &&
      other.kind == kind &&
      other.from == from &&
      other.to == to &&
      other.pair == pair;

  @override
  int get hashCode => Object.hash(kind, from, to, pair);

  @override
  String toString() {
    String at(StoryRef r) => '${r.row}.${r.col}';
    return '${kind.name} ${at(from)}>${at(to)}'
        '${pair == null ? '' : '+${at(pair!)}'}';
  }
}

/// The one sentence: its words in order, each marked when it is a name (set
/// in the names' face). [text] is the whole sentence.
@immutable
class StoryLine {
  StoryLine._(Object line, [Map<String, Object> values = const {}])
    : parts = _parts(line, values);

  final List<({String text, bool name})> parts;

  String get text => parts.map((p) => p.text).join();

  @override
  bool operator ==(Object other) =>
      other is StoryLine && listEquals(other.parts, parts);

  @override
  int get hashCode => Object.hashAll(parts);

  static final _gap = RegExp(r'\{(\w+)\}');

  /// The gaps that hold names; any other gap holds plain words (a role).
  static const _names = {'name', 'names', 'a', 'b', 'copied'};

  static List<({String text, bool name})> _parts(
    Object line,
    Map<String, Object> values,
  ) {
    final raw = line is Template ? line.raw : line as String;
    assert(
      line is! Template || setEquals(values.keys.toSet(), line.gaps.toSet()),
      '"$raw" fills its gaps',
    );
    final out = <({String text, bool name})>[];
    void plain(String s) {
      if (s.isNotEmpty) out.add((text: s, name: false));
    }

    var at = 0;
    for (final m in _gap.allMatches(raw)) {
      plain(raw.substring(at, m.start));
      final key = m[1]!;
      final value = values[key]!;
      if (!_names.contains(key)) {
        plain('$value');
      } else if (value is List<String>) {
        // "Ana", "Ana and Ben", "Ana, Ben and Cleo".
        for (final (i, n) in value.indexed) {
          if (i > 0) {
            plain(i == value.length - 1 ? ' ${NightStoryCopy.and} ' : ', ');
          }
          out.add((text: n, name: true));
        }
      } else {
        out.add((text: '$value', name: true));
      }
      at = m.end;
    }
    plain(raw.substring(at));
    return out;
  }
}

/// A night told as a picture: [rows] of cards, your own first; [links]
/// between them; [sleeps] when nothing moved and nothing was seen (the
/// sleeping village under your card); [line], the one sentence.
@immutable
class NightStory {
  const NightStory._({
    required this.rows,
    required this.links,
    required this.line,
    this.sleeps = false,
  });

  final List<List<StoryCard>> rows;
  final List<StoryLink> links;
  final StoryLine line;
  final bool sleeps;

  /// This phone's own card.
  static const youRef = (row: 0, col: 0);

  StoryCard cardAt(StoryRef ref) => rows[ref.row][ref.col];

  /// By value: the same night told twice is one story (so a view keeps its
  /// layout for it).
  @override
  bool operator ==(Object other) =>
      other is NightStory &&
      other.sleeps == sleeps &&
      other.line == line &&
      listEquals(other.links, links) &&
      other.rows.length == rows.length &&
      [for (var i = 0; i < rows.length; i++) listEquals(other.rows[i], rows[i])]
          .every((same) => same);

  @override
  int get hashCode => Object.hash(
    sleeps,
    line,
    Object.hashAll(links),
    Object.hashAll(rows.map(Object.hashAll)),
  );

  /// What a screen reader hears: the sentence, then every card.
  String get spoken => [
    line.text,
    for (final row in rows)
      for (final card in row) card.spoken,
  ].join(' ');

  /// This phone's night, from its own record only (`/me/`'s `night_results`
  /// as [NightReport] reads them): what it did and saw, never what was done
  /// to it. A Doppelganger's copy is the first row beside her card.
  factory NightStory.of(NightReport report) {
    final you = StoryCard._(StoryWho.you, NightCopy.you, report.dealt);
    final saw = report.saw ?? SleptResult.none;
    return switch (report.windowOne) {
      final CopiedResult copy => _copied(you, copy, saw),
      WindowOneDidNothing() => _story(you, const [], _Piece.didNothing),
      _ => _story(you, const [], _Piece.of(saw, report.dealt, base: 1)),
    };
  }

  static NightStory _story(StoryCard you, List<StoryCard> beside, _Piece p) =>
      NightStory._(
        rows: [
          [you, ...beside],
          ...p.rows,
        ],
        links: [...p.links],
        line: p.line,
        sleeps: p.sleeps,
      );

  static NightStory _copied(StoryCard you, CopiedResult copy, NightResult saw) {
    final copied = StoryCard._(StoryWho.player, copy.name, copy.role);
    final look = StoryLink._(StoryLinkKind.look, youRef, (row: 0, col: 1));
    final then = copy.followUp;
    final tells = switch (saw) {
      SleptResult() || DidNothingResult() => false,
      _ => true,
    };
    final picture = then != null
        ? _Piece.of(then, you.role!, base: 1)
        : tells
        ? _Piece.of(saw, you.role!, base: 1)
        : null;
    final c = {'copied': copy.name};
    final line = switch (then) {
      SeerPlayerResult(:final name) => StoryLine._(NightStoryCopy.copiedSaw, {
        ...c,
        'name': name,
      }),
      SeerCenterResult() => StoryLine._(NightStoryCopy.copiedCenter, c),
      RobbedResult(:final name) => StoryLine._(NightStoryCopy.copiedTook, {
        ...c,
        'name': name,
      }),
      SwappedResult(:final a, :final b) => StoryLine._(
        NightStoryCopy.copiedSwapped,
        {...c, 'a': a, 'b': b},
      ),
      DrunkResult(:final center) => StoryLine._(NightStoryCopy.copiedDrunk, {
        ...c,
        'pos': centerName(center).toLowerCase(),
      }),
      MinionResult(:final names) => StoryLine._(
        names.isEmpty ? NightStoryCopy.copiedNone : NightStoryCopy.copiedMinion,
        c,
      ),
      DidNothingResult() => StoryLine._(NightStoryCopy.copiedNothing, c),
      _ => StoryLine._(NightStoryCopy.copied, {
        ...c,
        'role': copy.role.displayName,
      }),
    };
    return NightStory._(
      rows: [
        [you, copied],
        ...?picture?.rows,
      ],
      links: [look, ...?picture?.links],
      line: line,
    );
  }
}

/// What one result adds under your card: its rows (from row [base]), the
/// threads from your card, and its own sentence.
class _Piece {
  const _Piece(this.rows, this.links, this.line, {this.sleeps = false});

  final List<List<StoryCard>> rows;
  final List<StoryLink> links;
  final StoryLine line;
  final bool sleeps;

  static final didNothing = _Piece(
    const [],
    const [],
    StoryLine._(SawCopy.didNothing),
    sleeps: true,
  );

  static StoryCard _player(String name, [RoleId? role]) =>
      StoryCard._(StoryWho.player, name, role);

  static List<StoryCard> _center([Map<int, RoleId> seen = const {}]) => [
    for (var i = 0; i < NightCopy.center.length; i++)
      StoryCard._(StoryWho.center, centerName(i), seen[i]),
  ];

  static StoryLink _link(StoryLinkKind kind, int base, int col) =>
      StoryLink._(kind, NightStory.youRef, (row: base, col: col));

  /// [result] as a piece; [dealt] is your card as dealt (the Insomniac's
  /// "still").
  static _Piece of(NightResult result, RoleId dealt, {required int base}) {
    List<StoryLink> each(StoryLinkKind kind, int n) => [
      for (var i = 0; i < n; i++) _link(kind, base, i),
    ];
    return switch (result) {
      SeerPlayerResult(:final name, :final role) => _Piece(
        [
          [_player(name, role)],
        ],
        each(StoryLinkKind.look, 1),
        StoryLine._(NightStoryCopy.seerPlayer, {
          'name': name,
          'role': role.displayName,
        }),
      ),
      SeerCenterResult(:final cards) => _Piece(
        [
          _center({for (final (i, role) in cards) i: role}),
        ],
        [for (final (i, _) in cards) _link(StoryLinkKind.look, base, i)],
        StoryLine._(NightStoryCopy.seerCenter),
      ),
      RobbedResult(:final name, :final role) => _Piece(
        [
          [_player(name, role)],
        ],
        each(StoryLinkKind.swap, 1),
        StoryLine._(NightStoryCopy.robbed, {
          'name': name,
          'role': role.displayName,
        }),
      ),
      NewCardResult(:final role) => _Piece(
        [
          [StoryCard._(StoryWho.now, NightStoryCopy.nowCard, role)],
        ],
        each(StoryLinkKind.look, 1),
        StoryLine._(role == dealt ? NightStoryCopy.still : NightStoryCopy.now, {
          'role': role.displayName,
        }),
      ),
      SwappedResult(:final a, :final b) => _Piece(
        [
          [_player(a), _player(b)],
        ],
        [
          StoryLink._(
            StoryLinkKind.act,
            NightStory.youRef,
            (row: base, col: 0),
            (row: base, col: 1),
          ),
          StoryLink._(
            StoryLinkKind.swap,
            (row: base, col: 0),
            (row: base, col: 1),
          ),
        ],
        StoryLine._(SawCopy.swapped, {'a': a, 'b': b}),
      ),
      DrunkResult(:final center) => _Piece(
        [_center()],
        [_link(StoryLinkKind.swap, base, center)],
        StoryLine._(NightStoryCopy.drunk, {
          'pos': centerName(center).toLowerCase(),
        }),
      ),
      WerewolvesResult(:final names) => _Piece(
        [
          [for (final n in names) _player(n, RoleId.werewolf)],
        ],
        each(StoryLinkKind.see, names.length),
        StoryLine._(NightStoryCopy.werewolves, {'names': names}),
      ),
      LoneWerewolfResult(:final look) => _Piece(
        [
          if (look case (final i, final role)) _center({i: role}),
        ],
        [if (look case (final i, _)) _link(StoryLinkKind.look, base, i)],
        StoryLine._(NightStoryCopy.onlyWerewolf),
      ),
      MinionResult(:final names) when names.isEmpty => _Piece(
        const [],
        const [],
        StoryLine._(SawCopy.noWerewolves),
      ),
      MinionResult(:final names) => _Piece(
        [
          [for (final n in names) _player(n, RoleId.werewolf)],
        ],
        each(StoryLinkKind.look, names.length),
        StoryLine._(
          names.length == 1 ? NightStoryCopy.minionOne : NightStoryCopy.minion,
          {'names': names},
        ),
      ),
      MasonsResult(:final names) when names.isEmpty => _Piece(
        const [],
        const [],
        StoryLine._(NightStoryCopy.onlyMason),
      ),
      MasonsResult(:final names) => _Piece(
        [
          [for (final n in names) _player(n, RoleId.mason)],
        ],
        each(StoryLinkKind.see, names.length),
        StoryLine._(NightStoryCopy.masons, {'names': names}),
      ),
      DidNothingResult() => didNothing,
      SleptResult() => _Piece(
        const [],
        const [],
        StoryLine._(NightCopy.slept),
        sleeps: true,
      ),
    };
  }
}
