import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/skin/elevation.dart';
import 'package:midnight_village/design_system/copy/copy.dart';
import 'package:midnight_village/design_system/layout/space.dart';
import 'package:midnight_village/design_system/primitives/face_down_card.dart';
import 'package:midnight_village/design_system/primitives/primary_button.dart';
import 'package:midnight_village/design_system/skin/skin_id.dart';

import 'package:midnight_village/design_system/teach/learned_store.dart';

import '../../helpers/frame_pixels.dart';
import '../../helpers/sheet/sheet_data.dart';
import 'board_harness.dart';

// How picking a card feels (polish pass 2, docs/design/feel.md, "Night
// action"): a finger dips the card the frame it lands; a pick lifts it with
// the selection's outline, a soft bone glow and a deeper hard shadow; letting
// go of a pick returns it cleanly; the same for every card and every role;
// nothing moves or sounds for anyone else; reduce motion cuts to the end
// state; and the waiting button is a slot that the amber paper rises out of.

final _night = SkinId.fallback.skin.night;

/// The card [label]'s own back (its decoration) and the AnimatedContainer
/// that moves the whole card (its transform).
AnimatedContainer _back(WidgetTester tester, String label) => tester
    .widgetList<AnimatedContainer>(
      find.descendant(
        of: card(label),
        matching: find.byType(AnimatedContainer),
      ),
    )
    .firstWhere((c) => c.decoration is BoxDecoration);

AnimatedContainer _mover(WidgetTester tester, String label) => tester
    .widgetList<AnimatedContainer>(
      find.descendant(
        of: card(label),
        matching: find.byType(AnimatedContainer),
      ),
    )
    .firstWhere((c) => c.transform != null);

/// How far down the card is drawn (negative: lifted).
double _dy(WidgetTester tester, String label) =>
    _mover(tester, label).transform!.getTranslation().y;

/// How high the card lies: read from its cast (the paper shadow's fall).
double _drop(WidgetTester tester, String label) =>
    _shadows(
      tester,
      label,
    ).firstWhere((s) => s.spreadRadius > 0 && s.blurRadius == 0).offset.dy /
    PaperShadow.castFall;

List<BoxShadow> _shadows(WidgetTester tester, String label) =>
    (_back(tester, label).decoration! as BoxDecoration).boxShadow!;

BoxDecoration _ring(WidgetTester tester, String label) =>
    _back(tester, label).foregroundDecoration! as BoxDecoration;

double _ringWidth(WidgetTester tester, String label) =>
    ((_ring(tester, label).border!) as Border).top.width;

/// [viewer]'s phone in a later game: the hold and the wave are learned, so
/// nothing keeps moving by itself (the ring's breath, the opening wave).
BoardHarness _veteran(Viewer viewer) =>
    BoardHarness.of(viewer, learned: {Cue.hold, Cue.nightChoose});

/// The first other seat's name.
String _seat(BoardHarness board) =>
    board.seats.firstWhere((s) => s.id != board.selfId).name;

void main() {
  group('a finger on a card', () {
    testWidgets('dips it 2 px the frame it lands, the shadow staying where '
        'it was, and it comes back when the finger lifts', (tester) async {
      final board = _veteran(Viewer.seer);
      await board.pump(tester);
      final name = _seat(board);
      expect(_dy(tester, name), 0);
      final lying = _drop(tester, name);

      final finger = await tester.startGesture(tester.getCenter(card(name)));
      await tester.pump();
      // The first frame after the touch already has the card going down.
      expect(_dy(tester, name), FaceDownCard.dip);
      expect(
        _mover(tester, name).duration,
        Motion.press,
        reason: 'the dip is a press',
      );
      expect(_drop(tester, name), closeTo(lying - FaceDownCard.dip, 1e-9));
      await tester.pump(Motion.press);

      await finger.up();
      await tester.pump();
      expect(_dy(tester, name), anyOf(0, -FaceDownCard.lift));
      await tester.pumpAndSettle();
    });

    testWidgets('sliding off cancels: it comes back and nothing is picked', (
      tester,
    ) async {
      final board = _veteran(Viewer.seer);
      await board.pump(tester);
      final name = _seat(board);
      final finger = await tester.startGesture(tester.getCenter(card(name)));
      await tester.pump(Motion.press);
      expect(_dy(tester, name), FaceDownCard.dip);
      await finger.moveBy(const Offset(0, -400));
      await finger.cancel();
      await tester.pumpAndSettle();
      expect(_dy(tester, name), 0);
      expect(lifted(tester), isEmpty);
    });

    testWidgets('every card answers the same way, whatever the role: an '
        'actor’s, a sleeper’s, a card a pick cannot take', (tester) async {
      final dips = <String>[];
      for (final viewer in [
        Viewer.seer,
        Viewer.villager,
        Viewer.robber,
        Viewer.drunk,
      ]) {
        final board = _veteran(viewer);
        await tester.pumpWidget(const SizedBox());
        await board.pump(tester);
        for (final name in [_seat(board), NightCopy.left, NightCopy.you]) {
          final finger = await tester.startGesture(
            tester.getCenter(card(name)),
          );
          await tester.pump();
          dips.add(
            '$name ${_dy(tester, name)} ${_mover(tester, name).duration}',
          );
          await finger.up();
          await tester.pumpAndSettle();
        }
      }
      // Four phones, three cards each: one answer per card, no phone's
      // different.
      expect(
        {for (final d in dips) d.replaceFirst(RegExp(r'^\S+ '), '')},
        {'2.0 0:00:00.090000'},
      );
    });
  });

  group('a pick', () {
    testWidgets('lifts the card 8 px with the bone outline, a soft glow and '
        'a deeper hard shadow', (tester) async {
      final board = _veteran(Viewer.seer);
      await board.pump(tester);
      final name = _seat(board);
      // At rest: no light (a clear shadow with no blur: nothing to paint),
      // the lying shadow, the hairline ring.
      expect(_shadows(tester, name).first.color.a, 0);
      expect(_shadows(tester, name).first.blurRadius, 0);
      final lying = _drop(tester, name);
      final hairline = _ringWidth(tester, name);

      await tapCard(tester, name);
      expect(lifted(tester), [name]);
      expect(_dy(tester, name), -FaceDownCard.lift);
      expect(_mover(tester, name).duration, Motion.quick);
      final shadows = _shadows(tester, name);
      expect(shadows, hasLength(2 + PaperShadow.castSteps));
      final glow = shadows.first;
      expect(glow.color, _night.elevation.glow);
      expect(glow.blurRadius, FaceDownCard.glowBlur);
      expect(glow.color.a, greaterThan(0.3), reason: 'the glow is seen');
      expect(_drop(tester, name), 10, reason: 'a deeper one');
      expect(_drop(tester, name), greaterThan(lying));
      expect(shadows.last.blurRadius, 0, reason: 'the shadow stays paper');
      expect(_ringWidth(tester, name), greaterThan(hairline));
      expect(
        ((_ring(tester, name).border!) as Border).top.color,
        _night.selection,
        reason: 'the outline is bone, never amber',
      );
      await tester.pumpAndSettle();
      expect(tester.hasRunningAnimations, isFalse);
    });

    testWidgets('a second tap returns it cleanly: back down, the light '
        'out, the lying shadow and the thin ring again', (tester) async {
      final board = _veteran(Viewer.seer);
      await board.pump(tester);
      final name = _seat(board);
      final lying = _shadows(tester, name).last.offset;
      final hairline = _ringWidth(tester, name);
      await tapCard(tester, name);
      await tester.pumpAndSettle();
      await tapCard(tester, name);
      expect(lifted(tester), isEmpty);
      expect(_dy(tester, name), 0);
      await tester.pumpAndSettle();
      expect(_dy(tester, name), 0);
      expect(_shadows(tester, name).first.color.a, 0);
      expect(_shadows(tester, name).last.offset, lying);
      expect(_ringWidth(tester, name), hairline);
    });

    testWidgets('a third pick drops the oldest as the new one rises, in one '
        'frame', (tester) async {
      final board = _veteran(Viewer.seer);
      await board.pump(tester);
      await tapCard(tester, NightCopy.left);
      await tapCard(tester, NightCopy.right);
      await tester.pumpAndSettle();
      await tapCard(tester, NightCopy.middle);
      expect(lifted(tester), [NightCopy.middle, NightCopy.right]);
      expect(_dy(tester, NightCopy.left), 0);
      expect(_dy(tester, NightCopy.middle), -FaceDownCard.lift);
    });

    testWidgets('the cards a pick cannot join dim, and a tap on one still '
        'dips it and switches the pick', (tester) async {
      final board = _veteran(Viewer.seer);
      await board.pump(tester);
      final name = _seat(board);
      await tapCard(tester, NightCopy.left);
      await tester.pumpAndSettle();
      final dimmed = tester.widget<AnimatedOpacity>(
        find.descendant(of: card(name), matching: find.byType(AnimatedOpacity)),
      );
      expect(dimmed.opacity, closeTo(0.4, 0.001));
      final finger = await tester.startGesture(tester.getCenter(card(name)));
      await tester.pump();
      expect(_dy(tester, name), FaceDownCard.dip);
      await finger.up();
      await tester.pumpAndSettle();
      expect(lifted(tester), [name], reason: 'the pick switched');
    });

    testWidgets('nothing buzzes at night: no vibration for a touch, a pick '
        'or a choose', (tester) async {
      final calls = <String>[];
      tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        (call) async {
          calls.add(call.method);
          return null;
        },
      );
      addTearDown(
        () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
          SystemChannels.platform,
          null,
        ),
      );
      final board = _veteran(Viewer.seer);
      await board.pump(tester);
      final name = _seat(board);
      final finger = await tester.startGesture(tester.getCenter(card(name)));
      await tester.pump();
      await finger.up();
      await tester.pumpAndSettle();
      await tapCard(tester, name);
      await tester.tap(find.byType(PrimaryButton));
      await tester.pumpAndSettle();
      expect(calls.where((c) => c.contains('HapticFeedback')), isEmpty);
    });
  });

  group('reduce motion', () {
    Widget reduced(Widget board) => MediaQuery(
      data: const MediaQueryData(disableAnimations: true),
      child: board,
    );

    testWidgets('cuts every part of the feel to its end state: the dip, '
        'the lift, the light, the dim', (tester) async {
      final board = _veteran(Viewer.seer);
      await board.pump(tester, wrap: reduced);
      final name = _seat(board);
      final finger = await tester.startGesture(tester.getCenter(card(name)));
      await tester.pump();
      expect(_dy(tester, name), FaceDownCard.dip);
      expect(_mover(tester, name).duration, Duration.zero);
      // Letting go is the tap: the card is picked, lifted at once.
      await finger.up();
      await tester.pump();
      expect(_dy(tester, name), -FaceDownCard.lift);
      expect(_mover(tester, name).duration, Duration.zero);
      expect(_back(tester, name).duration, Duration.zero);
      final other = find.descendant(
        of: card(NightCopy.left),
        matching: find.byType(AnimatedOpacity),
      );
      expect(tester.widget<AnimatedOpacity>(other).duration, Duration.zero);
      // The information is the same: the card is lifted and outlined.
      expect(lifted(tester), [name]);
      expect(_shadows(tester, name).first.color.a, greaterThan(0.3));
    });
  });

  group('the Choose button', () {
    PrimaryButton choose(WidgetTester tester) =>
        tester.widget<PrimaryButton>(find.byType(PrimaryButton));

    AnimatedContainer shell(WidgetTester tester) => tester.widget(
      find.descendant(
        of: find.byType(PrimaryButton),
        matching: find.byType(AnimatedContainer),
      ),
    );

    testWidgets('waits as a slot on purpose: the spec’s outline with no fill, '
        'clearly drawn, a dark lip inside its top edge, its words in full '
        'ink', (tester) async {
      await _veteran(Viewer.seer).pump(tester);
      expect(choose(tester).phase, ButtonPhase.locked);
      expect(choose(tester).slot, isTrue);
      final decoration = shell(tester).decoration! as BoxDecoration;
      expect(decoration.color, isNull, reason: 'disabled: outlined, no fill');
      final border = decoration.border! as Border;
      expect(border.top.color, _night.outline, reason: 'the outline is seen');
      expect(border.top.width, greaterThanOrEqualTo(2));
      expect(shell(tester).foregroundDecoration, isNotNull, reason: 'its lip');
      final words = tester.widget<Text>(find.text(NightCopy.chooseNone));
      expect(words.style!.color, _night.text, reason: 'full ink');
      // The same words, the same height as before: nothing was added.
      expect(tester.getSize(find.byType(PrimaryButton)).height, 48);
      expect(find.text(NightCopy.chooseNone), findsOneWidget);
    });

    testWidgets('becomes the amber button the frame the picks are whole, '
        'rising out of the slot, and takes the tap at once', (tester) async {
      final board = _veteran(Viewer.seer);
      await board.pump(tester);
      await tapCard(tester, _seat(board));
      // That frame: ready, amber paper, drawn down in the slot, easing up.
      expect(choose(tester).phase, ButtonPhase.ready);
      expect(choose(tester).rises, isTrue);
      expect(shell(tester).duration, Motion.quick);
      expect((shell(tester).decoration! as BoxDecoration).color, _night.accent);
      expect(
        shell(tester).transform!.getTranslation().y,
        greaterThan(0),
        reason: 'it starts down in the slot',
      );
      // A tap before it has finished rising is a choose.
      await tester.tap(find.byType(PrimaryButton));
      await tester.pump();
      expect(board.sent, hasLength(1));
      await tester.pumpAndSettle();
    });

    testWidgets('has risen to rest after quick: no offset, the amber '
        'shadow whole', (tester) async {
      final board = _veteran(Viewer.seer);
      await board.pump(tester);
      await tapCard(tester, _seat(board));
      await tester.pump();
      await tester.pump(Motion.quick);
      await tester.pumpAndSettle();
      final t = shell(tester).transform;
      expect(t == null || t.getTranslation().x == 0, isTrue);
      final shadows = (shell(tester).decoration! as BoxDecoration).boxShadow!;
      expect(shadows.last.offset, const Offset(0, 3), reason: 'the backing');
    });

    testWidgets('taking the pick back returns it to the slot; a button that '
        'was never waiting does not rise', (tester) async {
      final board = _veteran(Viewer.seer);
      await board.pump(tester);
      final name = _seat(board);
      await tapCard(tester, name);
      await tester.pumpAndSettle();
      await tapCard(tester, name);
      expect(choose(tester).phase, ButtonPhase.locked);
      expect(choose(tester).slot, isTrue);
      // The amber is cut out at once, never blended into the slot: the
      // button's own paper is the ground's from the first frame.
      final button = tester.getRect(find.byType(PrimaryButton));
      final frame = await FramePixels.of(tester);
      final inside = frame.at(button.left + 10, button.center.dy + 8);
      // The ground there is the mood's (a vignette of the night), so it is
      // read beside the button, in the same light.
      final beside = frame.at(button.left - 8, button.center.dy + 8);
      for (final shift in [0, 8, 16]) {
        expect(
          ((inside >> shift) & 0xFF) - ((beside >> shift) & 0xFF),
          inInclusiveRange(-6, 6),
        );
      }
      await tester.pumpAndSettle();
      expect((shell(tester).decoration! as BoxDecoration).color, isNull);
    });

    testWidgets('reduce motion: the amber is there at once, no rise', (
      tester,
    ) async {
      final board = _veteran(Viewer.seer);
      await board.pump(
        tester,
        wrap: (child) => MediaQuery(
          data: const MediaQueryData(disableAnimations: true),
          child: child,
        ),
      );
      await tapCard(tester, _seat(board));
      expect(shell(tester).duration, Duration.zero);
      await tester.pump();
      await tester.pump();
      final t = shell(tester).transform;
      expect(t == null || t.getTranslation().x == 0, isTrue);
      expect((shell(tester).decoration! as BoxDecoration).color, _night.accent);
    });

    testWidgets('the target stays 48 or more in every state', (tester) async {
      final board = _veteran(Viewer.seer);
      await board.pump(tester);
      double height() => tester.getSize(find.byType(PrimaryButton)).height;
      expect(height(), greaterThanOrEqualTo(48));
      await tapCard(tester, _seat(board));
      await tester.pumpAndSettle();
      expect(height(), greaterThanOrEqualTo(48));
      await tester.tap(find.byType(PrimaryButton));
      await tester.pumpAndSettle();
      expect(height(), greaterThanOrEqualTo(48));
    });
  });
}
