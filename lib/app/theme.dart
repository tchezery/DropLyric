import 'package:flutter/material.dart';

/// Apple Design System & Tokens
class AppTheme {
  // Apple iOS Light Palette
  static const white = Color(0xFFFFFFFF);
  static const groupedBackgroundLight = Color(0xFFF2F2F7);
  static const secondaryGroupedLight = Color(0xFFFFFFFF);
  static const labelLight = Color(0xFF000000);
  static const secondaryLabelLight = Color(0xFF8E8E93);
  static const separatorLight = Color(0xFFE5E5EA);
  static const fillLight = Color(0xFFE9E9EB);

  // Apple iOS Dark Palette
  static const black = Color(0xFF000000);
  static const groupedBackgroundDark = Color(0xFF000000);
  static const secondaryGroupedDark = Color(0xFF1C1C1E);
  static const labelDark = Color(0xFFFFFFFF);
  static const secondaryLabelDark = Color(0xFF8E8E93);
  static const separatorDark = Color(0xFF2C2C2E);
  static const fillDark = Color(0xFF2C2C2E);

  // Accents
  static const appleBlue = Color(0xFF007AFF);
  static const spotifyGreen = Color(0xFF1DB954);
  static const spotifyGreenLight = Color(0xFF1ED760);
  static const appleRed = Color(0xFFFF3B30);

  // Aliases for compatibility
  static const paper = white;
  static const sheet = secondaryGroupedLight;
  static const ink = labelLight;
  static const muted = secondaryLabelLight;
  static const yellow = appleBlue;
  static const marker = Color(0xFFD0E8FF);
  static const separator = separatorLight;

  static const spotifyBlack = black;
  static const spotifyDarkCard = secondaryGroupedDark;
  static const spotifyMediumGray = separatorDark;
  static const spotifyLightGray = secondaryLabelDark;
  static const spotifyWhite = labelDark;

  static const primaryColor = appleBlue;
  static const backgroundColor = white;
  static const cardColor = secondaryGroupedLight;
  static const surfaceColor = separatorLight;
  static const textPrimary = labelLight;
  static const textSecondary = secondaryLabelLight;

  static const String fontSF = '.SF Pro Text';

  static ThemeData get notesTheme {
    final scheme = ColorScheme.fromSeed(
      seedColor: appleBlue,
      brightness: Brightness.light,
      surface: white,
      surfaceContainerHighest: groupedBackgroundLight,
      primary: appleBlue,
      onPrimary: Colors.white,
      onSurface: labelLight,
      onSurfaceVariant: secondaryLabelLight,
      outline: separatorLight,
      secondary: appleBlue,
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: fontSF,
      brightness: Brightness.light,
      colorScheme: scheme,
      scaffoldBackgroundColor: white,
      appBarTheme: const AppBarTheme(
        backgroundColor: white,
        foregroundColor: labelLight,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: fontSF,
          color: labelLight,
          fontSize: 28,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
      ),
      textTheme: ThemeData.light().textTheme.apply(
        fontFamily: fontSF,
        bodyColor: labelLight,
        displayColor: labelLight,
      ),
      cardTheme: CardThemeData(
        color: white,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
          side: const BorderSide(color: separatorLight, width: 0.8),
        ),
      ),
      dividerTheme: const DividerThemeData(color: separatorLight, thickness: 0.6),
      iconTheme: const IconThemeData(color: labelLight),
      listTileTheme: const ListTileThemeData(
        textColor: labelLight,
        iconColor: secondaryLabelLight,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: groupedBackgroundLight,
        hintStyle: const TextStyle(color: secondaryLabelLight, fontSize: 15),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: appleBlue, width: 1.5),
        ),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: labelLight,
        thumbColor: labelLight,
        inactiveTrackColor: separatorLight,
        trackHeight: 4,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: labelLight,
        linearTrackColor: separatorLight,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: labelLight,
          foregroundColor: white,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          textStyle: const TextStyle(
            fontFamily: fontSF,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: labelLight,
          side: const BorderSide(color: separatorLight, width: 1),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          textStyle: const TextStyle(
            fontFamily: fontSF,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: white,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
      ),
    );
  }

  static ThemeData get darkTheme {
    final scheme = ColorScheme.fromSeed(
      seedColor: appleBlue,
      brightness: Brightness.dark,
      surface: secondaryGroupedDark,
      surfaceContainerHighest: separatorDark,
      primary: white,
      onPrimary: black,
      onSurface: labelDark,
      onSurfaceVariant: secondaryLabelDark,
      outline: separatorDark,
      secondary: appleBlue,
    );

    return ThemeData(
      useMaterial3: true,
      fontFamily: fontSF,
      brightness: Brightness.dark,
      colorScheme: scheme,
      scaffoldBackgroundColor: black,
      appBarTheme: const AppBarTheme(
        backgroundColor: black,
        foregroundColor: labelDark,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        titleTextStyle: TextStyle(
          fontFamily: fontSF,
          color: labelDark,
          fontSize: 28,
          fontWeight: FontWeight.w700,
          letterSpacing: -0.5,
        ),
      ),
      textTheme: ThemeData.dark().textTheme.apply(
        fontFamily: fontSF,
        bodyColor: labelDark,
        displayColor: labelDark,
      ),
      cardTheme: CardThemeData(
        color: secondaryGroupedDark,
        elevation: 0,
        margin: EdgeInsets.zero,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(18),
        ),
      ),
      dividerTheme: const DividerThemeData(color: separatorDark, thickness: 0.6),
      iconTheme: const IconThemeData(color: labelDark),
      listTileTheme: const ListTileThemeData(
        textColor: labelDark,
        iconColor: secondaryLabelDark,
        contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 2),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: secondaryGroupedDark,
        hintStyle: const TextStyle(color: secondaryLabelDark, fontSize: 15),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(14),
          borderSide: const BorderSide(color: white, width: 1.5),
        ),
      ),
      sliderTheme: const SliderThemeData(
        activeTrackColor: white,
        thumbColor: white,
        inactiveTrackColor: separatorDark,
        trackHeight: 4,
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: white,
        linearTrackColor: separatorDark,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: white,
          foregroundColor: black,
          elevation: 0,
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          textStyle: const TextStyle(
            fontFamily: fontSF,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: labelDark,
          side: const BorderSide(color: separatorDark, width: 1),
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(24),
          ),
          textStyle: const TextStyle(
            fontFamily: fontSF,
            fontSize: 15,
            fontWeight: FontWeight.w600,
          ),
        ),
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: secondaryGroupedDark,
        surfaceTintColor: Colors.transparent,
        showDragHandle: true,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(22)),
        ),
      ),
    );
  }

  static LinearGradient get greenGradient =>
      const LinearGradient(colors: [spotifyGreen, spotifyGreenLight]);
  static LinearGradient playerBackgroundGradient(Color dominantColor) =>
      LinearGradient(
        begin: Alignment.topCenter,
        end: Alignment.bottomCenter,
        colors: [dominantColor.withValues(alpha: 0.15), white],
      );
}
