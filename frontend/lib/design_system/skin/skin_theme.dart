import 'package:flutter/material.dart';

import '../layout/space.dart';
import 'ground.dart';
import 'skin.dart';

final _themes = Expando<Map<GroundKind, ThemeData>>('skin themes');

/// The Material theme of [skin] on [ground]: Material's text theme mapped to
/// the skin's type roles, its colour scheme to the ground's colour roles, and
/// component defaults (buttons, inputs, dialogs, sheets, snack bars) shaped
/// like the mocks, so screens not yet built from the skin's components still
/// get the right fonts and button sizes. The skin itself rides along as a
/// theme extension (`context.skin`).
///
/// Material buttons cast no shadow here: a hard offset shadow is drawn by the
/// skin's own buttons (`PrimaryButton`), and a Material elevation shadow would
/// be a soft blur.
ThemeData skinTheme(Skin skin, {GroundKind ground = GroundKind.night}) =>
    (_themes[skin] ??= {})[ground] ??= _build(skin, ground);

ThemeData _build(Skin skin, GroundKind kind) {
  final g = skin.ground(kind);
  final paper = skin.paper;
  final type = skin.typography;
  final shape = skin.shape;
  final corners = BorderRadius.circular(shape.radius);
  final cornered = RoundedRectangleBorder(borderRadius: corners);

  final scheme = ColorScheme(
    brightness: ThemeData.estimateBrightnessForColor(g.ground),
    primary: g.accent,
    onPrimary: g.onAccent,
    secondary: g.paper,
    onSecondary: paper.text,
    tertiary: g.selection,
    onTertiary: g.ground,
    error: g.danger,
    onError: g.onDanger,
    surface: g.ground,
    onSurface: g.text,
    onSurfaceVariant: g.quietText,
    surfaceContainerLowest: g.panel,
    surfaceContainerLow: g.panel,
    surfaceContainer: g.panel,
    surfaceContainerHigh: g.panel,
    surfaceContainerHighest: g.panel,
    outline: g.outline,
    outlineVariant: g.hairline,
    shadow: g.shadow,
    scrim: skin.scrim,
    inverseSurface: g.paper,
    onInverseSurface: paper.text,
    inversePrimary: g.selection,
    surfaceTint: Colors.transparent,
  );

  final textTheme = TextTheme(
    displayLarge: type.display,
    displayMedium: type.headline,
    displaySmall: type.title,
    headlineLarge: type.headline,
    headlineMedium: type.title,
    headlineSmall: type.heading,
    titleLarge: type.name,
    titleMedium: type.action,
    titleSmall: type.body,
    bodyLarge: type.bodyLarge,
    bodyMedium: type.body,
    bodySmall: type.caption,
    // Material's button label: the secondary-button style. The primary
    // (filled) button sets its own, larger label below.
    labelLarge: type.action,
    labelMedium: type.tag,
    labelSmall: type.caption,
  ).apply(bodyColor: g.text, displayColor: g.text);

  final quiet = TextStyle(color: g.quietText);
  OutlineInputBorder inputBorder(Color color) => OutlineInputBorder(
    borderRadius: corners,
    borderSide: BorderSide(color: color, width: shape.stroke),
  );

  final filled = ButtonStyle(
    backgroundColor: WidgetStateProperty.resolveWith(
      (states) => states.contains(WidgetState.disabled) ? g.disabled : g.accent,
    ),
    foregroundColor: WidgetStateProperty.resolveWith(
      (states) =>
          states.contains(WidgetState.disabled) ? g.onDisabled : g.onAccent,
    ),
    textStyle: WidgetStatePropertyAll(type.buttonLabel),
    minimumSize: const WidgetStatePropertyAll(Size(64, 56)),
    padding: WidgetStatePropertyAll(EdgeInsets.symmetric(horizontal: Space.xl)),
    shape: WidgetStatePropertyAll(cornered),
    elevation: const WidgetStatePropertyAll(0),
  );

  return ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    textTheme: textTheme,
    fontFamily: type.body.fontFamily,
    scaffoldBackgroundColor: g.ground,
    canvasColor: g.ground,
    splashFactory: NoSplash.splashFactory,
    iconTheme: IconThemeData(color: g.text),
    dividerTheme: DividerThemeData(color: g.hairline, thickness: shape.stroke),
    appBarTheme: AppBarTheme(
      backgroundColor: Colors.transparent,
      foregroundColor: g.text,
      elevation: 0,
      scrolledUnderElevation: 0,
      titleTextStyle: type.heading.copyWith(color: g.text),
    ),
    filledButtonTheme: FilledButtonThemeData(style: filled),
    elevatedButtonTheme: ElevatedButtonThemeData(style: filled),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: g.text,
        disabledForegroundColor: g.onDisabled,
        side: BorderSide(color: g.outline, width: shape.stroke),
        minimumSize: const Size(64, 48),
        shape: cornered,
        textStyle: type.action,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(
        foregroundColor: g.selection,
        textStyle: type.action,
        shape: cornered,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      contentPadding: EdgeInsets.symmetric(
        horizontal: Space.lg,
        vertical: Space.lg,
      ),
      border: inputBorder(g.outline),
      enabledBorder: inputBorder(g.outline),
      focusedBorder: inputBorder(g.selection),
      errorBorder: inputBorder(g.dangerLine),
      focusedErrorBorder: inputBorder(g.dangerLine),
      disabledBorder: inputBorder(g.hairline),
      labelStyle: type.body.merge(quiet),
      floatingLabelStyle: type.caption.copyWith(color: g.selection),
      hintStyle: type.bodyLarge.merge(quiet),
      helperStyle: type.caption.merge(quiet),
      errorStyle: type.caption.copyWith(color: g.dangerText),
    ),
    textSelectionTheme: TextSelectionThemeData(
      cursorColor: g.selection,
      selectionColor: g.selection.withValues(alpha: 0.4),
      selectionHandleColor: g.selection,
    ),
    // A dialog is a panel of the same ground, so the buttons in it keep the
    // contrast they have on the screen behind.
    dialogTheme: DialogThemeData(
      backgroundColor: g.panel,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      barrierColor: skin.scrim,
      shape: RoundedRectangleBorder(
        borderRadius: corners,
        side: BorderSide(color: g.hairline, width: shape.stroke),
      ),
      titleTextStyle: type.title.copyWith(color: g.text),
      contentTextStyle: type.body.copyWith(color: g.text),
    ),
    bottomSheetTheme: BottomSheetThemeData(
      backgroundColor: g.paper,
      modalBackgroundColor: g.paper,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      modalElevation: 0,
      modalBarrierColor: skin.scrim,
      showDragHandle: false,
      clipBehavior: Clip.antiAlias,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(shape.sheetRadius),
        ),
      ),
    ),
    snackBarTheme: SnackBarThemeData(
      backgroundColor: g.paper,
      contentTextStyle: type.body.copyWith(color: paper.text),
      actionTextColor: paper.selection,
      elevation: 0,
      behavior: SnackBarBehavior.floating,
      shape: cornered,
    ),
    cardTheme: CardThemeData(
      color: g.paper,
      surfaceTintColor: Colors.transparent,
      elevation: 0,
      shape: cornered,
    ),
    progressIndicatorTheme: ProgressIndicatorThemeData(
      color: g.selection,
      linearTrackColor: g.hairline,
    ),
    tooltipTheme: TooltipThemeData(
      decoration: BoxDecoration(color: g.paper, borderRadius: corners),
      textStyle: type.caption.copyWith(color: paper.text),
    ),
    extensions: [skin],
  );
}
