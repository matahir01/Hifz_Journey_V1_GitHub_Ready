import 'package:flutter/material.dart';

class AppTheme {
  static const emerald = Color(0xFF0E5A46);
  static const gold = Color(0xFFB58A3A);
  static const ivory = Color(0xFFFBF7EC);
  static const paper = Color(0xFFFFFDF6);
  static const charcoal = Color(0xFF111915);

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: emerald,
      brightness: Brightness.light,
      surface: paper,
    ).copyWith(
      primary: emerald,
      secondary: gold,
      surface: paper,
      surfaceContainerLowest: paper,
      surfaceContainerLow: ivory,
      outlineVariant: const Color(0xFFE3DCCB),
    );
    return _base(scheme, false).copyWith(scaffoldBackgroundColor: ivory);
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: const Color(0xFF69C4A4),
      brightness: Brightness.dark,
      surface: const Color(0xFF18201C),
    ).copyWith(
      primary: const Color(0xFF72C8A9),
      secondary: const Color(0xFFD2AD61),
      surface: const Color(0xFF18201C),
      surfaceContainerLowest: charcoal,
      surfaceContainerLow: const Color(0xFF151D19),
      outlineVariant: const Color(0xFF34463D),
    );
    return _base(scheme, true).copyWith(scaffoldBackgroundColor: charcoal);
  }

  static ThemeData _base(ColorScheme scheme, bool dark) => ThemeData(
    useMaterial3: true,
    colorScheme: scheme,
    appBarTheme: AppBarTheme(
      elevation: 0,
      scrolledUnderElevation: 0,
      backgroundColor: Colors.transparent,
      foregroundColor: scheme.onSurface,
      titleTextStyle: TextStyle(color: scheme.onSurface, fontSize: 20, fontWeight: FontWeight.w800),
    ),
    cardTheme: CardThemeData(
      elevation: dark ? 0 : 1,
      shadowColor: Colors.black.withValues(alpha: .08),
      color: scheme.surface,
      surfaceTintColor: Colors.transparent,
      margin: EdgeInsets.zero,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(20),
        side: BorderSide(color: scheme.outlineVariant.withValues(alpha: .72)),
      ),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        minimumSize: const Size(48, 52),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontWeight: FontWeight.w800),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        minimumSize: const Size(48, 50),
        side: BorderSide(color: scheme.outlineVariant),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        textStyle: const TextStyle(fontWeight: FontWeight.w700),
      ),
    ),
    navigationBarTheme: NavigationBarThemeData(
      height: 70,
      elevation: 0,
      backgroundColor: scheme.surface,
      indicatorColor: scheme.primaryContainer,
      labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: scheme.surfaceContainerLow,
      border: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide.none),
    ),
  );
}
