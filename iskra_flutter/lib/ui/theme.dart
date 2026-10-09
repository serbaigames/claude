// Цвета и шрифты веб-версии (переменные :root в index.html)
import 'package:flutter/material.dart';

class C {
  static const bg = Color(0xFF141026);
  static const panel = Color(0xFF1C1733);
  static const ink = Color(0xFFECE6FA);
  static const muted = Color(0xFFA79FC2);
  static const line = Color(0xFF342B55);
  static const gold = Color(0xFFF2B441);
  static const goldBg = Color(0xFF3B2E15);
  static const violet = Color(0xFFA88BE0);
  static const ok = Color(0xFF5CC28D);
  static const bad = Color(0xFFEF6B90);
  static const warn = Color(0xFFFFB36B);
  static const btn = Color(0xFF2A2347);
  static const btnHover = Color(0xFF352C5A);
  static const matter = Color(0xFFF2B441);
  static const energy = Color(0xFF5FB2E6);
  static const force = Color(0xFFEF6B90);

  static Color kind(String k) => switch (k) {
    'good' || 'ok' || 'grow' => ok,
    'bad' || 'dark' => bad,
    'warn' || 'stall' => warn,
    _ => muted,
  };
}

const displayFont = 'Philosopher';
const bodyFont = 'PT Sans';

ThemeData iskraTheme() {
  final base = ThemeData(
    brightness: Brightness.dark,
    useMaterial3: true,
    fontFamily: bodyFont,
    scaffoldBackgroundColor: C.bg,
    colorScheme: const ColorScheme.dark(
      primary: C.gold,
      onPrimary: Color(0xFF23163F),
      secondary: C.violet,
      surface: C.panel,
      onSurface: C.ink,
      error: C.bad,
    ),
  );
  return base.copyWith(
    textTheme: base.textTheme.apply(bodyColor: C.ink, displayColor: C.ink),
    dividerColor: C.line,
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: C.btn,
        foregroundColor: C.ink,
        disabledBackgroundColor: C.btn.withValues(alpha: 0.5),
        disabledForegroundColor: C.muted.withValues(alpha: 0.6),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        minimumSize: const Size(40, 36),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(10),
          side: const BorderSide(color: C.line),
        ),
      ),
    ),
    inputDecorationTheme: const InputDecorationTheme(border: OutlineInputBorder(), isDense: true),
  );
}

TextStyle h2([Color color = C.ink]) =>
    TextStyle(fontFamily: displayFont, fontSize: 18, fontWeight: FontWeight.w700, color: color);
