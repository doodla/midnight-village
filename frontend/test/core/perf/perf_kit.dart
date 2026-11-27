import 'dart:io';

import 'package:dio/dio.dart';
import 'package:midnight_village/core/perf/field_recorder.dart';

/// One request as the tests make it: the gap before it, its round trip and
/// the server's own `Server-Timing` (`total`, `connect`), in ms.
typedef Asked = ({double gap, double round, double total, double connect});

/// A poll, then a read made as its answer came (an `event`, not a poll).
const pollThenEvent = <Asked>[
  (gap: 0.0, round: 100.0, total: 50.0, connect: 10.0),
  (gap: 0.0, round: 100.0, total: 50.0, connect: 10.0),
];

String gameMe(int i) => 'https://api.example/api/onuw/games/7/me/';

/// A recorder with requests made on a clock the test moves.
Future<FieldRecorder> recorderWithRequests(
  List<Asked> asked, {
  String Function(int i) path = gameMe,
}) async {
  var t = 0.0;
  final recorder = FieldRecorder(now: () => t, controlAt: (_, _) => null);
  for (final (i, q) in asked.indexed) {
    t += q.gap;
    final mark = recorder.httpQueued()!;
    mark.left(RequestOptions(path: path(i)));
    t += q.round;
    mark.arrived(200, {
      'server-timing': ['connect;dur=${q.connect}, total;dur=${q.total}'],
    });
    await mark.watch(Future.value(null));
  }
  return recorder;
}

/// A Python file of the server (`backend/...`), read as text.
String serverFile(String path) => File('../backend/$path').readAsStringSync();

/// The quoted words of a tuple or set named [name] in [source].
Set<String> quotedWords(String source, String name) {
  final code = source.replaceAll(RegExp(r'#[^\n]*'), '');
  final found = RegExp(
    '$name = (?:frozenset\\(\\s*)?[({]([^)}]*)[)}]',
  ).firstMatch(code)!;
  return {
    for (final m in RegExp(r'"([A-Za-z_]+)"').allMatches(found.group(1)!))
      m.group(1)!,
  };
}
