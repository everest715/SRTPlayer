import 'package:flutter/material.dart';

class AppTheme {
  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    colorSchemeSeed: const Color(0xFF4A90D9),
    brightness: Brightness.light,
  );

  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    colorSchemeSeed: const Color(0xFF4A90D9),
    brightness: Brightness.dark,
  );

  static ThemeData oledTheme = ThemeData(
    useMaterial3: true,
    colorSchemeSeed: const Color(0xFF4A90D9),
    brightness: Brightness.dark,
    scaffoldBackgroundColor: Colors.black,
    cardColor: const Color(0xFF111111),
  );
}
