import 'package:flutter/material.dart';

class AppColors {
  static const Color primary = Color(0xFF19336A);
  static const Color primaryAlt = Color(0xFF2453A6);
  static const Color secondary = Color(0xFF0F766E);
  static const Color accent = Color(0xFFD62828);
  static const Color success = Color(0xFF15803D);
  static const Color warning = Color(0xFFD97706);
  static const Color background = Color(0xFFF4F7FB);
  static const Color backgroundAlt = Color(0xFFEAF1FB);
  static const Color surface = Colors.white;
  static const Color textPrimary = Color(0xFF0F172A);
  static const Color textMuted = Color(0xFF64748B);
  static const Color border = Color(0xFFD7DEEA);
  static const Color primarySoft = Color(0x1419336A);
  static const Color shadowSoft = Color(0x1F0F172A);
  static const Color shadowPrimary = Color(0x2619336A);
  static const Color skeletonBase = Color(0xFFD5DEEC);
  static const Color skeletonHighlight = Color(0xFFF0F4FA);
}

class AppTheme {
  static ThemeData get lightTheme {
    final base = ThemeData.light(useMaterial3: true);

    return base.copyWith(
      scaffoldBackgroundColor: AppColors.background,
      colorScheme: base.colorScheme.copyWith(
        primary: AppColors.primary,
        secondary: AppColors.secondary,
        surface: AppColors.surface,
        error: const Color(0xFFDC2626),
      ),
      textTheme: base.textTheme.apply(
        fontFamily: 'Roboto',
        bodyColor: AppColors.textPrimary,
        displayColor: AppColors.textPrimary,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: AppColors.primary,
        foregroundColor: Colors.white,
        centerTitle: false,
        elevation: 0,
      ),
      cardTheme: CardThemeData(
        color: AppColors.surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: AppColors.border),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: Colors.white,
        contentPadding: const EdgeInsets.symmetric(
          horizontal: 16,
          vertical: 14,
        ),
        hintStyle: const TextStyle(color: AppColors.textMuted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.border),
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: AppColors.primary, width: 1.3),
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      ),
      dividerColor: AppColors.border,
      iconTheme: const IconThemeData(color: AppColors.primary),
    );
  }
}
