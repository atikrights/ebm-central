import 'package:flutter/material.dart';

class AppColors {
  // Ultra-Premium Brand Colors (Stitch & Vercel Vibes)
  static const Color primary = Color(0xFF0B6E4F); // Deep Elegant Green
  static const Color primaryContainer = Color(0xFF83D7B1);
  static const Color primaryLight = Color(0xFFE8F5EE); // Light mode glass background
  
  static const Color secondary = Color(0xFF3CB371);
  static const Color accent = Color(0xFFFF8C42); // Warm Orange for contrast

  // Premium Dark Mode Surface Tokens
  static const Color darkBackground = Color(0xFF070B14); // Ultra-deep slate/black
  static const Color darkSurface = Color(0xFF111827); // Elevated
  static const Color darkSurfaceHigh = Color(0xFF1F2937); 

  // Ultra-Clean Light Mode Surface Tokens (Stripe / Linear vibes)
  static const Color lightBackground = Color(0xFFE2E8F0); // Smooth premium slate-gray (Not harsh white)
  static const Color lightSurface = Color(0xFFF8FAFC); // Very soft off-white for cards
  
  // Text Tokens
  static const Color darkText = Color(0xFFF8FAFC); // Slate-50
  static const Color darkTextMuted = Color(0xFF94A3B8); // Slate-400
  static const Color lightText = Color(0xFF0F172A); // Slate-900
  static const Color lightTextMuted = Color(0xFF64748B); // Slate-500
}

class AppTheme {
  static ThemeData darkTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.primaryContainer, // Lighter primary for dark mode
      onPrimary: AppColors.primary,
      secondary: AppColors.secondary,
      tertiary: AppColors.accent,
      surface: AppColors.darkBackground,
      surfaceContainerHigh: AppColors.darkSurfaceHigh,
      onSurface: AppColors.darkText,
      onSurfaceVariant: AppColors.darkTextMuted,
    ),
    scaffoldBackgroundColor: AppColors.darkBackground,
    cardTheme: CardThemeData(
      color: AppColors.darkSurface,
      elevation: 0,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(fontFamily: 'Manrope', fontSize: 56, fontWeight: FontWeight.bold, color: AppColors.darkText, letterSpacing: -1),
      headlineMedium: TextStyle(fontFamily: 'Manrope', fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.darkText, letterSpacing: -0.5),
      titleLarge: TextStyle(fontFamily: 'Manrope', fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.darkText),
      bodyLarge: TextStyle(fontFamily: 'Inter', fontSize: 16, color: AppColors.darkText),
      bodyMedium: TextStyle(fontFamily: 'Inter', fontSize: 14, color: AppColors.darkText),
      bodySmall: TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppColors.darkTextMuted),
    ),
  );

  static ThemeData lightTheme = ThemeData(
    useMaterial3: true,
    brightness: Brightness.light,
    colorScheme: const ColorScheme.light(
      primary: AppColors.primary,
      onPrimary: Colors.white,
      secondary: AppColors.secondary,
      tertiary: AppColors.accent,
      surface: AppColors.lightBackground,
      surfaceContainerHigh: AppColors.lightSurface,
      onSurface: AppColors.lightText,
      onSurfaceVariant: AppColors.lightTextMuted,
    ),
    scaffoldBackgroundColor: AppColors.lightBackground,
    cardTheme: CardThemeData(
      color: AppColors.lightSurface,
      elevation: 8,
      shadowColor: AppColors.primary.withOpacity(0.04), // Aesthetic subtle shadow
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
    ),
    textTheme: const TextTheme(
      displayLarge: TextStyle(fontFamily: 'Manrope', fontSize: 56, fontWeight: FontWeight.bold, color: AppColors.lightText, letterSpacing: -1),
      headlineMedium: TextStyle(fontFamily: 'Manrope', fontSize: 28, fontWeight: FontWeight.w700, color: AppColors.lightText, letterSpacing: -0.5),
      titleLarge: TextStyle(fontFamily: 'Manrope', fontSize: 20, fontWeight: FontWeight.w600, color: AppColors.lightText),
      bodyLarge: TextStyle(fontFamily: 'Inter', fontSize: 16, color: AppColors.lightText),
      bodyMedium: TextStyle(fontFamily: 'Inter', fontSize: 14, color: AppColors.lightText),
      bodySmall: TextStyle(fontFamily: 'Inter', fontSize: 12, color: AppColors.lightTextMuted),
    ),
  );
}
