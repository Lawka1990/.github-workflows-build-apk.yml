import 'package:flutter/material.dart';

abstract final class MedievalColors {
  static const Color black = Color(0xFF0C0B08);
  static const Color charcoal = Color(0xFF18150F);
  static const Color ink = Color(0xFF2A1B10);
  static const Color inkSoft = Color(0xFF584126);
  static const Color parchment = Color(0xFFE5D0A0);
  static const Color parchmentLight = Color(0xFFF1DFB6);
  static const Color parchmentDark = Color(0xFFC4A66A);
  static const Color gold = Color(0xFFC6A45B);
  static const Color goldBright = Color(0xFFE0C174);
  static const Color red = Color(0xFF7C2119);
  static const Color redBright = Color(0xFFA7382C);
  static const Color green = Color(0xFF4F602A);
  static const Color blue = Color(0xFF244E8A);
}

abstract final class MedievalTheme {
  static ThemeData get theme {
    final base = ThemeData(
      brightness: Brightness.dark,
      useMaterial3: true,
      fontFamily: 'serif',
      colorScheme: const ColorScheme.dark(
        primary: MedievalColors.goldBright,
        secondary: MedievalColors.redBright,
        surface: MedievalColors.charcoal,
        error: Color(0xFFDA665C),
        onPrimary: MedievalColors.black,
        onSecondary: Colors.white,
        onSurface: MedievalColors.parchmentLight,
      ),
    );

    return base.copyWith(
      scaffoldBackgroundColor: MedievalColors.black,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        foregroundColor: MedievalColors.goldBright,
        elevation: 0,
      ),
      dividerColor: MedievalColors.inkSoft,
      textTheme: base.textTheme.copyWith(
        headlineSmall: const TextStyle(
          color: MedievalColors.goldBright,
          fontWeight: FontWeight.w700,
          letterSpacing: 1.2,
        ),
        titleLarge: const TextStyle(
          color: MedievalColors.ink,
          fontWeight: FontWeight.w700,
        ),
        titleMedium: const TextStyle(
          color: MedievalColors.ink,
          fontWeight: FontWeight.w700,
        ),
        bodyLarge: const TextStyle(color: MedievalColors.ink),
        bodyMedium: const TextStyle(color: MedievalColors.ink),
        bodySmall: const TextStyle(color: MedievalColors.inkSoft),
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: MedievalColors.red,
          foregroundColor: MedievalColors.parchmentLight,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(4),
            side: const BorderSide(color: MedievalColors.gold, width: 1.2),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
          textStyle: const TextStyle(fontSize: 17, fontWeight: FontWeight.w700),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: MedievalColors.parchmentLight,
        labelStyle: const TextStyle(color: MedievalColors.inkSoft),
        hintStyle: TextStyle(color: MedievalColors.inkSoft.withValues(alpha: 0.65)),
        prefixIconColor: MedievalColors.inkSoft,
        suffixIconColor: MedievalColors.inkSoft,
        border: const OutlineInputBorder(
          borderSide: BorderSide(color: MedievalColors.inkSoft),
        ),
        enabledBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: MedievalColors.inkSoft),
        ),
        focusedBorder: const OutlineInputBorder(
          borderSide: BorderSide(color: MedievalColors.red, width: 2),
        ),
      ),
      snackBarTheme: const SnackBarThemeData(
        backgroundColor: MedievalColors.ink,
        contentTextStyle: TextStyle(color: MedievalColors.parchmentLight),
      ),
      dialogTheme: const DialogThemeData(
        backgroundColor: MedievalColors.charcoal,
        titleTextStyle: TextStyle(
          color: MedievalColors.goldBright,
          fontFamily: 'serif',
          fontSize: 21,
          fontWeight: FontWeight.w700,
        ),
        contentTextStyle: TextStyle(
          color: MedievalColors.parchmentLight,
          fontFamily: 'serif',
          fontSize: 15,
          height: 1.35,
        ),
      ),
      tooltipTheme: TooltipThemeData(
        decoration: BoxDecoration(
          color: MedievalColors.ink,
          border: Border.all(color: MedievalColors.gold),
          borderRadius: BorderRadius.circular(4),
        ),
        textStyle: const TextStyle(color: MedievalColors.parchmentLight),
      ),
    );
  }
}
