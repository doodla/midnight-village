// Guard file: a change here needs its line in the pull request (tool/guard_edits.py).
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/primitives/primary_button.dart';
import 'package:midnight_village/design_system/primitives/secondary_button.dart';
import 'package:midnight_village/design_system/primitives/square_foot.dart';
import 'package:midnight_village/design_system/primitives/until_touched.dart';

import 'finger.dart';
import 'name_pieces.dart';
import 'truncated_text.dart';

// The screen sweep: what every screen state in the gallery's catalogue
// (test_screens/screen_catalogue.dart) is held to, from its one declaration.
// The state is pumped once, then the phone is turned through three sizes and
// three text sizes on the same tree, as a player's settings would, and each
// time it is measured from the real render boxes as painted (a turned card by
// its turned corners). Rules, never pictures or numbers of a screen. Writing
// nothing gets all of them:
// - nothing overflows or throws, and no text is drawn cut;
// - every player's name is whole and no piece of the kit lies on its words
//   (name_pieces.dart: the pieces and names come from the kit, not a list);
// - the screen's main action (its amber button) is there, on the screen
//   without scrolling, not under another piece, labelled for a screen reader,
//   48 to touch, and a finger's press reaches it (`pressLikeAFinger`); on the
//   cobbles (08, 09) it lies in their middle. A state
//   with no main action (a wait, a lock) says so, with why: the one opt-out;
// - the phone's text size takes effect in the tree;
// - what the state says must be seen is drawn and on the screen; the pieces
//   it says lie apart do not lie on each other; its own rules hold.

/// Phones: a small one, a tall narrow one, a large Android one (412 wide: a link
/// drawn for 390 came out broken on the owner's), and last the mocks' one, which
/// is the size a state opens at.
const sweepSizes = [
  Size(360, 640),
  Size(360, 780),
  Size(412, 915),
  Size(390, 844),
];

/// The phone's text size: as set, larger, the largest a table plays with.
const sweepScales = [1.0, 1.3, 1.6];

/// A rule of one screen state: what is wrong on the tree as drawn, one line
/// each (empty when it holds).
typedef ScreenRule = List<String> Function(WidgetTester tester, Size screen);

/// What a screen state's main action is.
class MainAction {
  /// The state shows its main action, an acting [PrimaryButton], held to
  /// every rule. What every state is unless it says otherwise.
  const MainAction.button() : why = null;

  /// The state has no main action, and [why] (a wait for the others, a
  /// lock): the one opt-out. A main button it does show is still held to
  /// the rules.
  const MainAction.none(String this.why);

  final String? why;

  bool get required => why == null;
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
bool liesOn(Rect a, Rect b) => liesOnRect(a, b);

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

/// The screen's main action, acting, in the front route (a button under an
/// open sheet is not the screen's main action while the sheet is up): its
/// amber [PrimaryButton]; on a screen the kit gives none (01's Join and
/// Start), its [SecondaryButton]s. A waiting or done button does not act; a
/// button a lazy list never built is not here: a state that needs one fails.
List<Element> actingMainButtons() {
  bool front(Element e) => ModalRoute.of(e)?.isCurrent ?? true;
  List<Element> acting(Type type) => [
    for (final e in find.byType(type).evaluate())
      if (isAction(e.widget) && front(e)) e,
  ];
  final amber = find.byType(PrimaryButton).evaluate().where(front);
  return amber.isNotEmpty ? acting(PrimaryButton) : acting(SecondaryButton);
}

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

/// What lies over the centre of [element] is what a hold is showing
/// (`heldOpen`): it goes when the finger lifts.
bool _underHeldFace(WidgetTester tester, Element element) {
  final box = element.renderObject! as RenderBox;
  final centre = box.localToGlobal(box.size.center(Offset.zero));
  for (final hit in tester.hitTestOnBinding(centre).path) {
    if (hit.target case final RenderObject o) {
      if (o.debugCreator case final DebugCreator c) {
        return heldOpen(c.element);
      }
    }
  }
  return false;
}

/// What a finger at the centre of [element] reaches instead: the widgets
/// that made the front render objects under it.
String _onTop(WidgetTester tester, Element element) {
  final box = element.renderObject! as RenderBox;
  final centre = box.localToGlobal(box.size.center(Offset.zero));
  final names = [
    for (final hit in tester.hitTestOnBinding(centre).path.take(3))
      if (hit.target case final RenderObject o)
        if (o.debugCreator case final DebugCreator c)
          c.element.widget.runtimeType,
  ];
  return names.isEmpty
      ? 'nothing takes the finger'
      : 'a finger reaches '
            '${names.join(' in ')}';
}

/// What a screen state declares about itself, for the sweep: only what is
/// its own. The default is every rule, with a main action.
class SweepPlan {
  const SweepPlan({
    this.main = const MainAction.button(),
    this.mustSee = const [],
    this.apart = const [],
    this.rules = const [],
    this.whenOpened = const [],
  });

  /// A state with no main action, saying [why]: every other rule holds.
  SweepPlan.noMainAction(String why) : this(main: MainAction.none(why));

  final MainAction main;

  /// Drawn and on the screen, at every size (what must not lie under
  /// another piece is an [Apart]).
  final List<Finder> mustSee;
  final List<Apart> apart;
  final List<ScreenRule> rules;

  /// Rules about how the state opens (the end board opens with the hanged
  /// in view): checked once, on the mocks' phone as it opened, before the
  /// phone is turned (a turned phone does not open the screen again).
  final List<ScreenRule> whenOpened;
}

/// What is wrong at one size and text size, one line each.
List<String> checkDrawn(WidgetTester tester, SweepPlan plan, Size screen) {
  final problems = [for (final cut in truncatedText(tester)) 'cut short: $cut'];
  problems.addAll(nameProblems(tester, screen));
  problems.addAll(heldFaceProblems(screen));
  final buttons = actingMainButtons();
  if (plan.main.required && buttons.isEmpty) {
    final shown = [
      for (final e in find.byType(PrimaryButton).evaluate())
        if (e.widget case final PrimaryButton b)
          '"${b.label}" ${b.phase.name}${b.busy ? ' busy' : ''}'
              '${ModalRoute.of(e)?.isCurrent ?? true ? '' : ' under a sheet'}',
    ];
    problems.add(
      'no main button acts (${shown.isEmpty ? 'none built' : shown.join(', ')}'
      '): a state with no main action says why (SweepPlan.noMainAction)',
    );
  }
  for (final e in buttons) {
    final r = paintedRect(e);
    if (!onScreen(r, screen)) problems.add('main button off the screen: $r');
    if (!reachable(tester, e) && !_underHeldFace(tester, e)) {
      problems.add('main button under a piece (${_onTop(tester, e)}): $r');
    }
  }
  // The cobbles' plaque (08, 09: `SquareFoot`) lies in their middle on every
  // phone, as the mocks have it.
  for (final foot in find.byType(SquareFoot).evaluate()) {
    final cobbles = ownRect(foot).center.dx;
    final plaque = find.descendant(
      of: find.byElementPredicate((e) => identical(e, foot)),
      matching: find.byType(PrimaryButton),
    );
    for (final e in plaque.evaluate()) {
      final middle = ownRect(e).center.dx;
      if ((middle - cobbles).abs() > 1) {
        problems.add(
          'the plaque on the cobbles is off their middle: at '
          '${middle.toStringAsFixed(1)}, the cobbles\' at '
          '${cobbles.toStringAsFixed(1)}. Fix: centre it in '
          'lib/design_system/primitives/square_foot.dart',
        );
      }
    }
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

/// The largest text size any visible text is drawn at (its scaler on one
/// point), or null when there is none.
double? drawnTextScale() {
  double? most;
  for (final e in find.byType(RichText).evaluate()) {
    final p = e.renderObject;
    if (p is! RenderParagraph || !p.hasSize || p.size.isEmpty) continue;
    if (p.text.toPlainText().trim().isEmpty || isUnseen(e, p)) continue;
    // An icon is a glyph, not words: it keeps its size.
    if (e.findAncestorWidgetOfExactType<Icon>() != null) continue;
    final s = p.textScaler.scale(1);
    if (most == null || s > most) most = s;
  }
  return most;
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
    for (final rule in plan.whenOpened) {
      problems.addAll([
        for (final p in rule(tester, sweepSizes.last)) 'as it opens: $p',
      ]);
    }
    double? asSet;
    for (final scale in sweepScales) {
      for (final size in sweepSizes) {
        tester.view.physicalSize = size;
        tester.platformDispatcher.textScaleFactorTestValue = scale;
        await tester.pump();
        await tester.pump(const Duration(milliseconds: 100));
        final at = '${size.width.toInt()}x${size.height.toInt()} text x$scale';
        problems.addAll([
          for (final e in errors) '$at: $e',
          for (final p in checkDrawn(tester, plan, size)) '$at: $p',
        ]);
        errors.clear();
      }
      // The phone's text size reached the tree: a helper with its own
      // fixed text size would sweep only one.
      final drawn = drawnTextScale();
      if (scale == sweepScales.first) {
        asSet = drawn;
      } else if (asSet != null &&
          drawn != null &&
          drawn < asSet * scale - 0.01) {
        problems.add(
          'text x$scale did not take: the largest text is drawn at x$drawn '
          '(x$asSet at the phone\'s own size)',
        );
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
  // A layer up until one touch puts it away (`UntilTouched`): one touch, on
  // the main action itself (so "anywhere" holds where it matters most), puts
  // it away and does nothing else; the main action is then held to every rule.
  if (find.byType(UntilTouched).evaluate().isNotEmpty) {
    final under = actingMainButtons();
    final at = under.isEmpty
        ? tester.view.physicalSize.center(Offset.zero) /
              tester.view.devicePixelRatio
        : paintedRect(under.first).center;
    await pressAtLikeAFinger(tester, at);
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 400));
    if (find.byType(UntilTouched).evaluate().isNotEmpty) {
      problems.add('one touch did not put away what is up until touched');
      return problems;
    }
  }
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
  // The finger is taken away, not lifted: what the press sets off (a request,
  // the next screen) is the screen's own tests' business; the sweep asks only
  // that the lift would reach what the finger went down on.
  final touch = await pressAtLikeAFinger(
    tester,
    tester.getCenter(finder),
    lift: false,
  );
  if (touch == null || !identical(touch.action, button) || !touch.holds) {
    problems.add(
      'a finger\'s press (down, frames, up) did not reach the main button: '
      'a tap the button loses on a real phone',
    );
  }
  return problems;
}
