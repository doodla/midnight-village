import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/primitives/primary_button.dart';

import 'finger.dart';
import 'truncated_text.dart';

// The screen sweep: what every screen state in the gallery's catalogue
// (test_screens/screen_catalogue.dart) is held to, from its one declaration.
// The state is pumped once, then the phone is turned through three sizes and
// three text sizes on the same tree, as a player's settings would, and each
// time it is measured from the real render boxes as painted (a turned card by
// its turned corners). Rules, never pictures or numbers of a screen:
// - nothing overflows or throws, and no text is drawn cut (a name is whole);
// - the main action, if the screen shows one, is on the screen, not under
//   another piece, labelled for a screen reader, 48 to touch, and a finger's
//   press reaches it (down, a frame, up: `pressLikeAFinger`);
// - what the state says must be seen is drawn and on the screen; the pieces
//   it says lie apart do not lie on each other;
// - the state's own rules hold (a relation, e.g. the hanged are in view).

/// Phones: a small one, a tall narrow one, the mocks' one.
const sweepSizes = [Size(360, 640), Size(360, 780), Size(390, 844)];

/// The phone's text size: as set, larger, the largest a table plays with.
const sweepScales = [1.0, 1.3, 1.6];

/// A rule of one screen state: what is wrong on the tree as drawn, one line
/// each (empty when it holds).
typedef ScreenRule = List<String> Function(WidgetTester tester, Size screen);

/// What a screen state's main action is.
class MainAction {
  /// The screen's main action is its amber button: whatever acting
  /// [PrimaryButton] it shows is held to the rules (none is fine).
  const MainAction.ifShown() : required = false;

  /// The state must show an acting [PrimaryButton]: its main action.
  const MainAction.button() : required = true;

  final bool required;
}

/// Pieces that must not lie on each other: every piece [a] finds apart from
/// every other one it finds ([Apart.each]), or from every piece [b] finds.
class Apart {
  const Apart.each(this.what, this.a) : b = null;
  const Apart.from(this.what, this.a, Finder this.b);

  /// What is checked, for the message ("cards", "a tag on a card").
  final String what;
  final Finder a;
  final Finder? b;
}

/// The box [element] paints into on the screen: every box under it, its
/// corners carried through every turn and move to the screen.
Rect paintedRect(Element element) {
  Rect? all;
  void add(RenderObject o) {
    if (o is RenderBox && o.hasSize && !o.size.isEmpty) {
      final m = o.getTransformTo(null);
      final r = Offset.zero & o.size;
      for (final p in [r.topLeft, r.topRight, r.bottomLeft, r.bottomRight]) {
        final q = MatrixUtils.transformPoint(m, p);
        final dot = Rect.fromPoints(q, q);
        all = all == null ? dot : all!.expandToInclude(dot);
      }
    }
    o.visitChildren(add);
  }

  add(element.renderObject!);
  return all ?? Rect.zero;
}

/// The box of [element]'s own render box on the screen, turned as drawn
/// (what is inside it, a scrolling board, is not counted).
Rect ownRect(Element element) {
  final box = element.renderObject;
  if (box is! RenderBox || !box.hasSize) return Rect.zero;
  return MatrixUtils.transformRect(
    box.getTransformTo(null),
    Offset.zero & box.size,
  );
}

/// The painted boxes of everything [finder] finds.
List<Rect> paintedRects(Finder finder) =>
    finder.evaluate().map(paintedRect).toList();

/// Two boxes lie on each other by more than a hair.
bool liesOn(Rect a, Rect b) {
  final i = a.intersect(b);
  return i.width > 1 && i.height > 1;
}

/// [r] is on the [screen], to half a pixel.
bool onScreen(Rect r, Size screen) {
  final s = (Offset.zero & screen).inflate(0.5);
  return s.contains(r.topLeft) && s.contains(r.bottomRight);
}

/// What is wrong with [apart] on the tree as drawn.
List<String> apartProblems(Apart apart) {
  final a = paintedRects(apart.a);
  final same = apart.b == null;
  final b = same ? a : paintedRects(apart.b!);
  return [
    for (var i = 0; i < a.length; i++)
      for (var j = same ? i + 1 : 0; j < b.length; j++)
        if (liesOn(a[i], b[j])) '${apart.what}: ${a[i]} on ${b[j]}',
  ];
}

/// The acting main buttons on screen: in the front route (a button under an
/// open sheet is not the screen's main action while the sheet is up), and
/// acting (a waiting or done one does not).
List<Element> actingMainButtons() => [
  for (final e in find.byType(PrimaryButton).evaluate())
    if (_acts(e.widget as PrimaryButton) &&
        (ModalRoute.of(e)?.isCurrent ?? true))
      e,
];

bool _acts(PrimaryButton b) => switch (b.phase) {
  ButtonPhase.ready => !b.busy,
  ButtonPhase.quiet || ButtonPhase.on || ButtonPhase.locked => true,
  ButtonPhase.waiting || ButtonPhase.done => false,
};

/// A finger at the centre of [element] reaches it: nothing lies over it.
bool reachable(WidgetTester tester, Element element) {
  final box = element.renderObject;
  if (box is! RenderBox || !box.attached || !box.hasSize) return false;
  final centre = box.localToGlobal(box.size.center(Offset.zero));
  final hits = tester.hitTestOnBinding(centre).path.map((e) => e.target);
  for (final target in hits) {
    if (target is! RenderObject) continue;
    RenderObject? node = target;
    while (node != null) {
      if (identical(node, box)) return true;
      node = node.parent;
    }
  }
  return false;
}

/// What a screen state declares about itself, for the sweep.
class SweepPlan {
  const SweepPlan({
    this.main = const MainAction.ifShown(),
    this.mustSee = const [],
    this.apart = const [],
    this.rules = const [],
    this.opensAtEachSize = false,
  });

  /// The state is opened afresh at each phone and text size, for rules about
  /// how it opens (the end board shows the hanged when it opens); otherwise
  /// one tree is pumped and the phone turned under it, as a player would.
  final bool opensAtEachSize;

  final MainAction main;

  /// Drawn and on the screen, at every size (what must not lie under
  /// another piece is an [Apart]).
  final List<Finder> mustSee;
  final List<Apart> apart;
  final List<ScreenRule> rules;
}

/// What is wrong at one size and text size, one line each.
List<String> checkDrawn(WidgetTester tester, SweepPlan plan, Size screen) {
  final problems = [for (final cut in truncatedText(tester)) 'cut short: $cut'];
  final buttons = actingMainButtons();
  if (plan.main.required && buttons.isEmpty) {
    problems.add('no main button acts, and the state says it shows one');
  }
  for (final e in buttons) {
    final r = paintedRect(e);
    if (!onScreen(r, screen)) problems.add('main button off the screen: $r');
    if (!reachable(tester, e)) problems.add('main button under a piece: $r');
  }
  for (final finder in plan.mustSee) {
    final found = finder.evaluate().toList();
    if (found.isEmpty) {
      problems.add('not drawn: ${finder.describeMatch(Plurality.zero)}');
    }
    for (final e in found) {
      // Its own box: what it holds may scroll past the screen.
      final r = ownRect(e);
      if (!onScreen(r, screen)) {
        problems.add('off the screen: ${e.widget.runtimeType} $r');
      }
    }
  }
  for (final apart in plan.apart) {
    problems.addAll(apartProblems(apart));
  }
  for (final rule in plan.rules) {
    problems.addAll(rule(tester, screen));
  }
  return problems;
}

/// Sweeps the state [build] pumps through every phone in [sweepSizes] and
/// text size in [sweepScales] on one pumped tree, then checks its main
/// action for a screen reader and a finger. Returns every problem, each line
/// saying at what size; empty when the state holds.
Future<List<String>> sweepScreen(
  WidgetTester tester,
  Future<void> Function(WidgetTester tester) build,
  SweepPlan plan, {
  int settleFrames = 10,
}) async {
  final problems = <String>[];
  final errors = <String>[];
  final report = FlutterError.onError;
  FlutterError.onError = (d) =>
      errors.add(d.exceptionAsString().split('\n').first);
  tester.view.devicePixelRatio = 1;
  tester.view.physicalSize = sweepSizes.last;
  addTearDown(tester.view.reset);
  addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
  try {
    await build(tester);
    for (var i = 0; i < settleFrames; i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    for (final scale in sweepScales) {
      for (final size in sweepSizes) {
        tester.view.physicalSize = size;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        if (plan.opensAtEachSize) {
          await tester.pumpWidget(const SizedBox.shrink());
          await build(tester);
          tester.view.physicalSize = size;
          for (var i = 0; i < settleFrames; i++) {
            await tester.pump(const Duration(milliseconds: 100));
          }
        }
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        final at = '${size.width.toInt()}x${size.height.toInt()} text x$scale';
        problems.addAll([
          for (final e in errors) '$at: $e',
          for (final p in checkDrawn(tester, plan, size)) '$at: $p',
        ]);
        errors.clear();
      }
    }
    // The mocks' phone at the phone's own text size: the main action for a
    // screen reader and a finger.
    tester.view.physicalSize = sweepSizes.last;
    tester.platformDispatcher.textScaleFactorTestValue = 1;
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    problems.addAll(errors);
    problems.addAll(await _mainActionProblems(tester));
  } finally {
    FlutterError.onError = report;
  }
  return problems;
}

Future<List<String>> _mainActionProblems(WidgetTester tester) async {
  final problems = <String>[];
  final buttons = actingMainButtons();
  if (buttons.isEmpty) return problems;
  final button = buttons.first;
  final finder = find.byElementPredicate((e) => identical(e, button));
  final semantics = tester.ensureSemantics();
  await tester.pump();
  if (tester.getSemantics(finder).label.trim().isEmpty) {
    problems.add('the main button has no label for a screen reader');
  }
  semantics.dispose();
  final size = (button.renderObject! as RenderBox).size;
  if (size.height < 48 || size.width < 48) {
    problems.add('the main button is $size, under 48 to touch');
  }
  final pressed = <PrimaryButton>[];
  final rule = PrimaryButton.debugOnAct;
  // The press is held at the button: what it sets off (a request, the next
  // screen) is the screen's own tests' business; the sweep asks only that a
  // finger reaches it.
  PrimaryButton.debugOnAct = (button) {
    rule?.call(button);
    pressed.add(button);
    return false;
  };
  try {
    await pressLikeAFinger(tester, finder);
  } finally {
    PrimaryButton.debugOnAct = rule;
  }
  if (pressed.isEmpty) {
    problems.add(
      'a finger\'s press (down, a frame, up) did not reach the main button: '
      'a tap the button loses on a real phone',
    );
  }
  return problems;
}
