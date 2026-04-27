import 'package:flutter/material.dart';

class AdminTheme {
  static const primary = Color(0xFF00E676); // Same as EBM Central primary
  static const secondary = Color(0xFF00BCD4);
  static const darkBg = Color(0xFF0F1117);
  static const cardBg = Color(0xFF161A23);
  
  static ThemeData get theme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: primary,
      scaffoldBackgroundColor: darkBg,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: secondary,
        surface: cardBg,
      ),
    );
  }
}
