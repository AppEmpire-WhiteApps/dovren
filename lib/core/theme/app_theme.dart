import 'package:flutter/material.dart';

class DovrenTheme {
  static const ink = Color(0xFF14211B);
  static const cream = Color(0xFFF4F1E8);
  static const sage = Color(0xFFA8D5BA);
  static const orange = Color(0xFFE98B55);
  static const muted = Color(0xFF718078);

  static ThemeData light() => ThemeData(
        brightness: Brightness.light,
        scaffoldBackgroundColor: cream,
        colorScheme:
            ColorScheme.fromSeed(seedColor: sage, brightness: Brightness.light),
        appBarTheme:
            const AppBarTheme(backgroundColor: cream, foregroundColor: ink),
        cardTheme: CardThemeData(
            color: Colors.white, elevation: 0, margin: EdgeInsets.zero),
        inputDecorationTheme: InputDecorationTheme(
            filled: true,
            fillColor: Colors.white,
            border: OutlineInputBorder(
                borderRadius: BorderRadius.all(Radius.circular(16)),
                borderSide: BorderSide.none)),
        useMaterial3: true,
      );
}
