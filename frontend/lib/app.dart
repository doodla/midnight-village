import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'design_system/skin/ground.dart';
import 'design_system/skin/ground_scope.dart';
import 'design_system/skin/skin_choice.dart';

/// Root application widget. The app's ground is night until a screen says
/// otherwise (`ScreenFrame`); a skin switch takes effect in one frame, with
/// no theme animation blending two skins.
class App extends ConsumerWidget {
  const App({super.key});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    return MaterialApp.router(
      title: 'Midnight Village',
      debugShowCheckedModeBanner: false,
      theme: ref.watch(appThemeProvider),
      themeAnimationDuration: Duration.zero,
      routerConfig: ref.watch(appRouterProvider),
      builder: (context, child) =>
          GroundScope(ground: GroundKind.night, child: child!),
    );
  }
}
