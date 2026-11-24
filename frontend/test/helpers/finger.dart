// Guard file: a change here needs its line in the pull request (tool/guard_edits.py).
import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/primitives/chips.dart';
import 'package:midnight_village/design_system/primitives/face_down_card.dart';
import 'package:midnight_village/design_system/primitives/icon_action.dart';
import 'package:midnight_village/design_system/primitives/paper_scrap.dart';
import 'package:midnight_village/design_system/primitives/player_row.dart';
import 'package:midnight_village/design_system/primitives/primary_button.dart';
import 'package:midnight_village/design_system/primitives/role_card.dart';
import 'package:midnight_village/design_system/primitives/secondary_button.dart';
import 'package:midnight_village/design_system/primitives/text_action.dart';

// A finger on the glass. `tester.tap` puts the finger down and lifts it in the
// same instant, so it cannot see a press that a real phone loses: one where
// the frames drawn while the finger is down (an animation settling, a rebuild
// started by the touch) rebuild the action under the finger, so the lift goes
// to a detector that is gone. Every press of one of the kit's actions in a
// test is [pressLikeAFinger]: [installFingerRule] fails a test whose finger
// lifts in the frame it went down, on anything that takes a tap. Nothing in the app is
// changed for it: the rule watches the pointer and the tree.

/// How long a finger rests on the glass in a test's press: a quick tap (the
/// owner's taps last under a tenth of a second), drawn frame by frame.
const fingerFrames = 6;
const fingerFrame = Duration(milliseconds: 16);

/// The kit's actions, acting: what a player's finger presses on a screen (the
/// main and secondary buttons, a scrap, an icon or text action, a preset, a
/// vote's row, a card picked on the night board, a role card on the deck).
/// A waiting, done or busy button is not acting: a tap on it does nothing.
bool isAction(Widget widget) => switch (widget) {
  PrimaryButton(:final phase, :final busy) => switch (phase) {
    ButtonPhase.ready => !busy,
    ButtonPhase.quiet || ButtonPhase.on || ButtonPhase.locked => true,
    ButtonPhase.waiting || ButtonPhase.done => false,
  },
  SecondaryButton(:final busy, :final onPressed, :final onLockedTap) =>
    !busy && (onPressed != null || onLockedTap != null),
  PaperScrap() => true,
  IconAction(:final onPressed) ||
  TextAction(:final onPressed) => onPressed != null,
  PresetChip(:final onTap) ||
  PlayerRow(:final onTap) ||
  FaceDownCard(:final onTap) ||
  RoleCard(:final onTap) => onTap != null,
  _ => false,
};

/// What a finger going down at a point reaches: the action under it (its
/// element) and the gesture detectors between the finger and that action
/// (what the lift must reach). Null when the point holds no action.
class Touch {
  Touch._(this.action, this.detectors);

  final Element action;
  final List<Element> detectors;

  /// The lift still reaches what the finger went down on: the action and
  /// its detectors are the same, still in the tree (a detector rebuilt as a
  /// new one forgets the finger, and the tap goes nowhere).
  bool get holds =>
      action.mounted &&
      detectors.isNotEmpty &&
      detectors.every((d) => d.mounted);

  /// The action under [position] on the screen, front first.
  static Touch? at(Offset position, {int viewId = 0}) {
    final result = HitTestResult();
    RendererBinding.instance.hitTestInView(result, position, viewId);
    for (final entry in result.path) {
      final target = entry.target;
      if (target is! RenderObject) continue;
      final creator = target.debugCreator;
      if (creator is! DebugCreator) continue;
      final detectors = <Element>[];
      Element? action;
      void look(Element e) {
        if (e.widget is RawGestureDetector) detectors.add(e);
        if (isAction(e.widget)) action = e;
      }

      look(creator.element);
      creator.element.visitAncestorElements((e) {
        look(e);
        return action == null;
      });
      if (action != null) return Touch._(action!, detectors);
    }
    return null;
  }
}

/// Presses [finder] the way a finger does: down, [fingerFrames] frames of
/// [fingerFrame] drawn while the finger is on the glass, up, a frame. A tree
/// that changes shape under the finger in those frames loses the tap here as
/// it would on a phone. Returns what the finger went down on (null: no
/// action there) so a test can ask whether the lift still reached it.
/// [beforeLift] runs with the finger still down, after its frames: what the
/// tap sends begins at the lift, so a test that counts the requests a tap
/// makes counts from there (the screen's own polls go on while the finger
/// is down, as on a phone).
Future<Touch?> pressLikeAFinger(
  WidgetTester tester,
  Finder finder, {
  void Function()? beforeLift,
}) => pressAtLikeAFinger(
  tester,
  tester.getCenter(finder),
  beforeLift: beforeLift,
);

/// [pressLikeAFinger] at a point of the screen. [lift] false takes the finger
/// away without a tap (a cancel): what the press would set off is not set
/// off, and the returned [Touch] still says whether it would have.
Future<Touch?> pressAtLikeAFinger(
  WidgetTester tester,
  Offset point, {
  bool lift = true,
  void Function()? beforeLift,
}) async {
  final touch = Touch.at(point);
  final gesture = await tester.startGesture(point);
  for (var i = 0; i < fingerFrames; i++) {
    // A phone draws its frames whether or not anything asked for one.
    tester.binding.scheduleFrame();
    await tester.pump(fingerFrame);
  }
  beforeLift?.call();
  if (lift) {
    await gesture.up();
  } else {
    await gesture.cancel();
  }
  await tester.pump();
  return touch;
}

/// What takes a tap under [position]: the nearest named widget around a
/// gesture detector that recognises a tap, front first; null when nothing
/// there does. This is what a pressable IS, whatever it is called: a main
/// button, a card, a scrap, a row, the layer that takes a tap anywhere, a
/// part added tomorrow. No list of names.
Widget? tapTakerAt(Offset position, {int viewId = 0}) {
  final result = HitTestResult();
  RendererBinding.instance.hitTestInView(result, position, viewId);
  for (final entry in result.path) {
    final target = entry.target;
    if (target is! RenderObject) continue;
    final creator = target.debugCreator;
    if (creator is! DebugCreator) continue;
    var takesTap = false;
    Widget? named;
    bool look(Element e) {
      final widget = e.widget;
      if (widget is RawGestureDetector &&
          widget.gestures.keys.any((type) => '$type'.contains('Tap'))) {
        takesTap = true;
      } else if (takesTap &&
          !_plumbing.contains(widget.runtimeType) &&
          !'${widget.runtimeType}'.startsWith('_')) {
        named = widget;
      }
      return named == null;
    }

    if (look(creator.element)) creator.element.visitAncestorElements(look);
    if (takesTap) return named ?? creator.element.widget;
  }
  return null;
}

/// What sits between a detector and the part that owns it.
const _plumbing = {
  GestureDetector,
  RawGestureDetector,
  Listener,
  Semantics,
  RepaintBoundary,
  MouseRegion,
  Builder,
};

/// Test files whose plain taps are not converted yet, each with why. The
/// rule lets their taps pass; `finger_rule_test.dart` fails an entry whose
/// file no longer taps plainly, so the list only shrinks.
const notYetHeld = <String, String>{};

/// Installed for every test (flutter_test_config.dart): a finger that lifts
/// in the frame it went down (a plain `tester.tap`) on ANYTHING that takes a
/// tap ([tapTakerAt]) fails the test, with how to press it instead. A tap a
/// screen reader or a keyboard makes is not a finger's and is not held to
/// it. Nothing in the app is hooked for it: the rule watches the pointer.
void installFingerRule() {
  var frames = 0;
  final downs = <int, (int, DateTime, Widget?, Offset)>{};
  DateTime now() => TestWidgetsFlutterBinding.instance.clock.now();
  SchedulerBinding.instance.addPersistentFrameCallback((_) => frames++);
  GestureBinding.instance.pointerRouter.addGlobalRoute((event) {
    if (event is PointerDownEvent) {
      downs[event.pointer] = (
        frames,
        now(),
        tapTakerAt(event.position),
        event.position,
      );
    } else if (event is PointerUpEvent || event is PointerCancelEvent) {
      final down = downs.remove(event.pointer);
      if (event is! PointerUpEvent || down == null || _plainOnPurpose) return;
      final (at, since, taker, from) = down;
      // A frame drawn, or time passed with the finger down (a press a test
      // wrote out by hand, on a part that had nothing to redraw): not instant.
      if (at != frames || now() != since || taker == null) return;
      // A finger that moved is a drag, not a tap.
      if ((event.position - from).distance > kTouchSlop) return;
      final stack = '${StackTrace.current}';
      if (notYetHeld.keys.any(stack.contains)) return;
      throw FlutterError(
        'Something that takes a tap (${taker.runtimeType}) was pressed with '
        'no frame between the finger going down and coming up (a plain '
        '`tester.tap`). On a real phone frames are drawn while the finger is '
        'on the glass, and a part that settles an animation and rebuilds '
        'in them loses the tap; `tester.tap` cannot see it. Press it with '
        '`pressLikeAFinger(tester, finder)` or `pressAtLikeAFinger(tester, '
        'point)` (test/helpers/finger.dart).',
      );
    }
  });
}

var _plainOnPurpose = false;

/// A plain `tester.tap` on an action, on purpose, saying [why]: a test or a
/// gallery picture that counts its frames from the tap. Each is a to-do: the
/// rule above is what holds.
Future<void> plainTap(
  WidgetTester tester,
  Finder finder, {
  required String why,
}) async {
  assert(why.isNotEmpty);
  _plainOnPurpose = true;
  try {
    await tester.tap(finder);
  } finally {
    _plainOnPurpose = false;
  }
}
