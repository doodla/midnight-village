import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/copy/copy.dart';
import 'package:midnight_village/design_system/faces/face_content.dart';
import 'package:midnight_village/design_system/night/night_board.dart';
import 'package:midnight_village/design_system/night/night_pick.dart';
import 'package:midnight_village/design_system/primitives/face_down_card.dart';
import 'package:midnight_village/design_system/primitives/primary_button.dart';
import 'package:midnight_village/design_system/skin/ground.dart';
import 'package:midnight_village/design_system/skin/ground_scope.dart';
import 'package:midnight_village/design_system/skin/skin_theme.dart';
import 'package:midnight_village/design_system/teach/learned_store.dart';

import '../../helpers/component_sheet.dart';
import '../../helpers/pump_skinned.dart';
import '../../helpers/sheet/sheet_data.dart';

/// A night board on a phone, with what it sent.
class BoardHarness {
  BoardHarness({
    required this.face,
    this.window = NightWindow.two,
    this.seats = fiveSeats,
    this.taken = true,
    this.learned = const {},
  });

  FaceContent face;
  final NightWindow window;
  final List<NightSeat> seats;

  /// What the server answers each choose.
  bool taken;
  final Set<Cue> learned;

  /// Each choose's picks, in order.
  final sent = <List<NightPick>>[];
  late final container = ProviderContainer(
    overrides: learnedOverrides(learned),
  );

  Widget build({Widget Function(Widget board)? wrap}) {
    final board = NightBoard(
      seats: seats,
      selfId: ana.id,
      window: window,
      face: face,
      secondsLeft: 14,
      onChoose: (picks) async {
        sent.add(picks);
        return taken;
      },
    );
    return UncontrolledProviderScope(
      container: container,
      child: MaterialApp(
        debugShowCheckedModeBanner: false,
        theme: skinTheme(skinsUnderTest.values.first),
        builder: (context, child) =>
            GroundScope(ground: GroundKind.night, child: child!),
        home: wrap == null ? board : wrap(board),
      ),
    );
  }

  Future<void> pump(
    WidgetTester tester, {
    Widget Function(Widget)? wrap,
  }) async {
    tester.view.physicalSize = const Size(390, 844);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    addTearDown(container.dispose);
    await tester.pumpWidget(build(wrap: wrap));
    // The opening wave, done.
    await tester.pump(const Duration(seconds: 2));
    // Every picture loaded for real (the test clock never waits for I/O),
    // so the first board drawn in a test is drawn as the rest are.
    await tester.runAsync(
      () => Future.wait([
        for (final element in find.byType(Image).evaluate())
          precacheImage((element.widget as Image).image, element),
      ]),
    );
    await tester.pump();
  }
}

/// A card on the board by what is under it: a name, "You", "Left".
Finder card(String caption) =>
    find.ancestor(of: find.text(caption), matching: find.byType(FaceDownCard));

/// "You".
Finder get you => card(NightCopy.you);

/// A tap shorter than 120 ms (on "You", longer is a hold), then past the
/// double-tap window, so every card takes it the same way.
Future<void> tapCard(WidgetTester tester, String caption) async {
  await tester.tap(card(caption));
  await tester.pump(kDoubleTapTimeout + const Duration(milliseconds: 10));
}

/// The board's button: its label and what it can do.
(String, ButtonPhase) button(WidgetTester tester) {
  final b = tester.widget<PrimaryButton>(find.byType(PrimaryButton));
  return (b.label, b.phase);
}

/// The cards picked (lifted), by caption, in screen order.
List<String> lifted(WidgetTester tester) => [
  for (final element in find.byType(FaceDownCard).evaluate())
    if ((element.widget as FaceDownCard).selected)
      ((element.widget as FaceDownCard).semanticLabel)!,
];

/// What a phone shows of the board that a bystander could see, as text: the
/// render tree (sizes, places, paints, words), the widget tree and the
/// semantics tree. Left out: what tells two runs of the same app apart and
/// nothing about the screen (objects' identity hashes, semantics ids, which
/// inherited widgets an element has looked up so far, an image's loading
/// state).
String visibleTrees(WidgetTester tester) {
  final noise = [
    RegExp(r'#[0-9a-f]{5}\b|(?<=Location)\[[0-9a-f]{5}\]'),
    RegExp(r'(?<=SemanticsNode)#\d+'),
    RegExp(r', dependencies: \[(?:[^\[\]]|\[[^\]]*\])*\]'),
    RegExp(r', state: _ImageState\(.*$', multiLine: true),
  ];
  final view = tester.binding.renderViews.single;
  final semantics = view.owner?.semanticsOwner?.rootSemanticsNode?.toStringDeep(
    childOrder: DebugSemanticsDumpOrder.traversalOrder,
  );
  return noise.fold(
    [
      view.toStringDeep(),
      tester.binding.rootElement!.toStringDeep(),
      ?semantics,
    ].join('\n'),
    (text, pattern) => text.replaceAll(pattern, ''),
  );
}

/// The screen's pixels, as a PNG in base64 (for comparing, not saving).
Future<String> screenPixels(WidgetTester tester) async {
  final png = await tester.runAsync(() async {
    final image = await captureImage(tester.binding.rootElement!);
    final bytes = await image.toByteData(format: ui.ImageByteFormat.png);
    image.dispose();
    return bytes!.buffer.asUint8List();
  });
  return base64Encode(png!);
}
