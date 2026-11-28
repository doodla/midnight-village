// Guard file: a change here needs its line in the pull request (tool/guard_edits.py).
import 'package:flutter/gestures.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/feel/press.dart';

// Nothing that is on the screen moves unless it is the thing being touched
// (the owner, 28 November 2026, on 01 in Chrome on a Pixel: "when I tap, the
// name field also drops" and "things jump when the page loads and settles").
// Two rules, which the screen sweep holds every catalogue state to
// (sweep_run.dart):
// - [touchProblems]: a finger down anywhere presses at most one part, the one
//   under it, never a text field, and moves no other part on the screen in
//   the frames it is down. The browser's own move is played: a touch outside
//   a focused field takes the focus away on the down (Flutter on the web).
// - [openingProblems]: from the first frame a state draws to its settled
//   one, as its data, pictures and focus arrive, no part already drawn is
//   laid out anywhere else or at another size. A part may appear late or
//   fade in where it stands; it may not push what is there. (A motion drawn
//   by a transform, a screen's own arrival, is not a layout and is not
//   judged here; the card turn's own continuity test holds those.)

/// The parts a player sees: words, a field's text and every paper piece.
bool _isPart(RenderObject r) =>
    r is RenderParagraph ||
    r is RenderEditable ||
    (r is RenderBox && r.debugCreator is DebugCreator && _paper(r));

bool _paper(RenderBox r) =>
    (r.debugCreator! as DebugCreator).element.widget.runtimeType.toString() ==
    'TiltedPaper';

/// A part's words, to name it in a problem.
String describePart(RenderObject r) {
  if (r is RenderParagraph) return 'the words "${r.text.toPlainText()}"';
  if (r is RenderEditable) {
    return 'the text field "${r.text?.toPlainText() ?? ''}"';
  }
  final words = <String>[];
  void visit(RenderObject c) {
    if (c is RenderParagraph) words.add(c.text.toPlainText());
    if (c is RenderEditable) words.add('a text field');
    if (words.length < 2) c.visitChildren(visit);
  }

  r.visitChildren(visit);
  return 'the paper ${words.isEmpty ? '(no words)' : '"${words.join(' / ')}"'}';
}

/// Every part on screen and its rect: [layout] leaves out the paint-only
/// transforms (an arrival's slide, a press's sink) and keeps where layout put
/// it; else where it is drawn.
Map<RenderBox, Rect> _parts(WidgetTester tester, {required bool layout}) {
  final screen = Offset.zero & tester.view.physicalSize;
  final out = <RenderBox, Rect>{};
  void visit(RenderObject r, bool shown) {
    if (shown && r is RenderBox && r.hasSize && _isPart(r)) {
      final rect = layout ? _layoutRect(r) : _drawnRect(r);
      if (rect.overlaps(screen) && !rect.isEmpty) out[r] = rect;
    }
    r.visitChildren((c) => visit(c, shown && r.paintsChild(c)));
  }

  final root = tester.binding.rootElement?.renderObject;
  if (root != null) visit(root, true);
  return out;
}

Rect _drawnRect(RenderBox r) =>
    MatrixUtils.transformRect(r.getTransformTo(null), Offset.zero & r.size);

Rect _layoutRect(RenderBox box) =>
    MatrixUtils.transformRect(_chain(box), Offset.zero & box.size);

/// The paint transforms from [box] to the screen, without the paint-only
/// ones.
Matrix4 _chain(RenderBox box) {
  final steps = <Matrix4>[];
  RenderObject child = box;
  var parent = box.parent;
  while (parent != null) {
    if (parent is! RenderTransform &&
        parent is! RenderFractionalTranslation &&
        parent is! RenderPressSink) {
      final step = Matrix4.identity();
      parent.applyPaintTransform(child, step);
      steps.add(step);
    }
    child = parent;
    parent = parent.parent;
  }
  final m = Matrix4.identity();
  for (final step in steps.reversed) {
    m.multiply(step);
  }
  return m;
}

bool _moved(Rect a, Rect b) =>
    (a.topLeft - b.topLeft).distance > 0.5 ||
    (a.size.width - b.size.width).abs() > 0.5 ||
    (a.size.height - b.size.height).abs() > 0.5;

String _at(Rect r) =>
    '(${r.left.toStringAsFixed(0)}, ${r.top.toStringAsFixed(0)}) '
    '${r.width.toStringAsFixed(0)}x${r.height.toStringAsFixed(0)}';

/// The presses showing now.
List<RenderPressLayer> _pressed(WidgetTester tester) {
  final out = <RenderPressLayer>[];
  void visit(RenderObject r) {
    if (r is RenderPressLayer && r.isRepaintBoundary) out.add(r);
    r.visitChildren(visit);
  }

  final root = tester.binding.rootElement?.renderObject;
  if (root != null) visit(root);
  return out;
}

bool _inside(RenderObject r, RenderObject? of) {
  for (RenderObject? p = r; p != null; p = p.parent) {
    if (identical(p, of)) return true;
  }
  return false;
}

bool _holdsField(RenderObject r) {
  var found = false;
  void visit(RenderObject c) {
    if (c is RenderEditable) found = true;
    if (!found) c.visitChildren(visit);
  }

  visit(r);
  return found;
}

/// What a finger down presses and moves on the state on screen, touched at
/// the middle of every part that presses and of every text field, and on
/// the bare ground: the problems, one line each.
Future<List<String>> touchProblems(WidgetTester tester) async {
  Future<void> frames() async {
    for (var i = 0; i < 6; i++) {
      tester.binding.scheduleFrame();
      await tester.pump(const Duration(milliseconds: 16));
    }
  }

  final screen = Offset.zero & tester.view.physicalSize;
  Offset? middle(RenderBox r) {
    final c = _drawnRect(r).center;
    return screen.contains(c) ? c : null;
  }

  final points = <(Offset, String)>[
    for (final p in _presses(tester))
      if (middle(p) case final c?) (c, describePart(p)),
    for (final f in _parts(
      tester,
      layout: false,
    ).keys.whereType<RenderEditable>())
      if (middle(f) case final c?) (c, describePart(f)),
    (Offset(4, screen.height / 2), 'the bare edge of the screen'),
  ];
  final problems = <String>[];
  for (final (point, what) in points) {
    // What moves by itself in as many frames (a clock, a breath, a
    // cursor) is not the finger's doing.
    final before = _parts(tester, layout: false);
    await frames();
    final still = _parts(tester, layout: false);
    final own = {
      for (final MapEntry(:key, :value) in still.entries)
        if (before[key] case final b? when _moved(b, value)) key,
    };
    final gesture = await tester.startGesture(point);
    final focused = FocusManager.instance.primaryFocus?.context;
    final inField =
        focused != null &&
        focused.findRenderObject() is RenderBox &&
        _drawnRect(focused.findRenderObject()! as RenderBox).contains(point);
    if (focused?.widget is EditableText && !inField) {
      FocusManager.instance.primaryFocus?.unfocus();
    }
    await frames();
    final down = _pressed(tester);
    final after = _parts(tester, layout: false);
    if (down.length > 1) {
      problems.add('a touch on $what presses ${down.length} parts at once');
    }
    final press = down.isEmpty ? null : down.first;
    if (press != null && _holdsField(press)) {
      problems.add(
        'a touch on $what presses a text field (${describePart(press)})',
      );
    }
    if (press != null &&
        !_drawnRect(press).inflate(kTouchSlop).contains(point)) {
      problems.add(
        'a touch on $what presses ${describePart(press)}, not under it',
      );
    }
    for (final MapEntry(key: part, value: was) in still.entries) {
      final now = after[part];
      if (now == null || own.contains(part) || !_moved(was, now)) continue;
      final touched = press != null && _inside(part, press);
      if (touched && !_holdsField(press)) continue;
      problems.add(
        'a touch on $what moves ${describePart(part)} from ${_at(was)} to '
        '${_at(now)}: only the part under the finger answers a touch',
      );
    }
    await gesture.cancel();
    await tester.pump(const Duration(milliseconds: 500));
  }
  return problems.toSet().toList();
}

List<RenderPressLayer> _presses(WidgetTester tester) {
  final out = <RenderPressLayer>[];
  void visit(RenderObject r, bool shown) {
    if (shown && r is RenderPressLayer && r.hasSize) out.add(r);
    r.visitChildren((c) => visit(c, shown && r.paintsChild(c)));
  }

  final root = tester.binding.rootElement?.renderObject;
  if (root != null) visit(root, true);
  return out.take(8).toList();
}

/// The words of every text field on screen: they change when the player
/// types.
String _typed(Map<RenderBox, Rect> parts) => [
  for (final p in parts.keys.whereType<RenderEditable>())
    p.text?.toPlainText() ?? '',
].join('\n');

String? _words(RenderBox part) =>
    part is RenderParagraph ? part.text.toPlainText() : null;

/// Records the layout of every part on every frame [open] draws (the state's
/// build and its settling) until the player first does something (a finger
/// down, a word typed: what follows is their doing, not the opening): the
/// problems, one line each. A part whose own words changed is new content,
/// not a part pushed.
Future<List<String>> openingProblems(
  WidgetTester tester,
  Future<void> Function() open,
) async {
  final problems = <String>[];
  Map<RenderBox, Rect>? last;
  Map<RenderBox, String?> words = {};
  String? typed;
  var frame = 0;
  var on = true;
  void touched(PointerEvent event) {
    if (event is PointerDownEvent) on = false;
  }

  GestureBinding.instance.pointerRouter.addGlobalRoute(touched);
  void watch(Duration _) {
    if (!on) return;
    frame++;
    final now = _parts(tester, layout: true);
    typed ??= _typed(now);
    if (typed != _typed(now)) {
      on = false;
      return;
    }
    for (final MapEntry(key: part, value: rect) in now.entries) {
      final was = last?[part];
      if (was == null || !_moved(was, rect)) continue;
      if (words[part] != _words(part)) continue;
      problems.add(
        '${describePart(part)}, on the screen since an earlier frame, moved '
        'from ${_at(was)} to ${_at(rect)} in frame $frame: something that '
        'arrived after it pushed it (keep its room from the first frame, or '
        'let it appear in place)',
      );
    }
    last = now;
    words = {for (final p in now.keys) p: _words(p)};
    SchedulerBinding.instance.addPostFrameCallback(watch);
  }

  SchedulerBinding.instance.addPostFrameCallback(watch);
  try {
    await open();
  } finally {
    on = false;
    GestureBinding.instance.pointerRouter.removeGlobalRoute(touched);
  }
  return problems.toSet().toList();
}
