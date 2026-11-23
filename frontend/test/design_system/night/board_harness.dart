import 'dart:convert';
import 'dart:ui' as ui;

import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/copy/copy.dart';
import 'package:midnight_village/design_system/faces/face_content.dart';
import 'package:midnight_village/design_system/models/role.dart';
import 'package:midnight_village/design_system/night/night_board.dart';
import 'package:midnight_village/design_system/night/night_pick.dart';
import 'package:midnight_village/design_system/faces/night_report.dart';
import 'package:midnight_village/design_system/night/choose_prompt.dart';
import 'package:midnight_village/design_system/primitives/face_down_card.dart';
import 'package:midnight_village/design_system/primitives/primary_button.dart';
import 'package:midnight_village/design_system/skin/dress.dart';
import 'package:midnight_village/design_system/skin/ground.dart';
import 'package:midnight_village/design_system/skin/ground_scope.dart';
import 'package:midnight_village/design_system/skin/skin_theme.dart';
import 'package:midnight_village/design_system/teach/learned_store.dart';

import '../../helpers/component_sheet.dart';
import '../../helpers/pump_skinned.dart';
import '../../helpers/sheet/sheet_data.dart';

/// A night board on a phone of a recorded game, with what it sent.
class BoardHarness {
  BoardHarness(
    Map<String, dynamic> me, {
    this.learned = const {},
    Future<ChooseAnswer> Function()? answer,
    this.secondsLeft = 14,
    this.share,
    this.dress = Dress.plain,
  }) : answer = answer ?? (() async => ChooseAnswer.taken) {
    show(me);
  }

  /// [viewer]'s phone at its board.
  BoardHarness.of(
    Viewer viewer, {
    Set<Cue> learned = const {},
    Future<ChooseAnswer> Function()? answer,
    Dress dress = Dress.plain,
  }) : this(viewer.nightMe, learned: learned, answer: answer, dress: dress);

  /// How the board is dressed: plain, the look the behaviour tests measure;
  /// the app's own default is paper (`Dress.paper`).
  final Dress dress;

  /// What the phone shows: read from its `/me/`.
  late Map<String, dynamic> me;
  late ChoosePrompt prompt;
  late FaceContent face;
  late RoleId dealt;
  late List<NightSeat> seats;
  late int selfId;
  final Set<Cue> learned;

  /// The countdown shown; null for a window with no deadline.
  final int? secondsLeft;

  /// How much of the window is left, for the candle; null, whole.
  final double? share;

  /// The phone fetched [next] (a new stage, the Doppelganger's follow-up).
  void show(Map<String, dynamic> next) {
    me = next;
    prompt = ChoosePrompt.fromMe(next);
    face = NightReport.fromMe(next).you(prompt);
    dealt = NightReport.fromMe(next).dealt;
    seats = NightSeat.seatsOf(next);
    selfId = selfIn(next);
  }

  /// How the server answers each choose: at once, taken, by default.
  Future<ChooseAnswer> Function() answer;

  /// Each choose's stage, and its picks, in order.
  final stages = <String>[];
  final sent = <List<NightPick>>[];
  late final container = ProviderContainer(
    overrides: learnedOverrides(learned),
  );

  /// A seat by name.
  NightSeat seat(String name) => seats.firstWhere((s) => s.name == name);

  Widget build({Widget Function(Widget board)? wrap}) {
    final board = NightBoard(
      seats: seats,
      selfId: selfId,
      prompt: prompt,
      face: face,
      dealt: dealt,
      dress: dress,
      secondsLeft: secondsLeft,
      share: share,
      onChoose: (stage, picks) {
        stages.add(stage);
        sent.add(picks);
        return answer();
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
    // A phone that has shown no board yet: nothing kept from an earlier one.
    await tester.pumpWidget(const SizedBox());
    await tester.pumpWidget(build(wrap: wrap));
    // The opening wave, done: it starts on the frame after the first and
    // takes its first tick as time zero.
    await tester.pump();
    await tester.pump();
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

/// A tap shorter than 120 ms (on "You", longer is a hold); it picks at
/// once, on every card.
Future<void> tapCard(WidgetTester tester, String caption) async {
  await tester.tap(card(caption));
  await tester.pump();
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
    // How often a layer has repainted so far in the test.
    RegExp(r'^.*(metrics|diagnosis): .*$', multiLine: true),
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
