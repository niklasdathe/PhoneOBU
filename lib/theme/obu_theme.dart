import 'package:flutter/material.dart';

abstract final class ObuColors {
  static const ink = Color(0xFF171A1C);
  static const paper = Color(0xFFF7F7F4);
  static const surface = Color(0xFFF0F0EC);
  static const line = Color(0xFFD7D8D3);
  static const muted = Color(0xFF656B6F);
  static const green = Color(0xFF00A66A);
  static const amber = Color(0xFFF0A000);
  static const red = Color(0xFFD9363E);
  static const blue = Color(0xFF2D6CDF);
  static const cyan = Color(0xFF0B8FA3);
}

abstract final class ObuTheme {
  static ThemeData get light {
    const scheme = ColorScheme.light(
      primary: ObuColors.ink,
      onPrimary: Colors.white,
      primaryContainer: ObuColors.surface,
      onPrimaryContainer: ObuColors.ink,
      secondary: ObuColors.muted,
      onSecondary: Colors.white,
      surface: ObuColors.paper,
      onSurface: ObuColors.ink,
      error: ObuColors.red,
      onError: Colors.white,
      outline: ObuColors.line,
      outlineVariant: Color(0xFFE7E7E2),
    );

    final base = ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: ObuColors.paper,
      visualDensity: VisualDensity.standard,
    );

    return base.copyWith(
      textTheme: base.textTheme.copyWith(
        displayLarge: base.textTheme.displayLarge?.copyWith(
          fontWeight: FontWeight.w300,
          letterSpacing: -2,
        ),
        headlineMedium: base.textTheme.headlineMedium?.copyWith(
          fontWeight: FontWeight.w600,
          letterSpacing: -0.5,
        ),
        titleLarge: base.textTheme.titleLarge?.copyWith(
          fontWeight: FontWeight.w600,
        ),
        labelLarge: base.textTheme.labelLarge?.copyWith(
          fontWeight: FontWeight.w700,
          letterSpacing: 0.2,
        ),
      ),
      cardTheme: const CardThemeData(
        color: Color(0xF7FFFFFF),
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.all(Radius.circular(20)),
          side: BorderSide(color: ObuColors.line),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          backgroundColor: const Color(0xF2FFFFFF),
          foregroundColor: ObuColors.ink,
          side: const BorderSide(color: ObuColors.line),
        ),
      ),
      navigationDrawerTheme: const NavigationDrawerThemeData(
        backgroundColor: ObuColors.paper,
        indicatorColor: ObuColors.ink,
        indicatorShape: StadiumBorder(),
      ),
      dividerTheme: const DividerThemeData(
        color: ObuColors.line,
        thickness: 1,
        space: 1,
      ),
      snackBarTheme: const SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        backgroundColor: ObuColors.ink,
        contentTextStyle: TextStyle(color: Colors.white),
      ),
    );
  }
}
