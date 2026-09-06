import 'package:flutter/material.dart';

class AppTheme {
  static const _seed = Color(0xFF176B57);

  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: _seed,
      brightness: Brightness.light,
      surface: const Color(0xFFFCFBF7),
    );
    return _base(scheme).copyWith(
      scaffoldBackgroundColor: const Color(0xFFF5F4EE),
    );
  }

  static ThemeData dark() {
    return _base(
      ColorScheme.fromSeed(
        seedColor: const Color(0xFF63C6A5),
        brightness: Brightness.dark,
      ),
    );
  }

  static ThemeData _base(ColorScheme scheme) {
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      cardTheme: CardThemeData(
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(22),
        ),
      ),
      navigationBarTheme: const NavigationBarThemeData(
        height: 68,
        labelBehavior: NavigationDestinationLabelBehavior.alwaysShow,
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(18),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}
