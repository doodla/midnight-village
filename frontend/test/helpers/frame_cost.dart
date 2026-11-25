// Guard file: a change here needs its line in the pull request (tool/guard_edits.py).
//
// What a frame of a screen at rest costs, held by the screen sweep
// (sweep_run.dart) for every catalogue state, at every phone and text size:
//
// - [frameCostProblems]: above the screen's still pictures (`Still`, `Mood`)
//   nothing fills a layer of its own on every frame (a `saveLayer`, an
//   opacity under 1, a `ShaderMask`, a `BackdropFilter`, an image or colour
//   filter) except the named parts in [layerAllowed], each with why; and no
//   picture is decoded more than [decodeSlack] steps larger than it is drawn
//   (`ArtImage.decodedFor`), nor drawn by a way that does not decode it for
//   its box.
//
// How: the screen is painted once into a recording canvas, which paints
// every render object as it is (a repaint boundary is no shortcut there) but
// a `Still`'s inside, which is one picture, as on a frame.
import 'dart:math' as math;

import 'package:flutter/rendering.dart';
import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/skin/art_set.dart';

/// The parts that may fill a layer of their own on a frame at rest, and
/// why. A part is named by its widget's type: the nearest widget above the
/// layer whose name is here allows it. A name nothing uses fails
/// ([staleLayerAllowances]).
const layerAllowed = <String, String>{};

/// How many decode steps (an eighth of the picture's width each) larger than
/// drawn a picture may be: one for the rounding up, one for a box decoded
/// ahead from the phone's size (03's grid) rather than its own layout.
const decodeSlack = 2;

/// The pictures drawn without [ArtDecode] on purpose, by the widget that
/// draws them, and why.
const undecodedAllowed = <String, String>{
  'SlicedArt':
      'a nine-slice frame drawn at its own pixels per point, never scaled',
};

final _used = <String>{};

/// The [layerAllowed] names no state of the sweep used: stale.
Set<String> staleLayerAllowances() =>
    layerAllowed.keys.toSet().difference(_used);

List<String> frameCostProblems(WidgetTester tester, Size screen) {
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
    final allowedBy = _allowedBy(owner);
    if (allowedBy != null) {
      _used.add(allowedBy);
      continue;
    }
    problems.add(
      '$what on every frame at rest, from ${_chain(owner)}: bake it into a '
      'Still (or the art), or name it in layerAllowed with why',
    );
  }
  problems.addAll(_decodeProblems(tester, ratio));
  return problems.toList();
}

String? _allowedBy(RenderObject? owner) {
  final element = _element(owner);
  if (element == null) return null;
  String? found;
  void up(Element e) {
    if (found != null) return;
    final name = e.widget.runtimeType.toString().split('<').first;
    if (layerAllowed.containsKey(name)) found = name;
  }

  up(element);
  element.visitAncestorElements((e) {
    up(e);
    return found == null;
  });
  return found;
}

Element? _element(RenderObject? owner) {
  final creator = owner?.debugCreator;
  return creator is DebugCreator ? creator.element : null;
}

/// The owner's widget and the few of ours above it, for the message.
String _chain(RenderObject? owner) {
  final element = _element(owner);
  if (element == null) return '${owner.runtimeType}';
  final names = <String>[element.widget.runtimeType.toString()];
  element.visitAncestorElements((e) {
    final name = e.widget.runtimeType.toString();
    if (!name.startsWith('_') && !names.contains(name)) names.add(name);
    return names.length < 5;
  });
  return names.join(' < ');
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
    _stack.add(child);
    try {
      super.paintChild(child, offset);
    } finally {
      _stack.removeLast();
    }
  }

  final _made = <ColorFilterLayer>[];

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
    final layer = ColorFilterLayer();
    _made.add(layer);
    return layer;
  }

  @override
  void dispose() {
    for (final layer in _made) {
      layer.dispose();
    }
    super.dispose();
  }

  @override
  void pushLayer(
    Layer childLayer,
    PaintingContextCallback painter,
    Offset offset, {
    Rect? childPaintBounds,
  }) {
    final what = switch (childLayer) {
      ShaderMaskLayer() => 'a ShaderMask',
      BackdropFilterLayer() => 'a BackdropFilter',
      ImageFilterLayer() => 'an image filter',
      ColorFilterLayer() => 'a colour filter',
      _ => null,
    };
    if (what != null) (canvas as _Canvas).layers.add((what, painting));
    super.pushLayer(
      childLayer,
      painter,
      offset,
      childPaintBounds: childPaintBounds,
    );
  }
}

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
    if (provider is! ArtDecode) {
      final by = _drawnBy(element);
      if (by == null) {
        problems.add(
          'a picture drawn without ArtImage.decodedFor (${provider.runtimeType}'
          ') under ${_chain(box)}: it is decoded at full size',
        );
      }
      continue;
    }
    final scale = _scaleOf(box) * ratio;
    final input = Size(drawn.width / box.scale, drawn.height / box.scale);
    final fitted = applyBoxFit(box.fit ?? BoxFit.contain, input, box.size);
    if (fitted.source.width <= 0) continue;
    // Device pixels each decoded pixel covers.
    final k =
        fitted.destination.width * scale / (fitted.source.width * box.scale);
    final needed = drawn.width * k;
    final step = provider.art.pixels.width / ArtImage.steps;
    if (drawn.width - needed > decodeSlack * step + 0.5) {
      problems.add(
        '${provider.art.path} decoded ${drawn.width} wide, drawn '
        '${needed.round()} device pixels wide (${_chain(box)})',
      );
    }
  }
  return problems;
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

String? _drawnBy(Element element) {
  String? found;
  element.visitAncestorElements((e) {
    final name = e.widget.runtimeType.toString();
    if (undecodedAllowed.containsKey(name)) found = name;
    return found == null;
  });
  return found;
}

double _scaleOf(RenderObject box) {
  final m = box.getTransformTo(null);
  return math.sqrt(
    m.entry(0, 0) * m.entry(0, 0) + m.entry(1, 0) * m.entry(1, 0),
  );
}
