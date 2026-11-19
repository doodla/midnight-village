import 'dart:convert';

import 'contract_samples.dart';

/// The guard that keeps test fixtures to what the server can send.
///
/// For one endpoint (method, path, status) or socket event type, the *shape*
/// is taken from every recorded sample of it:
/// - the key paths that occur and the JSON types seen at each
///   (`players[].player_id: int`, `deadline: string|null`), and
/// - the keys present in every sample object at a path (always sent).
///
/// A payload is on contract when every key path it has occurs in the samples
/// with a type seen there, and it has every always-sent key. So a test cannot
/// invent a key, change a type, nest what the server sends flat, or leave out
/// a key the server always sends. It does NOT catch: a key sent only in some
/// situations (phase, role) used in another one, values (casing of role names,
/// window numbers; the builders take care of those), or the order of events.
///
/// Dictionary objects (data as keys: role names in `settings.roles`, player
/// ids in `votes`) have their keys collapsed to `*`.
class ContractShape {
  ContractShape._(this._types, this._required);

  factory ContractShape.of(Iterable<dynamic> samples) {
    final types = <String, Set<String>>{};
    final required = <String, Set<String>>{};
    void walk(dynamic value, String path) {
      (types[path] ??= {}).add(_typeOf(value));
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
    return ContractShape._(types, required);
  }

  final Map<String, Set<String>> _types;
  final Map<String, Set<String>> _required;

  /// What is wrong with [payload], one line per problem (empty when on
  /// contract).
  List<String> violations(dynamic payload) {
    final problems = <String>[];
    void walk(dynamic value, String path) {
      final at = path.isEmpty ? '(root)' : path;
      final seen = _types[path];
      if (seen == null) {
        problems.add('$at: the server never sends this key');
        return;
      }
      final type = _typeOf(value);
      if (!seen.contains(type)) {
        problems.add('$at: is $type, the server sends ${seen.join('|')}');
        return;
      }
      if (value is Map) {
        final keys = {for (final k in value.keys) _key(path, k as String)};
        for (final missing in (_required[path] ?? const {}).difference(keys)) {
          problems.add('${_child(path, missing)}: always sent, missing here');
        }
        value.forEach((k, v) => walk(v, _child(path, _key(path, k as String))));
      } else if (value is List) {
        for (final v in value) {
          walk(v, '$path[]');
        }
      }
    }

    walk(_plain(payload), '');
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
  static dynamic _plain(dynamic payload) =>
      payload is String && (payload.startsWith('{') || payload.startsWith('['))
      ? jsonDecode(payload)
      : payload;
}

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

ContractShape _shapeOf(String key, Iterable<SampleInfo> samples) =>
    _shapes[key] ??= ContractShape.of(
      samples.map((s) => ContractSamples.load(s.name)),
    );

/// Throws [OffContractPayload] unless [body] could be the server's response
/// to [method] [path] with [status]. A 4xx with no sample for that endpoint is
/// checked against every recorded error body; a 5xx body is not checked (the
/// server's are not JSON).
void checkHttpBody(String method, String path, int status, dynamic body) {
  if (status >= 500) return;
  final http = ContractSamples.index.where((s) => s.isHttp);
  var samples = http
      .where(
        (s) =>
            s.method == method.toUpperCase() &&
            s.status == status &&
            s.matchesPath(path),
      )
      .toList();
  var key = '${method.toUpperCase()} $path $status';
  if (samples.isEmpty && status >= 400) {
    samples = http.where((s) => s.status! >= 400).toList();
    key = 'any error';
  }
  final what = '${method.toUpperCase()} $path -> $status';
  if (samples.isEmpty) {
    throw OffContractPayload(what, ['no sample of this response is recorded']);
  }
  // Key by the samples, not the request: two ids share one endpoint.
  final problems = _shapeOf(
    samples.map((s) => s.name).join(','),
    samples,
  ).violations(body);
  if (problems.isNotEmpty) throw OffContractPayload('$what ($key)', problems);
}

/// Throws [OffContractPayload] unless [event] (a map, or its JSON encoding)
/// could be a socket event the server sends.
void checkSocketEvent(dynamic event) {
  final decoded = ContractShape._plain(event);
  final type = decoded is Map ? decoded['type'] : null;
  final samples = ContractSamples.index
      .where((s) => s.kind == 'ws' && s.type == type)
      .toList();
  if (samples.isEmpty) {
    throw OffContractPayload('socket event $type', [
      'the server never sends an event of this type',
    ]);
  }
  final problems = _shapeOf('ws:$type', samples).violations(decoded);
  if (problems.isNotEmpty) {
    throw OffContractPayload('socket event $type', problems);
  }
}
