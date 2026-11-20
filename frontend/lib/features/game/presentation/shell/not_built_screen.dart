import 'package:flutter/material.dart';

import '../../../../core/config/env.dart';
import '../../../../design_system/primitives/fit_line.dart';
import '../../../../design_system/primitives/screen_frame.dart';
import '../../../../design_system/skin/ground.dart';
import '../../../../design_system/skin/skin.dart';
import '../../domain/screen_table.dart';

/// A screen of the rebuild that is not built yet, named and nothing else:
/// the brief's number and name on the screen's own ground. For developers
/// only: the shell that shows it is reached only in a dev build (`GameEntry`)
/// and only by a night protocol 2 table, which only the `/debug` toolbar
/// creates. It goes when the last screen it stands for is rebuilt.
class NotBuiltScreen extends StatelessWidget {
  const NotBuiltScreen({super.key, required this.screen});

  final AppScreen screen;

  /// The screens drawn by day in the mocks.
  static const _day = {AppScreen.talk, AppScreen.vote, AppScreen.count};

  @override
  Widget build(BuildContext context) {
    assert(Env.isDev, 'A placeholder screen must never ship');
    return ScreenFrame(
      ground: _day.contains(screen) ? GroundKind.day : GroundKind.night,
      body: SizedBox(
        width: double.infinity,
        child: FitWords(
          '${screen.number} ${screen.briefName}',
          style: context.skin.typography.screenTitle,
        ),
      ),
    );
  }
}
