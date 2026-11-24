// One screen state, at the size of a real phone, at full resolution: what a
// player sees. Run it with `just look <state> [width] [height]`, which also
// draws the same state from main beside it (tool/look.sh).
//
// The contact sheet shows every screen small; a broken detail a few pixels long
// passes there. This is for judging one state before it is called done.
//
// Stands on its own (the catalogue and Flutter only), so the same file can be
// run inside a checkout of main that does not have it yet.
import 'dart:io';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

import 'screen_catalogue.dart';

/// The state to draw: a catalogue id (`08-talk-ready`), or part of one when
/// only a few ids hold it.
const _state = String.fromEnvironment('LOOK_STATE');

/// The phone, in logical pixels. The default is a common large Android phone.
const _width = int.fromEnvironment('LOOK_WIDTH', defaultValue: 412);
const _height = int.fromEnvironment('LOOK_HEIGHT', defaultValue: 915);

/// Device pixels per logical pixel: 3 is what such a phone has.
const _ratio = int.fromEnvironment('LOOK_RATIO', defaultValue: 3);
const _out = String.fromEnvironment('LOOK_OUT', defaultValue: 'build/look');
const _mostAtOnce = 8;

/// Many states at once, by exact id, separated by commas (`just handover`):
/// no limit, and an id this checkout does not have is skipped (main may lack
/// a new state).
const _states = String.fromEnvironment('LOOK_STATES');

List<ScreenEntry> _wanted() {
  final built = [
    for (final e in screenCatalogue)
      if (e.build != null) e,
  ];
  if (_states.isNotEmpty) {
    final ids = _states.split(',').toSet();
    return [
      for (final e in built)
        if (ids.contains(e.id)) e,
    ];
  }
  final exact = [
    for (final e in built)
      if (e.id == _state) e,
  ];
  if (exact.isNotEmpty) return exact;
  return [
    for (final e in built)
      if (_state.isNotEmpty && e.id.contains(_state)) e,
  ];
}

void main() {
  final wanted = _wanted();

  test('the state named is in the catalogue', () {
    // Written for tool/look.sh, which reads it when main has no such state.
    File('$_out/states.txt')
      ..parent.createSync(recursive: true)
      ..writeAsStringSync([for (final e in wanted) e.id].join('\n'));
    if (_states.isNotEmpty) return;
    if (wanted.isEmpty) {
      final near = [
        for (final e in screenCatalogue)
          if (e.build != null &&
              _state.isNotEmpty &&
              e.id.startsWith(_state.split('-').first))
            e.id,
      ];
      fail(
        'No screen state "$_state". '
        '${near.isEmpty ? 'Ids look like 02-table or 08-talk-ready.' : 'Near it: ${near.join(', ')}'}',
      );
    }
    expect(
      wanted.length,
      lessThanOrEqualTo(_mostAtOnce),
      reason:
          '"$_state" is part of ${wanted.length} states; name one: '
          '${[for (final e in wanted) e.id].join(', ')}',
    );
  });

  for (final entry in _states.isEmpty ? wanted.take(_mostAtOnce) : wanted) {
    testWidgets(entry.id, (tester) async {
      tester.view.physicalSize = Size(
        _width * _ratio.toDouble(),
        _height * _ratio.toDouble(),
      );
      tester.view.devicePixelRatio = _ratio.toDouble();
      addTearDown(tester.view.reset);
      if (entry.textScale != 1) {
        tester.platformDispatcher.textScaleFactorTestValue = entry.textScale;
        addTearDown(tester.platformDispatcher.clearTextScaleFactorTestValue);
      }
      WidgetsApp.debugAllowBannerOverride = false;
      addTearDown(() => WidgetsApp.debugAllowBannerOverride = true);
      // What the framework reports while the state is up is printed, not
      // thrown: this is for looking, `just screens strict` is the judge.
      final said = <String>{};
      final report = FlutterError.onError;
      FlutterError.onError = (d) =>
          said.add(d.exceptionAsString().split('\n').first.trim());
      debugDisableShadows = false;
      try {
        await entry.build!(tester);
        for (var i = 0; i < (entry.frames ?? 10); i++) {
          await tester.pump(const Duration(milliseconds: 100));
        }
        await _loadImages(tester);
        final png = await tester.runAsync(() async {
          final image = await captureImage(tester.binding.rootElement!);
          final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
          image.dispose();
          return bytes!.buffer.asUint8List();
        });
        File('$_out/${entry.id}.png')
          ..parent.createSync(recursive: true)
          ..writeAsBytesSync(png!);
        // How many words are on the screen at once (`just handover` says
        // which states show more than main does).
        File('$_out/${entry.id}.words').writeAsStringSync('${_wordsShown()}');
      } finally {
        debugDisableShadows = true;
        FlutterError.onError = report;
      }
      for (final line in said) {
        // ignore: avoid_print
        print('look: ${entry.id}: $line');
      }
    });
  }
}

/// The words drawn on the screen now: every piece with a letter in it, in
/// every text that has a size (icons are glyphs, not words).
int _wordsShown() {
  var words = 0;
  for (final e in find.byType(RichText).evaluate()) {
    if (e.findAncestorWidgetOfExactType<Icon>() != null) continue;
    final box = e.renderObject;
    if (box is! RenderBox || !box.hasSize || box.size.isEmpty) continue;
    final text = (e.widget as RichText).text.toPlainText();
    words += text
        .split(RegExp(r'\s+'))
        .where((piece) => RegExp(r'\p{L}', unicode: true).hasMatch(piece))
        .length;
  }
  return words;
}

/// Image providers load on real I/O, which the test clock never waits for:
/// load every image on screen for real, then draw again.
Future<void> _loadImages(WidgetTester tester) async {
  final images = [
    for (final element in find.byType(Image).evaluate())
      ((element.widget as Image).image, element),
    for (final element in find.byType(DecoratedBox).evaluate())
      if ((element.widget as DecoratedBox).decoration case BoxDecoration(
        image: final image?,
      ))
        (image.image, element),
  ];
  if (images.isEmpty) return;
  await tester.runAsync(
    () => Future.wait([
      for (final (provider, context) in images)
        precacheImage(provider, context),
    ]),
  );
  await tester.pump();
}
