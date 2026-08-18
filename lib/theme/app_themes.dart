import 'package:flutter/material.dart';

import 'design_tokens.dart';

ThemeData _buildTheme({
  required Brightness brightness,
  required Color scaffold,
  required Color surface,
  required Color primary,
  required Color onPrimary,
  required Color onSurface,
  required Color outline,
}) {
  final ColorScheme scheme = ColorScheme.fromSeed(
    seedColor: primary,
    brightness: brightness,
  ).copyWith(
    primary: primary,
    onPrimary: onPrimary,
    surface: surface,
    onSurface: onSurface,
    outline: outline,
  );

  return ThemeData(
    brightness: brightness,
    colorScheme: scheme,
    scaffoldBackgroundColor: scaffold,
    cardColor: surface,
    dividerColor: outline,
    appBarTheme: AppBarTheme(
      backgroundColor: primary,
      foregroundColor: onPrimary,
      elevation: 0,
      titleTextStyle: kDisplayTextStyle(
        size: 20,
        weight: FontWeight.w800,
        color: onPrimary,
      ),
    ),
    textTheme: TextTheme(
      headlineLarge: kDisplayTextStyle(
        size: 32,
        weight: FontWeight.w900,
        color: onSurface,
      ),
      headlineMedium: kDisplayTextStyle(
        size: 28,
        weight: FontWeight.w800,
        color: onSurface,
      ),
      titleLarge: kDisplayTextStyle(
        size: 22,
        weight: FontWeight.w800,
        color: onSurface,
      ),
      titleMedium: kDisplayTextStyle(
        size: 18,
        weight: FontWeight.w700,
        color: onSurface,
      ),
      bodyLarge: kBodyTextStyle(
        size: 16,
        weight: FontWeight.w500,
        color: onSurface,
      ),
      bodyMedium: kBodyTextStyle(
        size: 14,
        weight: FontWeight.w400,
        color: onSurface,
      ),
      bodySmall: kBodyTextStyle(
        size: 12,
        weight: FontWeight.w300,
        color: onSurface,
      ),
      labelLarge: kBodyTextStyle(
        size: 14,
        weight: FontWeight.w600,
        color: onPrimary,
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: surface,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kRadiusCard),
        borderSide: const BorderSide(color: kLine, width: kBorderWidth),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kRadiusCard),
        borderSide: BorderSide(color: outline, width: kBorderWidth),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(kRadiusCard),
        borderSide: BorderSide(color: primary, width: kBorderWidth),
      ),
      labelStyle: kBodyTextStyle(
        size: 14,
        weight: FontWeight.w500,
        color: onSurface,
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: primary,
        foregroundColor: onPrimary,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(kRadiusPill),
        ),
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        textStyle: kBodyTextStyle(
          size: 14,
          weight: FontWeight.w600,
          color: onPrimary,
        ),
      ),
    ),
    cardTheme: CardThemeData(
      color: surface,
      elevation: 0,
      shadowColor: Colors.transparent,
      margin: const EdgeInsets.symmetric(vertical: 4),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(kRadiusCard),
        side: BorderSide(color: outline, width: kBorderWidth),
      ),
    ),
    useMaterial3: true,
  );
}

ThemeData get customerTheme => _buildTheme(
      brightness: Brightness.light,
      scaffold: kSand,
      surface: kWhite,
      primary: kTeal,
      onPrimary: kWhite,
      onSurface: kInk,
      outline: kLine,
    );

ThemeData get merchantBrandTheme => _buildTheme(
      brightness: Brightness.dark,
      scaffold: kIndigo,
      surface: kIndigoLight,
      primary: kIndigo,
      onPrimary: kWhite,
      onSurface: kWhite,
      outline: kLineDark,
    );

ThemeData get adminTheme => _buildTheme(
      brightness: Brightness.dark,
      scaffold: kInk,
      surface: kIndigo,
      primary: kInk,
      onPrimary: kWhite,
      onSurface: kWhite,
      outline: kLineDark,
    );

ThemeData get cashierTheme => _buildTheme(
      brightness: Brightness.dark,
      scaffold: kViolet,
      surface: kViolet,
      primary: kViolet,
      onPrimary: kWhite,
      onSurface: kWhite,
      outline: kLineDark,
    );

ThemeData themeForRole(String role) {
  switch (role) {
    case 'merchant':
    case 'brand':
      return merchantBrandTheme;
    case 'admin':
      return adminTheme;
    case 'cashier':
      return cashierTheme;
    case 'customer':
    default:
      return customerTheme;
  }
}
