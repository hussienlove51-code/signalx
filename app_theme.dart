import 'package:flutter/material.dart';

class AppColors {
  // الألوان الأساسية
  static const Color background    = Color(0xFF0A0E1A);
  static const Color surface       = Color(0xFF0D1220);
  static const Color surfaceLight  = Color(0xFF141C2E);
  static const Color border        = Color(0xFF1A2540);

  // الأزرق النيون
  static const Color neon          = Color(0xFF00D4FF);
  static const Color neonDark      = Color(0xFF0066CC);
  static const Color neonGlow      = Color(0x2200D4FF);

  // الألوان الثانوية
  static const Color green         = Color(0xFF00E676);
  static const Color greenGlow     = Color(0x1400E676);
  static const Color orange        = Color(0xFFFFA000);
  static const Color orangeGlow    = Color(0x1AFFA000);
  static const Color red           = Color(0xFFFF4D6D);
  static const Color redGlow       = Color(0x1AFF4D6D);
  static const Color purple        = Color(0xFFA855F7);
  static const Color purpleGlow    = Color(0x1AA855F7);

  // النصوص
  static const Color textPrimary   = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xFF8AB4D4);
  static const Color textMuted     = Color(0xFF4A6FA5);
  static const Color textDim       = Color(0xFF2A3A55);
}

class AppTheme {
  static ThemeData get darkTheme => ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AppColors.background,
    fontFamily: 'Cairo',

    colorScheme: const ColorScheme.dark(
      background:   AppColors.background,
      surface:      AppColors.surface,
      primary:      AppColors.neon,
      secondary:    AppColors.purple,
      error:        AppColors.red,
    ),

    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.surface,
      elevation: 0,
      centerTitle: true,
      titleTextStyle: TextStyle(
        fontFamily: 'Cairo',
        fontSize: 17,
        fontWeight: FontWeight.w700,
        color: AppColors.textPrimary,
      ),
      iconTheme: IconThemeData(color: AppColors.textSecondary),
    ),

    cardTheme: CardThemeData(
      color: AppColors.surface,
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AppColors.border, width: 0.5),
      ),
    ),

    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppColors.neon,
        foregroundColor: AppColors.background,
        elevation: 0,
        padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 24),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
        textStyle: const TextStyle(
          fontFamily: 'Cairo',
          fontWeight: FontWeight.w700,
          fontSize: 14,
        ),
      ),
    ),

    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.surface,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border, width: 0.5),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.border, width: 0.5),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AppColors.neon, width: 1.5),
      ),
      hintStyle: const TextStyle(color: AppColors.textDim, fontFamily: 'Cairo'),
      labelStyle: const TextStyle(color: AppColors.textSecondary, fontFamily: 'Cairo'),
    ),

    textTheme: const TextTheme(
      displayLarge:  TextStyle(color: AppColors.textPrimary,   fontFamily: 'Cairo', fontWeight: FontWeight.w700),
      headlineMedium:TextStyle(color: AppColors.textPrimary,   fontFamily: 'Cairo', fontWeight: FontWeight.w700),
      titleLarge:    TextStyle(color: AppColors.textPrimary,   fontFamily: 'Cairo', fontWeight: FontWeight.w700),
      titleMedium:   TextStyle(color: AppColors.textPrimary,   fontFamily: 'Cairo', fontWeight: FontWeight.w600),
      bodyLarge:     TextStyle(color: AppColors.textSecondary, fontFamily: 'Cairo'),
      bodyMedium:    TextStyle(color: AppColors.textSecondary, fontFamily: 'Cairo'),
      bodySmall:     TextStyle(color: AppColors.textMuted,     fontFamily: 'Cairo'),
    ),

    bottomNavigationBarTheme: const BottomNavigationBarThemeData(
      backgroundColor: AppColors.surface,
      selectedItemColor: AppColors.neon,
      unselectedItemColor: AppColors.textMuted,
      type: BottomNavigationBarType.fixed,
      elevation: 0,
    ),

    dividerTheme: const DividerThemeData(
      color: AppColors.border,
      thickness: 0.5,
    ),
  );
}
