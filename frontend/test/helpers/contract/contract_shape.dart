import 'dart:convert';

import 'contract_samples.dart';

/// The guard that keeps test fixtures to what the server can send.
///
/// The *shape* of a payload is taken from recorded samples of the same thing:
/// - the key paths that occur and the JSON types seen at each
///   (`players[].player_id: int`, `deadline: string|null`), and
/// - the keys present in every sample object at a path (always sent).
///
/// A payload is on contract when every key path it has occurs in the samples
/// with a type seen there, and it has every always-sent key. So a test cannot
/// invent a key, change a type, nest what the server sends flat, or leave out
/// a key the server always sends.
///
/// Variants, not a union: where one endpoint or event sends different shapes
/// by situation, only the samples of the payload's own situation count (its
/// [Variant] discriminator: the `phase` of a `/me/` or a `phase_change`, the
/// `role_acting_as` of a prompt, the kind of a night result). A key the server
/// sends only at night is refused in a discussion `/me/`. When no sample has
/// the payload's discriminator value, every sample of the endpoint counts.
/// Still not checked: values (casing of role names, window numbers; the
/// builders take care of those) and the order of events.
///
/// Dictionary objects (data as keys: role names in `settings.roles`, player
/// ids in `votes`) have their keys collapsed to `*`.
class ContractShape {
  ContractShape._(this._types, this._required, this._opaque);

  /// The shape of [samples]; the subtrees at [opaque] paths are left out
  /// (only their own type is kept): a [Variant] checks them on their own.
  factory ContractShape.of(
    Iterable<dynamic> samples, {
    Set<String> opaque = const {},
  }) {
    final types = <String, Set<String>>{};
    final required = <String, Set<String>>{};
    void walk(dynamic value, String path) {
      (types[path] ??= {}).add(_typeOf(value));
      if (opaque.contains(path)) return;
      if (value is Map) {
        final keys = {for (final k in value.keys) _key(path, k as String)};
        required[path] = required[path]?.intersection(keys) ?? keys;
        value.forEach((k, v) => walk(v, _child(path, _key(path, k as String))));
      } else if (value is List) {
        for (final v in value) {
          walk(v, '$path[]');
        }
      }
    }

    for (final sample in samples) {
      walk(sample, '');
    }
    return ContractShape._(types, required, opaque);
  }

  final Map<String, Set<String>> _types;
  final Map<String, Set<String>> _required;
  final Set<String> _opaque;

  /// What is wrong with [payload], one line per problem (empty when on
  /// contract). [at] prefixes the paths in the messages.
  List<String> violations(dynamic payload, {String at = ''}) {
    final problems = <String>[];
    void walk(dynamic value, String path) {
      final where = _child(at, path.isEmpty ? '(root)' : path);
      final seen = _types[path];
      if (seen == null) {
        problems.add('$where: the server never sends this key here');
        return;
      }
      final type = _typeOf(value);
      if (!seen.contains(type)) {
        problems.add('$where: is $type, the server sends ${seen.join('|')}');
        return;
      }
      if (_opaque.contains(path)) return;
      if (value is Map) {
        final keys = {for (final k in value.keys) _key(path, k as String)};
        for (final missing in (_required[path] ?? const {}).difference(keys)) {
          problems.add(
            '${_child(at, _child(path, missing))}: always sent, missing here',
          );
        }
        value.forEach((k, v) => walk(v, _child(path, _key(path, k as String))));
      } else if (value is List) {
        for (final v in value) {
          walk(v, '$path[]');
        }
      }
    }

    walk(plain(payload), '');
    return problems;
  }

  static String _child(String path, String key) =>
      path.isEmpty ? key : '$path.$key';

  static final _digits = RegExp(r'^\d+$');
  static const _dictionaries = ['settings.roles'];

  static String _key(String parent, String key) =>
      _digits.hasMatch(key) || _dictionaries.any((d) => parent.endsWith(d))
      ? '*'
      : key;

  static String _typeOf(dynamic v) => switch (v) {
    null => 'null',
    bool() => 'bool',
    int() => 'int',
    double() => 'double',
    String() => 'string',
    List() => 'list',
    Map() => 'map',
    _ => 'unsupported ${v.runtimeType}',
  };

  /// A JSON-encoded string is checked as the value it encodes.
  static dynamic plain(dynamic payload) =>
      payload is String && (payload.startsWith('{') || payload.startsWith('['))
      ? jsonDecode(payload)
      : payload;
}

/// How one kind of payload varies: [discriminator] names the situation of a
/// payload (or of the subtree at a path), and the subtrees at the paths in
/// [parts] vary on their own.
class Variant {
  const Variant(this.discriminator, {this.parts = const {}});

  /// The situation's name, or null when the payload does not say.
  final String? Function(dynamic payload) discriminator;

  /// Path of a subtree (`action_prompt`, `night_results[]`) -> its variant.
  final Map<String, Variant> parts;
}

String? _field(dynamic payload, String key) =>
    payload is Map ? payload[key]?.toString() : null;

/// A night result's kind: its action, and for a team view whose team.
String? _resultKind(dynamic result) {
  final action = _field(result, 'action_type');
  if (action != 'see_team') return action;
  final info = result is Map ? result['revealed_info'] : null;
  return 'see_team:${_field(info, 'role_acting_as')}';
}

const _prompt = Variant(_promptKind);
String? _promptKind(dynamic prompt) => _field(prompt, 'role_acting_as');
const _result = Variant(_resultKind);
String? _phase(dynamic payload) => _field(payload, 'phase');

/// The variants of the server's payloads, by endpoint path or event type.
const _httpVariants = {
  '/onuw/games/{game_id}/me/': Variant(
    _phase,
    parts: {'action_prompt': _prompt, 'night_results[]': _result},
  ),
};
const _socketVariants = {
  'phase_change': Variant(_phase),
  'action_prompt': _prompt,
  'action_result': _result,
};

/// A payload a test fed to a mock is not something the server sends.
class OffContractPayload implements Exception {
  OffContractPayload(this.what, this.problems);

  final String what;
  final List<String> problems;

  @override
  String toString() =>
      'OffContractPayload: $what does not match what the server sends '
      '(contract_samples/):\n  ${problems.join('\n  ')}\n'
      'Build the fixture from a sample (test/helpers/contract/), or, for a '
      'test about malformed input, mark it off contract explicitly.';
}

final _shapes = <String, ContractShape>{};
final _pools = <String, List<dynamic>>{};

/// The decoded samples named [infos], kept for the run.
List<dynamic> _samplesOf(String key, List<SampleInfo> infos) =>
    _pools[key] ??= [for (final s in infos) ContractSamples.load(s.name)];

/// Every value at [path] (`a.b`, `list[]`) in [value].
Iterable<dynamic> _at(dynamic value, String path) sync* {
  if (path.isEmpty) {
    yield value;
    return;
  }
  final dot = path.indexOf('.');
  final head = dot < 0 ? path : path.substring(0, dot);
  final rest = dot < 0 ? '' : path.substring(dot + 1);
  final isList = head.endsWith('[]');
  final key = isList ? head.substring(0, head.length - 2) : head;
  if (value is! Map || !value.containsKey(key)) return;
  final child = value[key];
  if (isList) {
    if (child is! List) return;
    for (final item in child) {
      yield* _at(item, rest);
    }
  } else {
    yield* _at(child, rest);
  }
}

/// The problems of [payload] against [samples] (their own [variant] of it).
List<String> _check(
  String key,
  List<dynamic> samples,
  dynamic payload,
  Variant? variant, {
  String at = '',
}) {
  var own = samples;
  var ownKey = key;
  if (variant != null) {
    final situation = variant.discriminator(payload);
    final same = [
      for (final s in samples)
        if (variant.discriminator(s) == situation) s,
    ];
    if (situation != null && same.isNotEmpty) {
      own = same;
      ownKey = '$key[$situation]';
    }
  }
  final parts = variant?.parts ?? const <String, Variant>{};
  final shape = _shapes[ownKey] ??= ContractShape.of(
    own,
    opaque: parts.keys.toSet(),
  );
  final problems = shape.violations(payload, at: at);
  // A part is checked against the same part of EVERY sample of the endpoint:
  // a discussion `/me/`'s night results are the night's results.
  for (final MapEntry(key: path, value: part) in parts.entries) {
    final pool = _pools['$key>$path'] ??= [
      for (final s in samples)
        for (final v in _at(s, path))
          if (v != null) v,
    ];
    for (final value in _at(payload, path)) {
      if (value == null) continue;
      problems.addAll(
        _check('$key>$path', pool, value, part, at: _joined(at, path)),
      );
    }
  }
  return problems;
}

String _joined(String at, String path) => at.isEmpty ? path : '$at.$path';

/// Throws [OffContractPayload] unless [body] could be the server's response
/// to [method] [path] with [status]: there must be a recorded sample of that
/// endpoint answering that status (errors too). A 5xx body is not checked
/// (the server's are not JSON).
void checkHttpBody(String method, String path, int status, dynamic body) {
  if (status >= 500) return;
  final verb = method.toUpperCase();
  final infos = ContractSamples.index
      .where(
        (s) =>
            s.isHttp &&
            s.method == verb &&
            s.status == status &&
            s.matchesPath(path),
      )
      .toList();
  final what = '$verb $path -> $status';
  if (infos.isEmpty) {
    throw OffContractPayload(what, [
      'no sample of this endpoint answering $status is recorded '
          '(record one in backend/tests/contract/scenarios.py)',
    ]);
  }
  final key = infos.map((s) => s.name).join(',');
  final problems = _check(
    key,
    _samplesOf(key, infos),
    ContractShape.plain(body),
    _httpVariants[infos.first.path],
  );
  if (problems.isNotEmpty) throw OffContractPayload(what, problems);
}

/// Throws [OffContractPayload] unless [event] (a map, or its JSON encoding)
/// could be a socket event the server sends.
void checkSocketEvent(dynamic event) {
  final decoded = ContractShape.plain(event);
  final type = decoded is Map ? decoded['type'] : null;
  final infos = ContractSamples.index
      .where((s) => s.kind == 'ws' && s.type == type)
      .toList();
  if (infos.isEmpty) {
    throw OffContractPayload('socket event $type', [
      'the server never sends an event of this type',
    ]);
  }
  final problems = _check(
    'ws:$type',
    _samplesOf('ws:$type', infos),
    decoded,
    _socketVariants[type],
  );
  if (problems.isNotEmpty) {
    throw OffContractPayload('socket event $type', problems);
  }
}
