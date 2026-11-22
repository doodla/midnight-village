import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/design_system/copy/copy.dart';
import 'package:midnight_village/design_system/layout/space.dart';
import 'package:midnight_village/design_system/primitives/waiting_sign.dart';

import '../../helpers/pump_skinned.dart';

/// The one body every waiting screen has: nothing at first (an answer that
/// comes quickly shows no sign), then a sign of life, then one plain line
/// when it is slow, and "One moment" while a fetch fails.
void main() {
  double signOpacity(WidgetTester tester) => tester
      .widget<AnimatedOpacity>(
        find.descendant(
          of: find.byType(WaitingSign),
          matching: find.byType(AnimatedOpacity),
        ),
      )
      .opacity;

  testWidgets('shows no sign when the answer comes within the first '
      'moment, so a quick load never flashes one', (tester) async {
    await pumpSkinned(tester, const Waiting());
    expect(signOpacity(tester), 0);
    await tester.pump(Motion.signAfter - const Duration(milliseconds: 1));
    expect(signOpacity(tester), 0);
    // Answered: the wait is gone with the sign never drawn.
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('the sign comes in after the first moment, and turns', (
    tester,
  ) async {
    await pumpSkinned(tester, const Waiting());
    await tester.pump(Motion.signAfter);
    await tester.pump(Motion.settle);
    expect(signOpacity(tester), 1);

    Offset first() => tester.getTopLeft(
      find
          .descendant(
            of: find.byType(WaitingSign),
            matching: find.byType(Container),
          )
          .first,
    );
    final rest = first();
    await tester.pump(Motion.waitLoop ~/ 6);
    expect(first(), isNot(rest), reason: 'the first lantern lifts');
    await tester.pump(Motion.waitLoop);
    expect(find.text(BannerCopy.slow), findsNothing);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a long wait is named once, plainly', (tester) async {
    await pumpSkinned(tester, const Waiting());
    await tester.pump(Motion.slowAfter - const Duration(milliseconds: 10));
    expect(find.text(BannerCopy.slow), findsNothing);
    await tester.pump(const Duration(milliseconds: 20));
    expect(find.text(BannerCopy.slow), findsOneWidget);
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('a failing fetch says "One moment", with "Try again" to read '
      'it now when it can', (tester) async {
    var tried = 0;
    await pumpSkinned(tester, Waiting(failing: true, onRetry: () => tried++));
    expect(find.text(BannerCopy.offline), findsOneWidget);
    await tester.tap(find.text(BannerCopy.tryAgain));
    expect(tried, 1);
    await tester.pump(Motion.slowAfter);
    expect(
      find.text(BannerCopy.slow),
      findsNothing,
      reason: 'failing is told once, not with the slow line over it',
    );
    await tester.pumpWidget(const SizedBox());
  });

  testWidgets('with reduce motion the lanterns stand still, in view', (
    tester,
  ) async {
    tester.platformDispatcher.accessibilityFeaturesTestValue =
        const FakeAccessibilityFeatures(disableAnimations: true);
    addTearDown(tester.platformDispatcher.clearAccessibilityFeaturesTestValue);
    await pumpSkinned(tester, const Waiting());
    await tester.pump(Motion.signAfter);
    await tester.pump();
    expect(signOpacity(tester), 1, reason: 'the sign is cut in');
    await tester.pump(Motion.waitLoop);
    expect(
      tester.binding.hasScheduledFrame,
      isFalse,
      reason: 'nothing turns, so no frame is asked for',
    );
    await tester.pumpWidget(const SizedBox());
  });
}
