import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:midnight_village/core/router/back_policy.dart';
import 'package:midnight_village/design_system/layout/space.dart';
import 'package:midnight_village/design_system/primitives/scene_switcher.dart';
import 'package:midnight_village/design_system/skin/skin_id.dart';
import 'package:midnight_village/design_system/skin/skin_theme.dart';

// The one back policy on its own: what answers Back, in what order, and when
// Back may leave the app. (Every screen of the app: test/features/back_test.dart.)

/// Back, as the platform sends it (Android's back, the browser's on the web).
Future<void> _back(WidgetTester tester) async {
  await tester.binding.defaultBinaryMessenger.handlePlatformMessage(
    SystemChannels.navigation.name,
    SystemChannels.navigation.codec.encodeMethodCall(
      const MethodCall('popRoute'),
    ),
    (_) {},
  );
  await tester.pump();
}

/// The page's verdict on Back with nothing above it: bubble = leave the app.
RoutePopDisposition _disposition(WidgetTester tester) =>
    ModalRoute.of(tester.element(find.byKey(_page)))!.popDisposition;

const _page = Key('page');

Future<void> _pump(WidgetTester tester, BackRule rule, Widget child) =>
    tester.pumpWidget(
      MaterialApp(
        theme: skinTheme(SkinId.fallback.skin),
        home: BackPolicy(
          rule: rule,
          child: SizedBox(key: _page, child: child),
        ),
      ),
    );

void main() {
  testWidgets('only "leaves the app" lets Back leave, and only with nothing '
      'open', (tester) async {
    for (final rule in BackRule.values) {
      await _pump(tester, rule, const SizedBox());
      expect(
        _disposition(tester),
        rule == BackRule.leavesApp
            ? RoutePopDisposition.bubble
            : RoutePopDisposition.doNotPop,
        reason: rule.name,
      );
    }
    await _pump(
      tester,
      BackRule.leavesApp,
      BackHandler(onBack: () {}, child: const SizedBox()),
    );
    expect(_disposition(tester), RoutePopDisposition.doNotPop);
  });

  testWidgets('the last one opened answers first; one closed answers no '
      'more; one opened again is the last again', (tester) async {
    final answered = <String>[];
    Widget page({required bool a, required bool b}) => Column(
      children: [
        BackHandler(
          open: a,
          onBack: () => answered.add('a'),
          child: const SizedBox(),
        ),
        BackHandler(
          open: b,
          onBack: () => answered.add('b'),
          child: const SizedBox(),
        ),
      ],
    );

    await _pump(tester, BackRule.staysPut, page(a: true, b: true));
    await _back(tester);
    expect(answered, ['b']);

    await _pump(tester, BackRule.staysPut, page(a: true, b: false));
    await _back(tester);
    expect(answered, ['b', 'a']);

    // b opens again after a: b is the last opened.
    await _pump(tester, BackRule.staysPut, page(a: true, b: true));
    await _back(tester);
    expect(answered, ['b', 'a', 'b']);
  });

  testWidgets('a sheet open on top closes first; the page is not asked', (
    tester,
  ) async {
    var asked = 0;
    await _pump(
      tester,
      BackRule.staysPut,
      BackHandler(onBack: () => asked++, child: const SizedBox()),
    );
    unawaited(
      showModalBottomSheet<void>(
        context: tester.element(find.byKey(_page)),
        builder: (_) => const Text('sheet'),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('sheet'), findsOneWidget);
    await _back(tester);
    await tester.pumpAndSettle();
    expect(find.text('sheet'), findsNothing);
    expect(asked, 0);
    await _back(tester);
    expect(asked, 1);
  });

  testWidgets('a screen on its way out answers nothing: Back goes to the '
      'one arriving, by its rule', (tester) async {
    var leaving = 0;
    Widget at(String stage) => SceneSwitcher<String>(
      stage: stage,
      sceneBetween: (_, _) => null,
      child: stage == 'a'
          ? BackHandler(onBack: () => leaving++, child: const SizedBox())
          : const SizedBox(),
    );
    await _pump(tester, BackRule.staysPut, at('a'));
    await _pump(tester, BackRule.leavesApp, at('b'));
    // Mid-crossfade: the first screen is still in the tree, fading out.
    await tester.pump(Motion.settle ~/ 2);
    expect(find.byType(BackHandler), findsOneWidget);
    expect(_disposition(tester), RoutePopDisposition.bubble);
    await _back(tester);
    expect(leaving, 0);
    await tester.pumpAndSettle();
  });

  testWidgets('outside a policy (a gallery picture) it does nothing', (
    tester,
  ) async {
    await tester.pumpWidget(
      MaterialApp(
        home: BackHandler(
          onBack: () => fail('no policy'),
          child: const SizedBox(),
        ),
      ),
    );
    await _back(tester);
  });
}
