import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Colours from the design. Calories = green, protein = blue, so the two
/// differ in lightness as well as hue for colour-blind users.
class AppColors {
  static const ground = Color(0xFFF4F7F3);
  static const card = Color(0xFFFFFFFF);
  static const ink = Color(0xFF1C2B24);
  static const muted = Color(0xFF5B6B63);
  static const line = Color(0xFFE2E8E4);
  static const green = Color(0xFF1F7A4D);
  static const greenSoft = Color(0xFFE3F1E8);
  static const greenDark = Color(0xFF1F5C3C);
  static const blue = Color(0xFF1D5FD1);
  static const blueSoft = Color(0xFFE4ECFB);
  static const blueDark = Color(0xFF1D4FAF);
  static const chip = Color(0xFFEEF2EF);
  static const chipBorder = Color(0xFFD5DED8);
}

ThemeData buildTheme() {
  final base = ThemeData(
    useMaterial3: true,
    colorScheme: ColorScheme.fromSeed(
      seedColor: AppColors.green,
      primary: AppColors.green,
      surface: AppColors.ground,
    ),
    scaffoldBackgroundColor: AppColors.ground,
  );
  final text = GoogleFonts.nunitoTextTheme(base.textTheme).apply(
    bodyColor: AppColors.ink,
    displayColor: AppColors.ink,
  );
  return base.copyWith(
    textTheme: text,
    appBarTheme: const AppBarTheme(
      backgroundColor: AppColors.ground,
      foregroundColor: AppColors.ink,
      elevation: 0,
      scrolledUnderElevation: 0,
      centerTitle: false,
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: AppColors.green,
        foregroundColor: Colors.white,
        minimumSize: const Size.fromHeight(58),
        shape: const StadiumBorder(),
        textStyle: GoogleFonts.nunito(fontSize: 19, fontWeight: FontWeight.w800),
      ),
    ),
    outlinedButtonTheme: OutlinedButtonThemeData(
      style: OutlinedButton.styleFrom(
        foregroundColor: AppColors.ink,
        minimumSize: const Size(48, 52),
        side: const BorderSide(color: AppColors.chipBorder, width: 2),
        shape: const StadiumBorder(),
        textStyle: GoogleFonts.nunito(fontSize: 16, fontWeight: FontWeight.w700),
      ),
    ),
    inputDecorationTheme: InputDecorationTheme(
      filled: true,
      fillColor: AppColors.card,
      contentPadding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: AppColors.chipBorder, width: 2),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: AppColors.chipBorder, width: 2),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(18),
        borderSide: const BorderSide(color: AppColors.green, width: 2),
      ),
    ),
  );
}

const w800 = FontWeight.w800;
const w700 = FontWeight.w700;
