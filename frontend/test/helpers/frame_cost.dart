// Guard file: a change here needs its line in the pull request (tool/guard_edits.py).
//
// What a frame of a screen at rest costs, held by the screen sweep
// (sweep_run.dart) for every catalogue state, at every phone and text size:
//
// - [frameCostProblems]: above the screen's still pictures (`Still`, `Mood`)
//   nothing fills a layer of its own on every frame (a `saveLayer`, an
//   opacity under 1, a `ShaderMask`, a `BackdropFilter`, an image or colour
//   filter) but in the app's widgets named in [layerAllowed], each with why
//   and the state that shows it; and no picture is decoded larger than its
//   own drawn box asks for (`ArtImage.decodeWidth`), nor drawn by a way that
//   does not decode it for its box.
// - [staleLayerAllowances]: an allowance its state no longer uses fails, so
//   the list cannot keep a door open for a layer that is gone.
//
// Its job is that a NEW layer on every frame cannot arrive unnoticed; the
// ones named here are there today, each for its reason.
//
// How: the screen is painted once into a recording canvas, which paints
// every render object as it is (a repaint boundary is no shortcut there) but
// a `Still`'s inside, which is one picture, as on a frame.
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/skin/art_set.dart';

/// Why an app widget may fill a layer of its own on a frame at rest, and a
/// catalogue state that shows it ([seenOn]): the sweep fails the allowance
/// when that state no longer uses it ([staleLayerAllowances]).
class LayerAllowance {
  const LayerAllowance(this.seenOn, this.why);

  final String seenOn;
  final String why;
}

/// The app's widgets that may fill a layer of their own on a frame at rest,
/// named by the nearest widget of the app's own above the layer (the one
/// the sweep's message names).
const layerAllowed = <String, LayerAllowance>{};

/// The pictures drawn without [ArtDecode] on purpose, by the widget that
/// draws them, and why.
const undecodedAllowed = <String, String>{
  'SlicedArt':
      'a nine-slice frame drawn at its own pixels per point, never scaled',
};

/// The app's widgets that decode a picture for a box other than the one it
/// is drawn in, on purpose, and why.
const decodedAheadAllowed = <String, String>{
  'HeldFace':
      'a secret\'s portrait is decoded for the whole card ahead of the reveal '
      '(`secretArt`), whatever room its words leave it, so a reveal fetches '
      'nothing',
};

final _used = <String>{};

/// Forgets which allowances were used: the sweep calls it before a state.
void resetLayerAllowances() => _used.clear();

/// The allowances whose state ([LayerAllowance.seenOn]) is [state] and that
/// it did not use since [resetLayerAllowances]: stale.
List<String> staleLayerAllowances(
  String state, {
  Map<String, LayerAllowance> allowed = layerAllowed,
}) => [
  for (final MapEntry(:key, :value) in allowed.entries)
    if (value.seenOn == state && !_used.contains(key))
      '$key is in layerAllowed for $state, which no longer fills its layer: '
          'take the line out (or name the state that still shows it)',
];

/// The names of the classes declared in the app's code (`lib/`), read once:
/// a layer is told by the nearest of the app's widgets above it, never
/// Flutter's (an `Opacity` is everywhere; the `FaintArt` around it is not).
final Set<String> appClasses = () {
  final declared = RegExp(
    r'^\s*(?:(?:abstract|base|final|sealed|interface|mixin)\s+)*class\s+(\w+)',
    multiLine: true,
  );
  return {
    for (final file in Directory('lib').listSync(recursive: true))
      if (file is File && file.path.endsWith('.dart'))
        for (final m in declared.allMatches(file.readAsStringSync())) m[1]!,
  };
}();

List<String> frameCostProblems(WidgetTester tester, Size screen) =>
    frameCostProblemsWith(tester, allowed: layerAllowed);

/// [frameCostProblems] with its allowances [allowed] (the self-test's own).
List<String> frameCostProblemsWith(
  WidgetTester tester, {
  required Map<String, LayerAllowance> allowed,
}) {
  final root = tester.binding.renderViews.first.child;
  if (root == null) return const [];
  final ratio = tester.view.devicePixelRatio;
  final canvas = _Canvas();
  final context = _Context(canvas);
  canvas.owner = () => context.painting;
  context.paintChild(root, Offset.zero);
  context.dispose();
  final problems = <String>{};
  for (final (what, owner) in canvas.layers) {
    final element = _element(owner);
    final ours = element == null ? null : nearestAppWidget(element);
    if (ours != null && allowed.containsKey(ours)) {
      _used.add(ours);
      continue;
    }
    final by = element?.widget.runtimeType ?? owner.runtimeType;
    problems.add(
      '$what on every frame at rest, from $by in ${ours ?? 'no widget of '
              'the app'}: bake it into a Still (or the art), or name '
      '${ours ?? 'the widget'} in layerAllowed with why',
    );
  }
  problems.addAll(_decodeProblems(tester, ratio));
  return problems.toList();
}

String _name(Widget widget) => widget.runtimeType.toString().split('<').first;

/// The nearest widget above [element] (or it) whose class is the app's.
String? nearestAppWidget(Element element) {
  final own = _name(element.widget);
  if (appClasses.contains(own)) return own;
  String? found;
  element.visitAncestorElements((e) {
    final name = _name(e.widget);
    if (appClasses.contains(name)) found = name;
    return found == null;
  });
  return found;
}

Element? _element(RenderObject? owner) {
  final creator = owner?.debugCreator;
  return creator is DebugCreator ? creator.element : null;
}

class _Canvas extends TestRecordingCanvas {
  late RenderObject? Function() owner;
  final layers = <(String, RenderObject?)>[];

  @override
  void saveLayer(Rect? bounds, Paint paint) {
    layers.add(('a saveLayer', owner()));
    super.saveLayer(bounds, paint);
  }
}

class _Context extends TestRecordingPaintingContext {
  _Context(_Canvas super.canvas);

  final _stack = <RenderObject>[];
  RenderObject? get painting => _stack.isEmpty ? null : _stack.last;

  @override
  void paintChild(RenderObject child, Offset offset) {
    // A part that is its own layer (an opacity, `RenderOpacity` as a repaint
    // boundary) paints only its child here: its layer says what it fills.
    if (child.isRepaintBoundary) {
      final what = _layerCost(child.debugLayer);
      if (what != null) (canvas as _Canvas).layers.add((what, child));
    }
    _stack.add(child);
    try {
      super.paintChild(child, offset);
    } finally {
      _stack.removeLast();
    }
  }

  // The recording context drops a colour filter (and what is under it):
  // painted here, and counted.
  @override
  ColorFilterLayer pushColorFilter(
    Offset offset,
    ColorFilter colorFilter,
    PaintingContextCallback painter, {
    ColorFilterLayer? oldLayer,
  }) {
    (canvas as _Canvas).layers.add(('a colour filter', painting));
    painter(this, offset);
    // The render object keeps it (its layer handle) and lets it go.
    return oldLayer ?? ColorFilterLayer();
  }

  @override
  void pushLayer(
    Layer childLayer,
    PaintingContextCallback painter,
    Offset offset, {
    Rect? childPaintBounds,
  }) {
    final what = _layerCost(childLayer);
    if (what != null) (canvas as _Canvas).layers.add((what, painting));
    super.pushLayer(
      childLayer,
      painter,
      offset,
      childPaintBounds: childPaintBounds,
    );
  }
}

/// What a layer fills on every frame, or null for one that fills nothing.
String? _layerCost(Layer? layer) => switch (layer) {
  ShaderMaskLayer() => 'a ShaderMask',
  BackdropFilterLayer() => 'a BackdropFilter',
  ImageFilterLayer() => 'an image filter',
  ColorFilterLayer() => 'a colour filter',
  OpacityLayer(:final alpha?) when alpha < 255 => 'an opacity',
  _ => null,
};

List<String> _decodeProblems(WidgetTester tester, double ratio) {
  final problems = <String>[];
  for (final element in find.byType(Image).evaluate()) {
    final image = element.widget as Image;
    final box = _renderImage(element);
    final drawn = box?.image;
    if (box == null || drawn == null || !box.attached || !box.hasSize) {
      continue;
    }
    final provider = image.image;
    final ours = nearestAppWidget(element);
    if (provider is! ArtDecode) {
      if (!undecodedAllowed.containsKey(ours)) {
        problems.add(
          'a picture drawn without ArtImage.decodedFor (${provider.runtimeType}'
          ') in ${ours ?? 'no widget of the app'}: it is decoded at full size',
        );
      }
      continue;
    }
    if (decodedAheadAllowed.containsKey(_aheadBy(element))) continue;
    final scale = _scaleOf(box) * ratio;
    final input = Size(drawn.width / box.scale, drawn.height / box.scale);
    final fitted = applyBoxFit(box.fit ?? BoxFit.contain, input, box.size);
    if (fitted.source.width <= 0) continue;
    // Device pixels each decoded pixel covers, and so the device pixels the
    // whole picture covers across: what its own box asks for.
    final k =
        fitted.destination.width * scale / (fitted.source.width * box.scale);
    final needed = drawn.width * k;
    final asked = _stepFor(provider.art, needed);
    if (drawn.width > asked + 0.5) {
      problems.add(
        '${provider.art.path} decoded ${drawn.width} wide, its box asks for '
        '$asked (drawn ${needed.round()} device pixels wide, in '
        '${ours ?? 'no widget of the app'}): decode it for the box it is '
        'drawn in',
      );
    }
  }
  return problems;
}

/// The width [ArtImage.decodeWidth] gives a picture [needed] device pixels
/// wide (it steps by halvings of the full width).
int _stepFor(ArtImage art, double needed) {
  // A box exactly as wide as [needed] at a ratio of one, at the picture's
  // own shape: decodeWidth's own answer, so the guard never has rules of
  // its own about sizes.
  final full = art.pixels;
  return art.decodeWidth(Size(needed, needed * full.height / full.width), 1);
}

/// The widget of [decodedAheadAllowed] [element] is drawn in, if any.
String? _aheadBy(Element element) {
  String? found;
  element.visitAncestorElements((e) {
    final name = _name(e.widget);
    if (decodedAheadAllowed.containsKey(name)) found = name;
    return found == null;
  });
  return found;
}

RenderImage? _renderImage(Element element) {
  RenderImage? found;
  void down(Element e) {
    if (found != null) return;
    if (e.renderObject case final RenderImage r) {
      found = r;
      return;
    }
    e.visitChildren(down);
  }

  down(element);
  return found;
}

double _scaleOf(RenderObject box) {
  final m = box.getTransformTo(null);
  return math.sqrt(
    m.entry(0, 0) * m.entry(0, 0) + m.entry(1, 0) * m.entry(1, 0),
  );
}
