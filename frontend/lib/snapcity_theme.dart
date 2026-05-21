import 'package:flutter/material.dart';

class SnapColors {
  static const purple = Color(0xFF48117F);
  static const purple2 = Color(0xFF6A35C8);
  static const yellow = Color(0xFFFFC83D);
  static const bg = Color(0xFFF6F4F8);
  static const ink = Color(0xFF17151C);
  static const muted = Color(0xFF77727F);
  static const danger = Color(0xFFE84A2A);
  static const success = Color(0xFF18A65B);
  static const line = Color(0x14111111);
}

ThemeData snapTheme() {
  return ThemeData(
    useMaterial3: true,
    scaffoldBackgroundColor: SnapColors.bg,
    fontFamily: 'Inter',
    colorScheme: ColorScheme.fromSeed(
      seedColor: SnapColors.purple,
      primary: SnapColors.purple,
      secondary: SnapColors.yellow,
      background: SnapColors.bg,
    ),
    textTheme: const TextTheme(
      titleLarge: TextStyle(fontSize: 22, fontWeight: FontWeight.w800, height: 1.05),
      titleMedium: TextStyle(fontSize: 15, fontWeight: FontWeight.w700),
      bodyMedium: TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
      labelMedium: TextStyle(fontSize: 11, fontWeight: FontWeight.w600),
    ),
  );
}
