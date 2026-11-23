import 'package:flutter/gestures.dart';
import 'package:flutter/material.dart';
import 'package:flutter/scheduler.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/primitives/primary_button.dart';

/// Presses [finder] the way a finger does: down, a frame drawn while the
/// finger is on the glass, up, a frame. The frame between moves the clock by
/// [hold] (none by default, so a picture's timing is the same as a tap's:
/// what the frame catches is a rebuild, which needs no time). `tester.tap` puts the finger down and
/// lifts it in the same instant, so it cannot see a press that a real phone
/// loses: one where the frame between down and up settles an animation and
/// rebuilds the button under the finger (the tap goes nowhere). Every press
/// of a screen's main action in a test is this: [installFingerRule] fails a
/// test whose finger lifts off a main button in the frame it went down.
Future<void> pressLikeAFinger(
  WidgetTester tester,
  Finder finder, {
  Duration hold = Duration.zero,
}) async {
  await pressAtLikeAFinger(tester, tester.getCenter(finder), hold: hold);
}

/// [pressLikeAFinger] at a point of the screen.
Future<void> pressAtLikeAFinger(
  WidgetTester tester,
  Offset point, {
  Duration hold = Duration.zero,
}) async {
  final gesture = await tester.startGesture(point);
  // A phone draws the next frame whether or not anything asked for one.
  tester.binding.scheduleFrame();
  await tester.pump(hold);
  await gesture.up();
  await tester.pump();
}

/// Installed for every test (flutter_test_config.dart): a [PrimaryButton]
/// (a screen's main action) that acts on a finger that went down in this
/// same frame fails the test, with how to press it instead. A tap a screen
/// reader or a keyboard makes is not a finger's and is not held to it.
void installFingerRule() {
  var frames = 0;
  int? downAt;
  SchedulerBinding.instance.addPersistentFrameCallback((_) => frames++);
  GestureBinding.instance.pointerRouter.addGlobalRoute((event) {
    if (event is PointerDownEvent) downAt = frames;
  });
  PrimaryButton.debugOnAct = (button) {
    if (downAt != frames || _plainOnPurpose) return true;
    throw FlutterError(
      'A main button ("${button.label}") was pressed with no frame between '
      'the finger going down and coming up (a plain `tester.tap`). On a real '
      'phone a frame is drawn while the finger is on the glass, and a button '
      'that settles an animation and rebuilds in that frame loses the tap; '
      '`tester.tap` cannot see it. Press it with '
      '`pressLikeAFinger(tester, finder)` (test/helpers/finger.dart).',
    );
  };
}

var _plainOnPurpose = false;

/// A plain `tester.tap` on a main button, on purpose, saying [why]: a test
/// that counts frames from the tap, or a press a finger loses today that is
/// still to be looked at (the why says which). Each is a to-do: the rule
/// above is what holds.
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
