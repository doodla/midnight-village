import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/faces/face_content.dart';
import 'package:midnight_village/design_system/faces/held_face.dart';
import 'package:midnight_village/design_system/layout/space.dart';
import 'package:midnight_village/design_system/models/role.dart';
import 'package:midnight_village/design_system/primitives/hold_to_reveal.dart';
import 'package:midnight_village/design_system/primitives/paper_flip.dart';
import 'package:midnight_village/design_system/skin/ground.dart';
import 'package:midnight_village/design_system/skin/ground_scope.dart';
import 'package:midnight_village/design_system/skin/skin_theme.dart';

import '../../helpers/pump_skinned.dart';

const _size = Size(200, 266);
const _back = Key('back');
const _faceKey = Key('face');
const _cover = Key('cover');

/// A card turned by a switch the test holds.
class _Flip extends StatefulWidget {
  const _Flip({this.landed});

  final VoidCallback? landed;

  @override
  State<_Flip> createState() => _FlipState();
}

class _FlipState extends State<_Flip> {
  var turned = false;
  var pressed = false;
  var faces = 0;

  void change({bool? turned, bool? pressed}) => setState(() {
    this.turned = turned ?? this.turned;
    this.pressed = pressed ?? this.pressed;
  });

  @override
  Widget build(BuildContext context) => Center(
    child: PaperFlip(
      turned: turned,
      pressed: pressed,
      onLanded: widget.landed,
      back: const SizedBox(
        key: _back,
        width: 200,
        height: 266,
        child: ColoredBox(color: Colors.indigo),
      ),
      face: (context) {
        faces++;
        return const SizedBox.expand(
          key: _faceKey,
          child: ColoredBox(color: Colors.white),
        );
      },
    ),
  );
}

Widget _app(Widget child, {bool still = false}) => MaterialApp(
  theme: skinTheme(skinsUnderTest.values.first),
  builder: (context, home) => MediaQuery(
    data: MediaQuery.of(context).copyWith(disableAnimations: still),
    child: GroundScope(ground: GroundKind.night, child: home!),
  ),
  home: Scaffold(body: child),
);

_FlipState _state(WidgetTester tester) =>
    tester.state<_FlipState>(find.byType(_Flip));

Future<void> _set(WidgetTester tester, {bool? turned, bool? pressed}) async {
  _state(tester).change(turned: turned, pressed: pressed);
  await tester.pump();
}

/// How much of its width the card on show faces us (1 flat, 0 edge on).
double _across(WidgetTester tester) {
  final side = tester.any(find.byKey(_faceKey))
      ? find.byKey(_faceKey)
      : find.byKey(_back);
  final matrix = tester
      .widget<Transform>(
        find.ancestor(of: side, matching: find.byType(Transform)).first,
      )
      .transform;
  return matrix.entry(0, 0) / matrix.entry(1, 1);
}

void main() {
  group('the turn', () {
    testWidgets('lies face down with no face in the tree, turns when asked '
        'and lies flat, the right way round, once landed', (tester) async {
      await tester.pumpWidget(_app(const _Flip()));
      expect(find.byKey(_back), findsOneWidget);
      expect(find.byKey(_faceKey, skipOffstage: false), findsNothing);
      expect(_state(tester).faces, 0);

      await _set(tester, turned: true);
      await tester.pump(PaperFlip.turn);
      await tester.pump(const Duration(milliseconds: 1));
      expect(find.byKey(_faceKey), findsOneWidget);
      expect(tester.getRect(find.byKey(_faceKey)).size, _size);
      final flat = tester
          .widget<Transform>(
            find
                .ancestor(
                  of: find.byKey(_faceKey),
                  matching: find.byType(Transform),
                )
                .first,
          )
          .transform;
      // Upright and not mirrored: x grows to the right, y downward.
      expect(flat.entry(0, 0), closeTo(1, 1e-6));
      expect(flat.entry(1, 1), closeTo(1, 1e-6));
    });

    testWidgets('while it turns the face is never mirrored and the card '
        'never leaves a gap: something is always drawn', (tester) async {
      await tester.pumpWidget(_app(const _Flip()));
      await _set(tester, turned: true);
      for (var ms = 0; ms <= 200; ms += 8) {
        await tester.pump(const Duration(milliseconds: 8));
        final onStage = tester.any(find.byKey(_faceKey))
            ? find.byKey(_faceKey)
            : find.byKey(_back);
        final matrix = tester
            .widget<Transform>(
              find
                  .ancestor(of: onStage, matching: find.byType(Transform))
                  .first,
            )
            .transform;
        expect(
          matrix.entry(0, 0),
          greaterThanOrEqualTo(-1e-9),
          reason: 'mirrored at $ms ms',
        );
      }
    });

    testWidgets('it lifts and grows at the edge, and is flat at both ends', (
      tester,
    ) async {
      await tester.pumpWidget(_app(const _Flip()));
      final rest = tester.getRect(find.byKey(_back));
      await _set(tester, turned: true);
      var highest = rest.top;
      var widest = 0.0;
      for (var ms = 0; ms < 170; ms += 8) {
        await tester.pump(const Duration(milliseconds: 8));
        final box = tester.getRect(
          tester.any(find.byKey(_faceKey))
              ? find.byKey(_faceKey)
              : find.byKey(_back),
        );
        highest = math.min(highest, box.top);
        widest = math.max(widest, box.height);
      }
      expect(highest, lessThan(rest.top - 2), reason: 'lifted');
      expect(widest, greaterThan(rest.height), reason: 'grown at the edge');
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byKey(_faceKey)), rest);
    });

    testWidgets('the face lands with the settle and the landing is told '
        'once', (tester) async {
      var landed = 0;
      await tester.pumpWidget(_app(_Flip(landed: () => landed++)));
      await _set(tester, turned: true);
      await tester.pump(PaperFlip.turn - const Duration(milliseconds: 20));
      expect(landed, 0);
      await tester.pumpAndSettle();
      expect(landed, 1);
    });

    testWidgets('let go half way it goes back from where it is, not from '
        'the face, and is told of no landing', (tester) async {
      var landed = 0;
      await tester.pumpWidget(_app(_Flip(landed: () => landed++)));
      await _set(tester, turned: true);
      // Early in the turn: the back is still the side on show.
      await tester.pump(const Duration(milliseconds: 24));
      expect(find.byKey(_faceKey), findsNothing);
      final before = _across(tester);
      expect(before, lessThan(0.95), reason: 'turned some of the way');
      await _set(tester, turned: false);
      var last = before;
      for (var ms = 0; ms < 90; ms += 6) {
        await tester.pump(const Duration(milliseconds: 6));
        // It goes back the way it came: never through the face, never
        // starting again from the far end.
        expect(find.byKey(_faceKey), findsNothing);
        final now = _across(tester);
        expect(now, greaterThanOrEqualTo(last - 1e-9));
        last = now;
      }
      expect(last, closeTo(1, 1e-6));
      expect(landed, 0);
      expect(tester.getRect(find.byKey(_back)).size, _size);
    });

    testWidgets('let go once the face is up, it passes through the edge and '
        'lands flat on the back', (tester) async {
      await tester.pumpWidget(_app(const _Flip()));
      await _set(tester, turned: true);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(_faceKey), findsOneWidget);
      await _set(tester, turned: false);
      await tester.pump(PaperFlip.turnBack);
      await tester.pump(const Duration(milliseconds: 1));
      expect(find.byKey(_faceKey, skipOffstage: false), findsNothing);
      expect(tester.getRect(find.byKey(_back)).size, _size);
    });

    testWidgets('let go after the edge, it turns back in no more than the '
        'fade it replaces, and the face leaves the tree', (tester) async {
      await tester.pumpWidget(_app(const _Flip()));
      await _set(tester, turned: true);
      await tester.pumpAndSettle();
      await _set(tester, turned: false);
      await tester.pump(PaperFlip.turnBack);
      await tester.pump(const Duration(milliseconds: 1));
      expect(PaperFlip.turnBack, lessThanOrEqualTo(Motion.press));
      expect(find.byKey(_faceKey, skipOffstage: false), findsNothing);
      expect(find.byKey(_back), findsOneWidget);
    });

    testWidgets('taken again half way back it goes on from there', (
      tester,
    ) async {
      var landed = 0;
      await tester.pumpWidget(_app(_Flip(landed: () => landed++)));
      await _set(tester, turned: true);
      await tester.pumpAndSettle();
      expect(landed, 1);
      await _set(tester, turned: false);
      await tester.pump(const Duration(milliseconds: 30));
      await _set(tester, turned: true);
      await tester.pumpAndSettle();
      expect(find.byKey(_faceKey), findsOneWidget);
      expect(tester.getRect(find.byKey(_faceKey)).size, _size);
      expect(landed, 2);
    });

    testWidgets('a finger dips the back and gives it back as the turn '
        'begins', (tester) async {
      await tester.pumpWidget(_app(const _Flip()));
      final rest = tester.getRect(find.byKey(_back));
      await _set(tester, pressed: true);
      await tester.pump(Motion.press);
      final dipped = tester.getRect(find.byKey(_back));
      expect(dipped.width, closeTo(rest.width * (1 - PaperFlip.dip), 0.5));
      await _set(tester, pressed: false, turned: true);
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byKey(_faceKey)), rest);
    });
  });

  group('reduce motion', () {
    testWidgets('is a cut: the face at once, the back at once, a landing '
        'told, no dip', (tester) async {
      var landed = 0;
      await tester.pumpWidget(_app(_Flip(landed: () => landed++), still: true));
      final rest = tester.getRect(find.byKey(_back));
      await _set(tester, pressed: true);
      await tester.pump();
      expect(tester.getRect(find.byKey(_back)), rest);
      await _set(tester, turned: true);
      expect(find.byKey(_faceKey), findsOneWidget);
      expect(tester.getRect(find.byKey(_faceKey)), rest);
      expect(landed, 1);
      await _set(tester, turned: false, pressed: false);
      expect(find.byKey(_faceKey, skipOffstage: false), findsNothing);
      expect(find.byKey(_back), findsOneWidget);
      expect(tester.getRect(find.byKey(_back)), rest);
    });
  });

  group('your card in a hold', () {
    final seer = FaceContent.roleText(RoleId.seer);
    late List<MethodCall> buzzes;

    setUp(() => buzzes = []);

    Widget hold({bool still = false}) => _app(
      Center(
        child: HoldToReveal(
          inPlace: true,
          target: 'Your card',
          face: seer,
          cover: const SizedBox(
            key: _cover,
            width: 200,
            height: 266,
            child: ColoredBox(color: Colors.indigo, child: Text('Face down')),
          ),
        ),
      ),
      still: still,
    );

    Future<void> listen(WidgetTester tester) async {
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'HapticFeedback.vibrate') buzzes.add(call);
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
    }

    testWidgets('holding turns the card to its face and letting go turns it '
        'back, with no vibration at all (the owner, 23 Nov 2026)', (
      tester,
    ) async {
      await listen(tester);
      await tester.pumpWidget(hold());
      final card = find.byType(HoldToReveal);
      final frame = tester.getRect(card);
      final finger = await tester.startGesture(tester.getCenter(card));
      await tester.pump(HoldToReveal.holdDelay);
      await tester.pumpAndSettle();
      expect(find.byType(HeldFace), findsOneWidget);
      expect(tester.getRect(find.byType(HeldFace)), frame);
      expect(buzzes, isEmpty, reason: 'the face landing is silent');

      await finger.up();
      await tester.pumpAndSettle();
      expect(find.byType(HeldFace, skipOffstage: false), findsNothing);
      expect(buzzes, isEmpty, reason: 'letting go is silent');
    });

    testWidgets('let go before it lands: the face is gone at '
        'once', (tester) async {
      await listen(tester);
      await tester.pumpWidget(hold());
      final card = find.byType(HoldToReveal);
      final finger = await tester.startGesture(tester.getCenter(card));
      await tester.pump(HoldToReveal.holdDelay);
      await tester.pump(const Duration(milliseconds: 50));
      await finger.up();
      await tester.pump();
      await tester.pump(PaperFlip.turnBack);
      await tester.pump(const Duration(milliseconds: 1));
      expect(find.byType(HeldFace, skipOffstage: false), findsNothing);
      await tester.pumpAndSettle();
      expect(buzzes, isEmpty);
    });

    testWidgets('under reduce motion the face is there the frame it shows, '
        'without a buzz, and is gone on release', (tester) async {
      await listen(tester);
      await tester.pumpWidget(hold(still: true));
      final card = find.byType(HoldToReveal);
      final finger = await tester.startGesture(tester.getCenter(card));
      await tester.pump(HoldToReveal.holdDelay);
      expect(find.byType(HeldFace), findsOneWidget);
      expect(buzzes, isEmpty);
      await finger.up();
      await tester.pump();
      expect(find.byType(HeldFace, skipOffstage: false), findsNothing);
    });

    testWidgets('a finger that lands dips the card the same frame it '
        'starts, before it is a hold; a tap gives it back', (tester) async {
      await tester.pumpWidget(hold());
      final card = find.byType(HoldToReveal);
      final rest = tester.getRect(find.byKey(_cover));
      final finger = await tester.startGesture(tester.getCenter(card));
      // The first frame after the touch starts the dip.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 45));
      expect(tester.getRect(find.byKey(_cover)).width, lessThan(rest.width));
      await finger.up();
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byKey(_cover)), rest);
    });
  });

  group('races and edges', () {
    testWidgets('the face is not built, nor in semantics, before the edge', (
      tester,
    ) async {
      final handle = tester.ensureSemantics();
      await tester.pumpWidget(_app(const _Flip()));
      await _set(tester, turned: true);
      await tester.pump(const Duration(milliseconds: 8));
      expect(_across(tester), lessThan(1), reason: 'turning');
      // Asked for, it may be built, but offstage: not painted, not hit, and
      // out of the semantics tree.
      expect(find.byKey(_faceKey), findsNothing);
      final offstage = tester.widget<Offstage>(
        find
            .ancestor(
              of: find.byKey(_faceKey, skipOffstage: false),
              matching: find.byType(Offstage),
            )
            .first,
      );
      expect(offstage.offstage, isTrue);
      await tester.pump(const Duration(milliseconds: 100));
      expect(find.byKey(_faceKey), findsOneWidget);
      handle.dispose();
    });

    testWidgets('a parent rebuild mid-turn neither restarts nor skips it', (
      tester,
    ) async {
      await tester.pumpWidget(_app(const _Flip()));
      await _set(tester, turned: true);
      await tester.pump(const Duration(milliseconds: 40));
      final before = _across(tester);
      _state(tester).change();
      await tester.pump();
      expect(_across(tester), closeTo(before, 1e-6));
      await tester.pump(const Duration(milliseconds: 16));
      expect(_across(tester), greaterThan(before), reason: "past the edge");
      await tester.pumpAndSettle();
      expect(tester.getRect(find.byKey(_faceKey)).size, _size);
    });

    testWidgets('unmounting mid-turn throws nothing', (tester) async {
      await tester.pumpWidget(_app(const _Flip()));
      await _set(tester, turned: true);
      await tester.pump(const Duration(milliseconds: 40));
      await tester.pumpWidget(_app(const SizedBox()));
      await tester.pump(const Duration(seconds: 1));
      expect(tester.takeException(), isNull);
    });

    testWidgets('releasing in the first frame never shows the face', (
      tester,
    ) async {
      await tester.pumpWidget(_app(const _Flip()));
      await _set(tester, turned: true);
      await _set(tester, turned: false);
      for (var i = 0; i < 20; i++) {
        await tester.pump(const Duration(milliseconds: 16));
        expect(find.byKey(_faceKey, skipOffstage: false), findsNothing);
      }
      await tester.pumpAndSettle();
      expect(find.byKey(_faceKey, skipOffstage: false), findsNothing);
    });
  });

  group('your card in a hold, pressed twice', () {
    testWidgets('press, release, press ends face up and never buzzes', (
      tester,
    ) async {
      final buzzes = <MethodCall>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          if (call.method == 'HapticFeedback.vibrate') buzzes.add(call);
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      await tester.pumpWidget(
        _app(
          Center(
            child: HoldToReveal(
              inPlace: true,
              target: 'Your card',
              face: FaceContent.roleText(RoleId.seer),
              cover: const SizedBox(
                width: 200,
                height: 266,
                child: ColoredBox(color: Colors.indigo),
              ),
            ),
          ),
        ),
      );
      final card = find.byType(HoldToReveal);
      final first = await tester.startGesture(tester.getCenter(card));
      await tester.pump(HoldToReveal.holdDelay);
      await tester.pump(const Duration(milliseconds: 60));
      await first.up();
      await tester.pump(const Duration(milliseconds: 30));
      final second = await tester.startGesture(tester.getCenter(card));
      await tester.pump(HoldToReveal.holdDelay);
      await tester.pumpAndSettle();
      expect(find.byType(HeldFace), findsOneWidget);
      expect(buzzes, isEmpty);
      await second.up();
      await tester.pumpAndSettle();
      expect(find.byType(HeldFace, skipOffstage: false), findsNothing);
      expect(buzzes, isEmpty);
    });
  });
}
