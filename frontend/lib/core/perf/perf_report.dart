import 'dart:convert';

import 'field_recorder.dart';
import 'perf_records.dart';

/// The words of the strip, the sheet and the report: a developer's tool the
/// owner reads and pastes to us, so they live here, not in the player's copy.
abstract final class PerfWords {
  static const copyReport = 'Copy report';
  static const copyAll = 'Copy everything';
  static const clear = 'Clear';
  static const copied = 'Copied';
  static const noTap = 'Tap anything:\nits time shows here.';
  static const legs =
      'heard: finger to the app. screen: finger to the first frame. left: '
      'finger to the request leaving. answer: its round trip, as the '
      'browser saw it. applied: the answer in to the app having used it '
      '(a busy page shows here). shown: to the frame after. total: finger '
      'to the last of these. A tap is timed from the lift, a hold from the '
      'touch.';
}

/// The strip's two lines for the last tap that finished:
/// "finger → screen 84 ms · request left 12 ms" and "answer 163 ms · worst
/// 22 ms". Always two lines, so the strip never changes height (the app
/// above it would be laid out again).
String stripLine(TapRecord? tap) {
  if (tap == null) return PerfWords.noTap;
  final screen = 'finger → screen ${_ms(tap.toScreen)}';
  final worst = 'worst ${_ms(tap.worstFrame)}';
  if (tap.request == null) return '$screen · no request\n$worst';
  return '$screen · request left ${_ms(tap.toLeft)}\n'
      'answer ${_ms(tap.roundTrip)} · $worst';
}

/// The report to paste in a chat: short (under 4,000 characters), plain.
String shortReport(FieldRecorder r, {String commit = ''}) {
  r.settleRest();
  final out = StringBuffer();
  final done = r.taps.where((t) => t.done).toList();
  out.writeln(
    'Midnight Village perf${commit.isEmpty ? '' : ' $commit'}: '
    '${done.length} taps, ${r.requests.length} requests, '
    '${r.screens.length} screen changes',
  );
  out.writeln('Taps, median/worst ms from the finger: ${_legNames.join(' ')}');
  for (final (kind, taps) in _grouped(done, (t) => t.kind).take(12)) {
    out.writeln(
      ' $kind x${taps.length}: ${[for (final leg in _legs) _mw(taps.map(leg))].join(' ')}',
    );
  }
  out.writeln(
    'Frames per screen: count, over 16/32/50/100 ms, worst, '
    'build/raster/other median, at rest per minute',
  );
  final screens = r.frames.entries.toList()
    ..sort((a, b) => b.value.frames.compareTo(a.value.frames));
  for (final MapEntry(key: screen, value: f) in screens.take(10)) {
    final rest = f.restPerMinute;
    out.writeln(
      ' $screen: ${f.frames}, ${f.over16}/${f.over32}/${f.over50}/'
      '${f.over100}, ${_n(f.worst)}, ${_ms0(median(f.builds))}/'
      '${_ms0(median(f.rasters))}/${_ms0(median(f.others))}, '
      '${rest == null ? '-' : _n(rest)}',
    );
  }
  out.writeln(
    'Requests, median/worst ms: waited to leave, round trip, answer '
    'waited for the page, server total',
  );
  final paths = _grouped(r.requests, (q) => '${q.method} ${q.path}');
  for (final (path, list) in paths.take(10)) {
    final polls = list.where((q) => q.isPoll).length;
    out.writeln(
      ' $path x${list.length}${polls > 0 ? ' ($polls polls)' : ''}: '
      '${_mw(list.map((q) => q.waited))} ${_mw(list.map((q) => q.roundTrip))} '
      '${_mw(list.map((q) => q.sat))} ${_mw(list.map((q) => q.serverTotal))}',
    );
  }
  out.writeln('Screen changes, median/worst ms: to first frame, to content');
  final changes = _grouped(
    r.screens,
    (s) => '${s.from} > ${s.to} (${s.cause})',
  );
  for (final (what, list) in changes.take(8)) {
    out.writeln(
      ' $what x${list.length}: ${_mw(list.map((s) => s.toFirstFrame))} '
      '${_mw(list.map((s) => s.toContent))}',
    );
  }
  final events = r.sockets.where((s) => !s.state).length;
  final states = r.sockets.where((s) => s.state).map((s) => s.what).toList();
  out.writeln(
    'Socket: $events events (they carry no send time), '
    '${states.where((s) => s == 'connected').length} opened, '
    '${states.where((s) => s == 'disconnected').length} dropped',
  );
  out.writeln('Slowest five:');
  for (final line in _slowest(r).take(5)) {
    out.writeln(' $line');
  }
  out.write('Phone: ${_environment(r)}');
  final text = out.toString();
  return text.length <= 4000 ? text : '${text.substring(0, 3990)}…';
}

/// Everything recorded, as JSON ("Copy everything").
String fullReport(FieldRecorder r, {String commit = ''}) {
  r.settleRest();
  return jsonEncode({
    'commit': commit,
    'environment': {
      ...r.environment,
      'first_frame_ms': r.firstFrameAt?.round(),
    },
    'taps': [
      for (final t in r.taps) {...t.toJson(), 'kind': t.kind},
    ],
    'requests': [for (final q in r.requests) q.toJson()],
    'sockets': [for (final s in r.sockets) s.toJson()],
    'screens': [for (final s in r.screens) s.toJson()],
    'frames': {for (final e in r.frames.entries) e.key: e.value.toJson()},
  });
}

const _legNames = [
  'heard',
  'screen',
  'left',
  'answer',
  'applied',
  'shown',
  'total',
];

final List<double? Function(TapRecord)> _legs = [
  (t) => t.heard,
  (t) => t.toScreen,
  (t) => t.toLeft,
  (t) => t.roundTrip,
  (t) => t.toApplied,
  (t) => t.toShown,
  (t) => t.total,
];

/// The moments that took longest, with what happened in them.
List<String> _slowest(FieldRecorder r) {
  final moments = <(double, String)>[
    for (final t in r.taps)
      if (t.total case final total? when t.done)
        (
          total,
          '${_n(total)} ms: ${t.kind}: heard ${_ms(t.heard)}, screen '
              '${_ms(t.toScreen)}${t.request == null ? '' : ', left ${_ms(t.toLeft)}, '
                        'answer ${_ms(t.roundTrip)}, applied ${_ms(t.toApplied)}, '
                        'shown ${_ms(t.toShown)}'}, worst frame ${_ms(t.worstFrame)}',
        ),
    for (final s in r.screens)
      if (s.toContent case final content?)
        (
          content,
          '${_n(content)} ms: ${s.from} > ${s.to} after ${s.cause}: first '
              'frame ${_ms(s.toFirstFrame)}, content ${_ms(content)}',
        ),
  ]..sort((a, b) => b.$1.compareTo(a.$1));
  return [for (final (_, line) in moments) line];
}

String _environment(FieldRecorder r) {
  final e = r.environment;
  String cut(Object? v, int most) {
    final s = '${v ?? '-'}';
    return s.length <= most ? s : s.substring(0, most);
  }

  return [
    cut(e['agent'], 140),
    'ratio ${e['pixel_ratio'] ?? '-'}',
    'screen ${e['screen'] ?? '-'}',
    'window ${e['window'] ?? '-'}',
    '${e['renderer'] ?? '-'}',
    'gpu ${cut(e['gpu'], 80)}',
    '${e['cores'] ?? '-'} cores',
    '${e['memory_gb'] ?? '-'} GB',
    'first frame ${_ms(r.firstFrameAt)}',
    'main bundle ${e['main_bundle_ms'] ?? '-'} ms',
    'engine ${e['engine_ms'] ?? '-'} ms',
  ].join(', ');
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

/// "median/worst" of [values] (the ones that happened).
String _mw(Iterable<double?> values) {
  final seen = values.whereType<double>().toList();
  if (seen.isEmpty) return '-';
  final worst = seen.reduce((a, b) => a > b ? a : b);
  return '${_n(median(seen)!)}/${_n(worst)}';
}

String _ms(double? ms) => ms == null ? '-' : '${_n(ms)} ms';

String _n(double v) => v.round().toString();

String _ms0(double? ms) => ms == null ? '-' : _n(ms);
