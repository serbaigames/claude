import 'package:flutter/material.dart';

class AppColors {
  static const bg = Color(0xFF0B0D14);
  static const bg2 = Color(0xFF121624);
  static const card = Color(0xFF161B2C);
  static const line = Color(0xFF262D45);
  static const text = Color(0xFFE8EAF2);
  static const muted = Color(0xFF9AA1B9);
  static const accent = Color(0xFFFF9A3C);
  static const accent2 = Color(0xFF7C6CFF);
}

const double maxContentWidth = 1100;

ThemeData buildTheme() {
  final base = ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    fontFamily: 'Inter',
    scaffoldBackgroundColor: AppColors.bg,
    colorScheme: const ColorScheme.dark(
      primary: AppColors.accent,
      secondary: AppColors.accent2,
      surface: AppColors.card,
      onSurface: AppColors.text,
    ),
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(
      bodyColor: AppColors.text,
      displayColor: AppColors.text,
    ),
  );
}
