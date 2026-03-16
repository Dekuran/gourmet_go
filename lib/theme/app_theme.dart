import 'package:flutter/material.dart';

import 'game_colors.dart';

/// ThemeData for Flutter overlays.
///
/// Dark theme matching the game's aesthetic.
abstract final class AppTheme {
  static ThemeData get dark => ThemeData(
        brightness: Brightness.dark,
        colorScheme: ColorScheme.dark(
          primary: GameColors.primary,
          secondary: GameColors.secondary,
          surface: GameColors.surfaceBg,
        ),
        scaffoldBackgroundColor: GameColors.darkBg,
        appBarTheme: const AppBarTheme(
          backgroundColor: GameColors.surfaceBg,
          elevation: 0,
        ),
        elevatedButtonTheme: ElevatedButtonThemeData(
          style: ElevatedButton.styleFrom(
            backgroundColor: GameColors.primary,
            foregroundColor: Colors.white,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
            ),
            padding: const EdgeInsets.symmetric(
              horizontal: 24,
              vertical: 12,
            ),
          ),
        ),
        textTheme: const TextTheme(
          displayLarge: TextStyle(
            fontSize: 32,
            fontWeight: FontWeight.bold,
            color: GameColors.textPrimary,
          ),
          titleLarge: TextStyle(
            fontSize: 22,
            fontWeight: FontWeight.bold,
            color: GameColors.textPrimary,
          ),
          titleMedium: TextStyle(
            fontSize: 18,
            fontWeight: FontWeight.w600,
            color: GameColors.textPrimary,
          ),
          bodyLarge: TextStyle(
            fontSize: 16,
            height: 1.5,
            color: GameColors.textSecondary,
          ),
          bodyMedium: TextStyle(
            fontSize: 14,
            height: 1.4,
            color: GameColors.textSecondary,
          ),
          labelSmall: TextStyle(
            fontSize: 11,
            color: GameColors.textMuted,
          ),
        ),
        useMaterial3: true,
      );
}
