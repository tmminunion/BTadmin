import 'package:flutter/material.dart';

class AdminColors {
  static const Color bg = Color(0xFF060B16);
  static const Color surface = Color(0xFF0D1526);
  static const Color card = Color(0xFF131E36);
  static const Color cardElevated = Color(0xFF192746);
  static const Color border = Color(0xFF1F3054);
  static const Color gold = Color(0xFFF59E0B);
  static const Color goldSoft = Color(0xFFFBBF24);
  static const Color emerald = Color(0xFF10B981);
  static const Color sky = Color(0xFF38BDF8);
  static const Color indigo = Color(0xFF6366F1);
  static const Color danger = Color(0xFFEF4444);
  static const Color textPrimary = Color(0xFFF8FAFC);
  static const Color textSecondary = Color(0xFF94A3B8);

  static const LinearGradient heroGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF162447), Color(0xFF0F172A), Color(0xFF1B1F3B)],
  );
}

ThemeData buildAdminTheme() {
  return ThemeData(
    useMaterial3: true,
    brightness: Brightness.dark,
    scaffoldBackgroundColor: AdminColors.bg,
    colorScheme: const ColorScheme.dark(
      primary: AdminColors.gold,
      secondary: AdminColors.emerald,
      surface: AdminColors.surface,
      error: AdminColors.danger,
    ),
    appBarTheme: const AppBarTheme(
      backgroundColor: AdminColors.surface,
      foregroundColor: AdminColors.textPrimary,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
      surfaceTintColor: Colors.transparent,
    ),
    cardTheme: CardThemeData(
      color: AdminColors.card,
      elevation: 0,
      surfaceTintColor: Colors.transparent,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(16),
        side: const BorderSide(color: AdminColors.border, width: 1),
      ),
    ),
    elevatedButtonTheme: ElevatedButtonThemeData(
      style: ElevatedButton.styleFrom(
        backgroundColor: AdminColors.gold,
        foregroundColor: AdminColors.bg,
        elevation: 0,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 13),
        textStyle: const TextStyle(fontWeight: FontWeight.w800, fontSize: 14),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AdminColors.textPrimary,
        side: const BorderSide(color: AdminColors.border),
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
        textStyle: const TextStyle(fontWeight: FontWeight.w700, fontSize: 13),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    ),
    chipTheme: ChipThemeData(
      backgroundColor: AdminColors.surface,
      selectedColor: AdminColors.gold.withValues(alpha: 0.2),
      side: const BorderSide(color: AdminColors.border),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
      labelStyle: const TextStyle(fontSize: 12.5, fontWeight: FontWeight.w600),
    ),
    snackBarTheme: SnackBarThemeData(
      behavior: SnackBarBehavior.floating,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
    ),
    dividerTheme: const DividerThemeData(
      color: AdminColors.border,
      thickness: 1,
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AdminColors.surface,
      hintStyle: const TextStyle(color: AdminColors.textSecondary, fontSize: 13.5),
      labelStyle: const TextStyle(color: AdminColors.textSecondary, fontSize: 13.5),
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AdminColors.border),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AdminColors.border),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: AdminColors.gold, width: 1.5),
      ),
    ),
  );
}
