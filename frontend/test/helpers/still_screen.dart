// Guard file: a change here needs its line in the pull request (tool/guard_edits.py).
import 'package:flutter/foundation.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/primitives/countdown.dart';
import 'package:midnight_village/design_system/faces/held_face.dart';

// A still screen asks for no frames (the owner, 24 November 2026: "The game
// was very choppy", "it felt like I was watching a ppt"; measured, a screen
// waiting on a player kept the phone 25 to 100% busy drawing itself whole,
// and a tap's first frame waited behind those). Two rules, which the screen
// sweep holds every catalogue state to (sweep_run.dart):
// - [watchAtRest]: the state at rest, pumped for [restWindow] (with the
//   tests' fast healing timings, so a poll of an unchanged answer that
//   redraws anything shows many times), asks for frames only from a source
//   on [restSources] (or, until it moves, [movingToAmbient]); each such
//   frame rebuilds inside that source, and every layer it draws again (a
//   repaint boundary that needed paint) stands inside it. A screen with none
//   of them on it asks for no frame at all. Only a frame that comes again
//   counts: one that comes once (a "slow" line, a deadline passing) is news.
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

/// States the rest rule does not hold yet, each with what it finds: a to-do
/// that only shrinks.
const restNotYet = {
  '02-table-offline':
      'the table socket\'s reconnect attempts (a growing backoff) tell the '
      'table its connection again, and 02 is drawn again with "One moment" '
      'unchanged (3 frames in 16 s)',
  '03-deck-offline': 'as 02-table-offline',
};

/// How long a state is watched at rest: past the game's 5 s poll and the
/// table's 15 s one (`HealTiming`), which must redraw nothing that did not
/// change.
const restWindow = Duration(seconds: 16);

/// How long a state may take to come to rest first (its scenes and
/// entrances playing out), and the quiet it must show to be at rest.
const settleAtMost = Duration(seconds: 8);
const _quiet = Duration(seconds: 1);

const _step = Duration(milliseconds: 100);

/// The longest run of frames that counts as one moment, not a repeat.
const _once = Duration(seconds: 1);

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

/// The element that made [object], or the nearest render ancestor's (a
/// render object a render object made for itself has none).
Element? _elementOf(RenderObject object) {
  for (RenderObject? o = object; o != null; o = o.parent) {
    if (o.debugCreator case DebugCreator(:final element)) return element;
  }
  return null;
}

/// What one frame did: what it rebuilt and what it painted.
class _Frame {
  final rebuilt = <Element>[];
  final painted = <RenderObject>[];

  /// What needed layout, paint or a layer update as the frame began (a
  /// timer's mark: a cursor's blink changes only its layer, and paints
  /// nothing).
  final marked = <RenderObject>[];

  /// The layers drawn again: each painted object whose parent was not
  /// painted (a repaint boundary that needed paint before the frame; the
  /// clean boundaries under it were kept as they were). A cursor that
  /// blinks inside its field's own boundary needs only that one.
  List<RenderObject> get layers {
    final set = painted.toSet();
    return [
      for (final o in painted)
        if (o.parent == null || !set.contains(o.parent)) o,
    ];
  }
}

/// The render objects marked for the next frame.
List<RenderObject> _marked(WidgetTester tester) {
  final marked = <RenderObject>[];
  void visit(RenderObject o) {
    if (o.debugNeedsLayout ||
        o.debugNeedsPaint ||
        o.debugNeedsCompositedLayerUpdate) {
      marked.add(o);
    }
    o.visitChildren(visit);
  }

  for (final view in tester.binding.renderViews) {
    visit(view);
  }
  return marked;
}

/// Runs [body] with every rebuild and paint of its frames recorded.
Future<_Frame> _recorded(
  Future<void> Function() body, {
  WidgetTester? tester,
}) async {
  final frame = _Frame();
  final before = tester == null ? const <RenderObject>[] : _marked(tester);
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
  if (tester != null) {
    // What the frame took care of: a render object never painted (offstage,
    // under a page not shown) stays marked, and is not this frame's.
    final after = _marked(tester).toSet();
    frame.marked.addAll(before.where((o) => !after.contains(o)));
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
  // A face held up by a finger (in the overlay; one turned in place is
  // the card's own): Flutter lays its overlay layer out again at
  // every frame (`OverlayPortal.overlayChildLayoutBuilder`, so the face
  // follows the card), and a frame while it is up draws from the overlay.
  // The finger is on the glass: nothing is at rest.
  final heldUp = find
      .byType(HeldFace)
      .evaluate()
      .any((e) => _within(e, const {'PaperFlip'}).isEmpty);
  if (heldUp) return null;
  // Every layer drawn again stands inside its source.
  final escaped = {
    for (final o in frame.layers)
      if (_elementOf(o) case final e? when _within(e, allowed).isEmpty)
        e.widget.runtimeType.toString()
      else if (_elementOf(o) == null)
        o.runtimeType.toString(),
  };
  if (escaped.isNotEmpty) {
    return 'drew a layer beyond its source: ${escaped.take(4).join(', ')}';
  }
  final marked = {
    for (final o in frame.marked)
      if (_elementOf(o) case final e? when _within(e, allowed).isEmpty)
        e.widget.runtimeType.toString()
      else if (_elementOf(o) == null)
        o.runtimeType.toString(),
  };
  if (marked.isNotEmpty) {
    return 'was marked to draw beyond its source: ${marked.take(4).join(', ')}';
  }
  // A mark inside its source (a cursor's layer) is a frame of that source.
  if (frame.rebuilt.isEmpty && frame.painted.isEmpty && frame.marked.isEmpty) {
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
    return _recorded(() => tester.pump(), tester: tester);
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
  final problems = <String, List<Duration>>{};
  for (var t = Duration.zero; t < restWindow; t += _step) {
    final frame = await step();
    if (frame == null) continue;
    frames++;
    final problem = _frameProblem(frame);
    if (problem != null) (problems[problem] ??= []).add(t);
  }
  final sources = {
    for (final e in find.byWidgetPredicate((_) => true).evaluate())
      if (restSources.containsKey(e.widget.runtimeType.toString()) ||
          movingToAmbient.contains(e.widget.runtimeType.toString()))
        e.widget.runtimeType.toString(),
  };
  return RestReport(frames, [
    // Frames that come once, as one short run (an entrance, a "slow" line
    // fading in at 5 s, a deadline passing), are news; frames that come
    // again are a screen drawing itself.
    for (final MapEntry(:key, value: at) in problems.entries)
      if (at.last - at.first > _once)
        'at rest, ${at.length} frames in ${restWindow.inSeconds} s $key '
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
  // As each clock's timer does (a mark on the clock alone; the screen's
  // layout builders would hide a plain markNeedsBuild until a ticker runs).
  ClockTick.debugTickAll();
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
    for (final o in frame.layers)
      if (_elementOf(o) case final e?
          when _within(e, const {'ClockTick'}).isEmpty)
        e.widget.runtimeType.toString(),
  };
  if (frame.rebuilt.isEmpty) {
    problems.add('a clock tick rebuilt nothing (the tick never reached it)');
  }
  if (escaped.isNotEmpty) {
    problems.add(
      'a clock tick painted beyond the clock: ${escaped.take(4).join(', ')}',
    );
  }
  return problems;
}
