import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import 'core/router/app_router.dart';
import 'core/router/back_policy.dart';
import 'design_system/copy/copy.dart';
import 'design_system/load_once_bundle.dart';
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
    final theme = ref.watch(appThemeProvider);
    // The pictures are read through the bundle the start precaches with
    // (`SkinLoader`), which on the web reads each file once.
    return DefaultAssetBundle(bundle: appAssets, child: _app(ref, theme));
  }

  Widget _app(WidgetRef ref, ThemeData theme) {
    return MaterialApp.router(
      // The task switcher's name (the Join screen's own title) and colour
      // (the night ground, as behind the icon and the launch screen).
      title: JoinCopy.title,
      color: theme.colorScheme.surface,
      debugShowCheckedModeBanner: false,
      theme: theme,
      themeAnimationDuration: Duration.zero,
      // The browser's history holds one entry for the app, so its Back is
      // the phone's Back (`BackPolicy`).
      routerConfig: oneHistoryEntry(ref.watch(appRouterProvider)),
      builder: (context, child) =>
          GroundScope(ground: GroundKind.night, child: child!),
    );
  }
}
