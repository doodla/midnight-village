import 'package:flutter/widgets.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/primitives/mood.dart';

/// How long a test waits, on the real clock, for something real to finish (a
/// picture decoding, a file read). Generous on purpose: a passing test never
/// waits it out, and a machine under load is slow, not broken.
const realPatience = Duration(seconds: 30);

/// Waits on the REAL clock until [done], drawing a frame between looks.
///
/// For work the fake test clock cannot move: decoding and file I/O. A test
/// waits on the thing itself, never on a stretch of time that "should be
/// enough": that guess fails on a busy machine. Fails, naming [what], when
/// [realPatience] runs out.
Future<void> untilReal(
  WidgetTester tester,
  bool Function() done, {
  required String what,
}) async {
  final waited = Stopwatch()..start();
  while (!done()) {
    if (waited.elapsed > realPatience) {
      fail('waited ${realPatience.inSeconds} s of real time for $what');
    }
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 5)),
    );
    await tester.pump();
  }
}

/// Waits until every [Mood] on screen shows its finished picture (its layers
/// decode on real I/O; before that it paints the bare ground).
Future<void> untilMoodsArePainted(WidgetTester tester) => untilReal(
  tester,
  () => find
      .byType(Mood)
      .evaluate()
      .every(
        (mood) => find
            .descendant(
              of: find.byElementPredicate((e) => e == mood),
              matching: find.byType(RawImage),
            )
            .evaluate()
            .isNotEmpty,
      ),
  what: 'every mood on screen to show its finished picture',
);
