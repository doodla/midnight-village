import 'dart:convert';

import 'field_recorder.dart';
import 'perf_records.dart';

/// The quiet recorder's summary of one game (or of the play before the tab
/// was hidden): what `field_beacon.dart` sends to the server
/// (`POST /api/observe/summary/`, `backend/apps/observe/summary.py` keeps
/// only this shape). Kinds of tap, screens, paths without ids, times and
/// counts, and what the phone says about itself: never a name, a role, a
/// card, a vote, a code or an id.
///
/// Per kind of tap and per leg it holds up to [mostValues] of the game's
/// values, spread over their range (the smallest, the largest and evenly
/// between), so the server can merge games into a median and a 90th
/// percentile without every tap.
const fieldSummaryVersion = 1;
const mostEntries = 24;
const mostValues = 24;

/// What a summary may weigh, as sent (the server refuses over 16 KB).
const mostSummaryChars = 12000;

/// A request counts as a cold start when the time outside the server's own
/// count (the round trip less `Server-Timing`'s `total`: the network, the
/// platform and a server instance starting) is this far above the game's
/// usual (`boot`), or its database connection is (`db_wake`: Neon waking).
const coldBootOver = 700.0;
const coldConnectOver = 250.0;

/// The summary as JSON, or null when nothing was tapped or asked for.
/// [environment] stands in for the recorder's own (the quiet mode reads it
/// only when a first summary is made, never at the app's start).
String? fieldSummaryJson(
  FieldRecorder r, {
  required String commit,
  required String end,
  Map<String, Object?>? environment,
}) {
  r.settleRest();
  for (final (values, entries) in [
    (mostValues, mostEntries),
    (8, mostEntries),
    (4, 8),
  ]) {
    final summary = fieldSummary(
      r,
      commit: commit,
      end: end,
      values: values,
      entries: entries,
      environment: environment,
    );
    if (summary == null) return null;
    final text = jsonEncode(summary);
    if (text.length <= mostSummaryChars) return text;
  }
  return null;
}

Map<String, Object?>? fieldSummary(
  FieldRecorder r, {
  required String commit,
  required String end,
  int values = mostValues,
  int entries = mostEntries,
  Map<String, Object?>? environment,
}) {
  final done = r.taps.where((t) => t.done).toList();
  final asked = r.requests.where((q) => q.doneAt != null).toList();
  if (done.isEmpty && asked.isEmpty) return null;

  Map<String, Object?> legs(int n, Map<String, Iterable<double?>> named) => {
    'n': n,
    for (final MapEntry(key: name, value: of) in named.entries)
      if (spreadOf(of, values) case final v when v.isNotEmpty) name: v,
  };

  final env = environment ?? r.environment;
  return {
    'v': fieldSummaryVersion,
    'commit': commit,
    'end': end,
    'env': {
      for (final key in const [
        'agent',
        'pixel_ratio',
        'screen',
        'window',
        'renderer',
        'gpu',
        'cores',
        'memory_gb',
        'main_bundle_ms',
        'engine_ms',
      ])
        if (env[key] case final value?) key: value,
      if (r.firstFrameAt case final first?) 'first_frame_ms': first.round(),
    },
    'taps': {
      for (final (kind, taps) in _grouped(done, (t) => t.kind).take(entries))
        kind: legs(taps.length, {
          'heard': taps.map((t) => t.heard),
          'screen': taps.map((t) => t.toScreen),
          'left': taps.map((t) => t.toLeft),
          'answer': taps.map((t) => t.roundTrip),
          'applied': taps.map((t) => t.toApplied),
          'shown': taps.map((t) => t.toShown),
          'total': taps.map((t) => t.total),
        }),
    },
    'frames': {
      for (final MapEntry(key: screen, value: f)
          in (r.frames.entries.toList()
                ..sort((a, b) => b.value.frames.compareTo(a.value.frames)))
              .take(entries))
        if (f.frames > 0)
          screen: {
            'frames': f.frames,
            'over_50': f.over50,
            'over_100': f.over100,
            'worst': _r(f.worst),
            if (median(f.totals) case final m?) 'median': _r(m),
          },
    },
    'screens': {
      for (final (change, list) in _grouped(
        r.screens,
        (s) => '${s.from} > ${s.to} (${s.cause})',
      ).take(entries))
        change: legs(list.length, {
          'first': list.map((s) => s.toFirstFrame),
          'content': list.map((s) => s.toContent),
        }),
    },
    'requests': {
      for (final (path, list) in _grouped(
        asked,
        (q) => '${q.method} ${q.path}',
      ).take(entries))
        path: legs(list.length, {
          'round': list.map((q) => q.roundTrip),
          'server': list.map((q) => q.serverTotal),
          'connect': list.map((q) => q.serverConnect),
          'outside': list.map(_outside),
        }),
    },
    'cold': coldStarts(asked),
    'socket': {
      'events': r.sockets.where((s) => !s.state).length,
      'opened': r.sockets.where((s) => s.what == 'connected').length,
      'dropped': r.sockets.where((s) => s.what == 'disconnected').length,
    },
  };
}

/// The time a request spent outside the server's own count.
double? _outside(HttpRecord q) => switch ((q.roundTrip, q.serverTotal)) {
  (final round?, final total?) => round > total ? round - total : 0,
  _ => null,
};

/// The requests of [asked] that look like a cold start, at most ten, each
/// with how long the phone had asked nothing before it (`gap_s`).
List<Map<String, Object?>> coldStarts(List<HttpRecord> asked) {
  final outside = [for (final q in asked) ?_outside(q)];
  final connect = [for (final q in asked) ?q.serverConnect];
  double usual(List<double> values) =>
      values.length < 3 ? 0 : (median(values) ?? 0);
  final usualOutside = usual(outside);
  final usualConnect = usual(connect);
  final byTime = [...asked]..sort((a, b) => a.queuedAt.compareTo(b.queuedAt));
  final cold = <Map<String, Object?>>[];
  for (final (i, q) in byTime.indexed) {
    final out = _outside(q);
    final kind = switch ((out, q.serverConnect)) {
      (_, final c?) when c > _over(usualConnect, coldConnectOver, 4) =>
        'db_wake',
      (final o?, _) when o > _over(usualOutside, coldBootOver, 3) => 'boot',
      _ => null,
    };
    if (kind == null) continue;
    final before = i == 0 ? null : byTime[i - 1];
    cold.add({
      'kind': kind,
      'path': '${q.method} ${q.path}',
      'round': ?_r(q.roundTrip),
      'server': ?_r(q.serverTotal),
      'connect': ?_r(q.serverConnect),
      'outside': ?_r(out),
      if (before != null)
        'gap_s': ((q.queuedAt - before.queuedAt) / 1000).roundToDouble(),
    });
    if (cold.length == 10) break;
  }
  return cold;
}

double _over(double usual, double by, double times) =>
    usual + by > usual * times ? usual + by : usual * times;

/// Up to [most] of [values] (the ones that happened), spread over their
/// range: all of them when there are few, else the smallest, the largest
/// and evenly between.
List<double> spreadOf(Iterable<double?> values, int most) {
  final seen = values.whereType<double>().toList()..sort();
  if (seen.length <= most) return [for (final v in seen) _r(v)!];
  return [
    for (var i = 0; i < most; i++)
      _r(seen[(i * (seen.length - 1) / (most - 1)).round()])!,
  ];
}

/// [items] grouped by [key], the biggest group first.
List<(String, List<T>)> _grouped<T>(Iterable<T> items, String Function(T) key) {
  final groups = <String, List<T>>{};
  for (final item in items) {
    groups.putIfAbsent(key(item), () => []).add(item);
  }
  return [for (final e in groups.entries) (e.key, e.value)]
    ..sort((a, b) => b.$2.length.compareTo(a.$2.length));
}

double? _r(double? ms) => ms == null ? null : (ms * 10).round() / 10;
