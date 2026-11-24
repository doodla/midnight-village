import 'package:flutter/widgets.dart';

/// The text size a pumped app draws at: its own [textScale] times the
/// phone's (the test view's `textScaleFactorTestValue`, 1 unless a test sets
/// it). The screen sweep (`screen_sweep.dart`) turns the phone's text size up
/// on a tree already pumped, as a player does in their settings, so every app
/// root a test pumps reads the phone's size through here, never a bare
/// `TextScaler.linear`.
TextScaler ambientTextScaler(BuildContext context, double textScale) =>
    TextScaler.linear(textScale * MediaQuery.textScalerOf(context).scale(1));
