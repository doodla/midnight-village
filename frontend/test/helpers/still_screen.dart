// Guard file: a change here needs its line in the pull request (tool/guard_edits.py).
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/primitives/countdown.dart';

// A still screen asks for no frames (the owner, 24 November 2026: "The game
// was very choppy", "it felt like I was watching a ppt"; measured, a screen
// waiting on a player kept the phone 25 to 100% busy drawing itself whole,
// and a tap's first frame waited behind those). The screen sweep holds every
// catalogue state to it (sweep_run.dart), in two rules:
// - [stillScreenProblems]: the state at rest, pumped for [restWindow], asks
//   for frames only from a source on [restSources] (or, until it moves,
//   [movingToAmbient]), and each such frame rebuilds and paints inside that
//   source alone. A screen with none of them on it asks for no frame at all.
// - [clockTickProblems]: a tick of every clock on the screen rebuilds the
//   clock (`ClockTick`) and nothing else, and paints inside its room alone.

/// What may ask for frames on a screen at rest, by widget class, and why.
/// A new one is a decision, written here with its reason.
const restSources = {
  'ClockTick':
      'the clock: once a second, its number and candle only (countdown.dart)',
  'Ambient':
      'the ambient wrapper (design_system/feel/ambient.dart): short bursts '
      'with rest between, inside its own repaint boundary',
  'SkinField':
      'the text cursor blinking in a focused field, inside the field\'s own '
      'repaint boundary',
};

/// The loops that still repeat by themselves, moving onto [restSources]'s
/// `Ambient` (branch `motion-layer`): that session empties this list. While
/// one is on a screen its frames are allowed, and a frame it draws in may
/// paint beyond it.
const movingToAmbient = {'WaitingSign', 'LanternMark', 'HoldCue'};

/// How long a state is watched at rest: past the game's 5 s poll and the
/// table's 15 s one (`HealTiming`), which must redraw nothing that did not
/// change.
const restWindow = Duration(seconds: 16);

/// How long a state may take to come to rest first (its scenes and
/// entrances playing out), and the quiet it must show to be at rest.
const settleAtMost = Duration(seconds: 8);
const _quiet = Duration(seconds: 1);

const _step = Duration(milliseconds: 100);

/// The widget names [element] stands inside (itself included).
Set<String> _within(Element element, Set<String> names) {
  final found = <String>{};
  void look(Element e) {
    final name = e.widget.runtimeType.toString();
    if (names.contains(name)) found.add(name);
  }

  look(element);
  element.visitAncestorElements((e) {
    look(e);
    return true;
  });
  return found;
}

Element? _elementOf(RenderObject object) {
  final creator = object.debugCreator;
  return creator is DebugCreator ? creator.element : null;
}

/// What one frame did: what it rebuilt and what it painted.
class _Frame {
  final rebuilt = <Element>[];
  final painted = <RenderObject>[];
}

/// Runs [body] with every rebuild and paint of its frames recorded.
Future<_Frame> _recorded(Future<void> Function() body) async {
  final frame = _Frame();
  final rebuild = debugOnRebuildDirtyWidget;
  final paint = debugOnProfilePaint;
  debugOnRebuildDirtyWidget = (e, _) => frame.rebuilt.add(e);
  debugOnProfilePaint = frame.painted.add;
  try {
    await body();
  } finally {
    debugOnRebuildDirtyWidget = rebuild;
    debugOnProfilePaint = paint;
  }
  return frame;
}

/// The widgets a frame rebuilt from (the first rebuilt under no other
/// rebuilt one), by name: who asked for it.
List<String> _roots(List<Element> rebuilt) {
  final set = rebuilt.toSet();
  final roots = <String>{};
  for (final e in rebuilt) {
    var under = false;
    e.visitAncestorElements((a) {
      if (set.contains(a)) under = true;
      return !under;
    });
    if (!under) roots.add(e.widget.runtimeType.toString());
  }
  return roots.toList();
}

/// The files that registered the frame callbacks still pending (a ticker
/// that runs), from their registration stacks.
List<String> _tickerFiles() {
  final files = <String>{};
  final report = FlutterError.onError;
  FlutterError.onError = (details) {
    for (final node in details.informationCollector?.call() ?? const []) {
      if (node is DiagnosticsStackTrace) {
        final stack = node.value?.toString() ?? '';
        for (final m in RegExp(
          r'package:midnight_village/([\w/]+\.dart)',
        ).allMatches(stack)) {
          files.add(m.group(1)!);
        }
      }
    }
  };
  try {
    SchedulerBinding.instance.debugAssertNoTransientCallbacks('at rest');
  } finally {
    FlutterError.onError = report;
  }
  return files.toList();
}

/// What is wrong with one frame at rest, or null when it is allowed.
String? _frameProblem(_Frame frame) {
  final allowed = restSources.keys.toSet();
  final all = {...allowed, ...movingToAmbient};
  final outside = [
    for (final e in frame.rebuilt)
      if (_within(e, all).isEmpty) e,
  ];
  if (outside.isNotEmpty) {
    return 'rebuilt ${_roots(outside).take(4).join(', ')}';
  }
  final moving = frame.rebuilt.any(
    (e) => _within(e, movingToAmbient).isNotEmpty,
  );
  if (moving) return null;
  final escaped = [
    for (final o in frame.painted)
      if (_elementOf(o) case final e? when _within(e, all).isEmpty) o,
  ];
  if (escaped.isNotEmpty) {
    final names = {
      for (final o in escaped.take(40))
        _elementOf(o)?.widget.runtimeType.toString() ?? '$o',
    };
    return 'painted beyond its source: ${names.take(4).join(', ')}';
  }
  if (frame.rebuilt.isEmpty && frame.painted.isEmpty) {
    final tickers = _tickerFiles();
    final known = tickers.any(
      (f) => const [
        'waiting_sign.dart',
        'paper_lantern.dart',
        'hold_cue.dart',
        'feel/ambient.dart',
      ].any(f.endsWith),
    );
    if (!known) {
      return 'drew nothing new (a ticker or a repeated value: '
          '${tickers.isEmpty ? 'no ticker' : tickers.take(3).join(', ')})';
    }
  }
  return null;
}

/// How a state's rest went: its frames, and what is wrong.
class RestReport {
  RestReport(this.frames, this.problems);

  /// Frames asked for in [restWindow].
  final int frames;
  final List<String> problems;
}

/// The rest rule (see the top of this file): pumps the state until it is at
/// rest, then watches it for [restWindow].
Future<RestReport> watchAtRest(WidgetTester tester) async {
  final binding = tester.binding;
  Future<_Frame?> step() async {
    await binding.delayed(_step);
    if (!binding.hasScheduledFrame) return null;
    return _recorded(() => tester.pump());
  }

  // To rest: a quiet stretch with no frame beyond the allowed ones.
  var quiet = Duration.zero;
  for (var t = Duration.zero; t < settleAtMost && quiet < _quiet; t += _step) {
    final frame = await step();
    quiet = frame == null || _frameProblem(frame) == null
        ? quiet + _step
        : Duration.zero;
  }
  var frames = 0;
  final problems = <String, int>{};
  for (var t = Duration.zero; t < restWindow; t += _step) {
    final frame = await step();
    if (frame == null) continue;
    frames++;
    final problem = _frameProblem(frame);
    if (problem != null) problems[problem] = (problems[problem] ?? 0) + 1;
  }
  final sources = {
    for (final e in find.byWidgetPredicate((_) => true).evaluate())
      if (restSources.containsKey(e.widget.runtimeType.toString()) ||
          movingToAmbient.contains(e.widget.runtimeType.toString()))
        e.widget.runtimeType.toString(),
  };
  return RestReport(frames, [
    for (final MapEntry(:key, :value) in problems.entries)
      'at rest, $value frame(s) in ${restWindow.inSeconds} s $key '
          '(allowed: ${sources.isEmpty ? 'none on this screen' : sources.join(', ')})',
  ]);
}

/// The clock rule (see the top of this file): every clock on the screen is
/// made to tick once, with nothing else running, and the frame is read.
Future<List<String>> clockTickProblems(WidgetTester tester) async {
  final clocks = find.byType(ClockTick).evaluate().toList();
  if (clocks.isEmpty) return const [];
  // Whatever was pending drawn first, so the frame below is the tick's.
  await tester.pump();
  for (final clock in clocks) {
    clock.markNeedsBuild();
  }
  // Only the frame's build, layout and paint: no ticker runs in it.
  final frame = await _recorded(() async => tester.binding.drawFrame());
  final problems = <String>[];
  final outside = [
    for (final e in frame.rebuilt)
      if (_within(e, const {'ClockTick'}).isEmpty) e,
  ];
  if (outside.isNotEmpty) {
    problems.add(
      'a clock tick rebuilt beyond the clock: '
      '${_roots(outside).take(4).join(', ')}',
    );
  }
  final escaped = {
    for (final o in frame.painted)
      if (_elementOf(o) case final e?
          when _within(e, const {'ClockTick'}).isEmpty)
        e.widget.runtimeType.toString(),
  };
  if (escaped.isNotEmpty) {
    problems.add(
      'a clock tick painted beyond the clock: ${escaped.take(4).join(', ')}',
    );
  }
  return problems;
}
