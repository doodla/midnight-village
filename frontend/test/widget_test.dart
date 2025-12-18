import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'package:midnight_village/app.dart';

void main() {
  testWidgets('App initializes smoke test', (WidgetTester tester) async {
    // Build our app and trigger a frame.
    await tester.pumpWidget(const ProviderScope(child: App()));

    // Verify that the app renders without crashing.
    expect(find.byType(MaterialApp), findsOneWidget);
  });
}
