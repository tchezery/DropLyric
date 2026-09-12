import 'package:flutter/material.dart';

class AppTheme {
  static const paper = Color(0xFFF7F5EF);
  static const sheet = Color(0xFFFFFEFA);
  static const ink = Color(0xFF242320);
  static const muted = Color(0xFF74716A);
  static const yellow = Color(0xFF936800);
  static const marker = Color(0xFFFFE89A);
  static const separator = Color(0xFFE4E0D6);
  // Compatibility aliases for existing screens.
  static const spotifyGreen = yellow;
  static const spotifyGreenLight = marker;
  static const spotifyBlack = paper;
  static const spotifyDarkCard = sheet;
  static const spotifyMediumGray = separator;
  static const spotifyLightGray = muted;
  static const spotifyWhite = ink;
  static const primaryColor = yellow;
  static const backgroundColor = paper;
  static const cardColor = sheet;
  static const surfaceColor = separator;
  static const textPrimary = ink;
  static const textSecondary = muted;

  static ThemeData get notesTheme {
    final scheme = ColorScheme.fromSeed(
      seedColor: yellow,
      brightness: Brightness.light,
      surface: sheet,
      primary: yellow,
      onPrimary: Colors.white,
      onSurface: ink,
      secondary: yellow,
    );
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: paper,
      appBarTheme: const AppBarTheme(
        backgroundColor: paper,
        foregroundColor: ink,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          color: ink,
          fontSize: 32,
          fontWeight: FontWeight.w700,
          letterSpacing: -1,
        ),
      ),
      textTheme: ThemeData.light().textTheme.apply(
        bodyColor: ink,
        displayColor: ink,
      ),
      cardTheme: CardThemeData(
        color: sheet,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      ),
      dividerTheme: const DividerThemeData(color: separator, thickness: 0.5),
      iconTheme: const IconThemeData(color: yellow),
      listTileTheme: const ListTileThemeData(textColor: ink, iconColor: yellow),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: separator,
        hintStyle: const TextStyle(color: muted),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: yellow,
        thumbColor: yellow,
        inactiveTrackColor: separator,
        trackHeight: 3,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: yellow,
        linearTrackColor: separator,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: marker,
          foregroundColor: ink,
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: yellow,
          side: const BorderSide(color: separator),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: sheet,
        showDragHandle: true,
      ),
    );
  }

  static ThemeData get darkTheme => notesTheme;
  static LinearGradient get greenGradient =>
      const LinearGradient(colors: [marker, paper]);
  static LinearGradient playerBackgroundGradient(Color dominantColor) =>
      const LinearGradient(colors: [sheet, paper]);
}
