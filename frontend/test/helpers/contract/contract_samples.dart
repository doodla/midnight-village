import 'dart:convert';
import 'dart:io';

/// The payloads the real server sends, recorded into `contract_samples/` at
/// the repo root by `backend/tests/contract/` (`just samples`). The backend
/// suite fails while the committed files differ from what the server sends.
///
/// Every fixture the app's tests feed through the HTTP or socket mocks starts
/// from one of these and may only change values (see `contract_shape.dart`).
abstract final class ContractSamples {
  static Directory? _dir;
  static final Map<String, String> _texts = {};
  static List<SampleInfo>? _index;

  /// `contract_samples/`, found from the working directory upwards (the
  /// package root under `flutter test`, wherever the test file is).
  static Directory get dir => _dir ??= _find();

  static Directory _find() {
    var at = Directory.current.absolute;
    while (true) {
      final candidate = Directory('${at.path}/contract_samples');
      if (File('${candidate.path}/index.json').existsSync()) return candidate;
      final parent = at.parent;
      if (parent.path == at.path) {
        throw StateError(
          'contract_samples/index.json not found above ${Directory.current.path}',
        );
      }
      at = parent;
    }
  }

  /// Every recorded sample, as listed in `index.json`.
  static List<SampleInfo> get index => _index ??= [
    for (final entry in (_decode('index') as Map)['samples'] as List)
      SampleInfo.fromJson((entry as Map).cast<String, dynamic>()),
  ];

  /// A `ws_sequence/*` sample: per seat (player name), the types of the game
  /// socket events that seat heard, in order. It is a list of event TYPES, not
  /// an event: `checkSocketEvent` does not take it.
  static Map<String, List<String>> sequence(String name) => {
    for (final e in map(name).entries)
      e.key: [for (final type in e.value as List) type as String],
  };

  /// A `ws_stream/*` sample: per seat (player name), what that phone saw in a
  /// whole game, in order: `{"event": <a game socket event>}`, `{"request":
  /// {method, path, sent}}` as one of its own requests left, and `{"answer":
  /// {method, path, status, body}}` when it was answered.
  static Map<String, List<Map<String, dynamic>>> stream(String name) => {
    for (final e in map(name).entries)
      e.key: [
        for (final item in e.value as List)
          (item as Map).cast<String, dynamic>(),
      ],
  };

  /// Every event type any seat heard in the sequence sample [name].
  static Set<String> sequenceEventTypes(String name) => {
    for (final heard in sequence(name).values) ...heard,
  };

  /// A fresh copy of sample [name] (e.g. `http/game/me_voting`), free to change.
  static dynamic load(String name) => _decode(name);

  /// [load] for a sample whose body is a JSON object.
  static Map<String, dynamic> map(String name) =>
      (_decode(name) as Map).cast<String, dynamic>();

  /// The recorded body of [method] [path] answering [status] (the first such
  /// sample), for a test that only needs "what the server answers".
  static dynamic bodyFor(String method, String path, {int status = 200}) {
    final info = index.firstWhere(
      (s) =>
          s.isHttp &&
          s.method == method &&
          s.status == status &&
          s.matchesPath(path),
      orElse: () => throw ArgumentError(
        'no sample of $method $path answering $status is recorded',
      ),
    );
    return load(info.name);
  }

  static dynamic _decode(String name) {
    final text = _texts.putIfAbsent(name, () {
      final file = File('${dir.path}/$name.json');
      if (!file.existsSync()) {
        throw ArgumentError.value(name, 'name', 'no such contract sample');
      }
      return file.readAsStringSync();
    });
    return jsonDecode(text);
  }
}

/// One entry of `index.json`: what a sample is the answer to.
class SampleInfo {
  const SampleInfo({
    required this.name,
    required this.kind,
    this.method,
    this.path,
    this.status,
    this.type,
    this.socket,
  });

  factory SampleInfo.fromJson(Map<String, dynamic> json) => SampleInfo(
    name: json['name'] as String,
    kind: json['kind'] as String,
    method: json['method'] as String?,
    path: json['path'] as String?,
    status: json['status'] as int?,
    type: json['type'] as String?,
    socket: json['socket'] as String?,
  );

  final String name;

  /// `http` (a response body), `ws` (one socket event) or `ws_sequence` (the
  /// list of event types each seat heard over a stretch of play: not an event).
  final String kind;

  /// For `http`: the request, with the app's path template
  /// (`/onuw/games/{game_id}/me/`) and the response status.
  final String? method;
  final String? path;
  final int? status;

  /// For `ws`: the event's `type`.
  final String? type;

  /// For `ws` and `ws_sequence`: the socket (`game` or `lobby`).
  final String? socket;

  bool get isHttp => kind == 'http';
  bool get isEvent => kind == 'ws';
  bool get isSequence => kind == 'ws_sequence';
  bool get isStream => kind == 'ws_stream';

  /// Whether a request for [requestPath] would be answered by this endpoint.
  bool matchesPath(String requestPath) {
    final template = path;
    if (template == null) return false;
    final pattern = RegExp(
      '^${template.split(RegExp(r'\{[a-z_]+\}')).map(RegExp.escape).join('[^/]+')}\$',
    );
    return pattern.hasMatch(requestPath);
  }
}
