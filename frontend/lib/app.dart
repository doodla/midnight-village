import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'design_system/skin/skin_choice.dart';

/// Root application widget.
class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Midnight Village',
      debugShowCheckedModeBanner: false,
      theme: ref.watch(appThemeProvider),
      routerConfig: ref.watch(appRouterProvider),
    );
  }
}
