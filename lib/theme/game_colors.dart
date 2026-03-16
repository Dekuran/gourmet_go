import 'dart:ui';

/// Game palette constants used across Flame components and overlays.
abstract final class GameColors {
  // Background
  static const Color darkBg = Color(0xFF0F0F1A);
  static const Color surfaceBg = Color(0xFF1A1A2E);
  static const Color kitchenBg = Color(0xFF2D1B0E);

  // Primary palette
  static const Color primary = Color(0xFFFF6B35);
  static const Color secondary = Color(0xFFFFC107);
  static const Color accent = Color(0xFF4A8FD9);

  // UI
  static const Color cash = Color(0xFF4CAF50);
  static const Color danger = Color(0xFFE53935);
  static const Color warning = Color(0xFFFF9800);

  // Progress bars
  static const Color progressFull = Color(0xFF4CAF50);
  static const Color progressMid = Color(0xFFFF9800);
  static const Color progressLow = Color(0xFFE53935);

  // Patience bar
  static const Color patienceHigh = Color(0xFF4CAF50);
  static const Color patienceMid = Color(0xFFFFEB3B);
  static const Color patienceLow = Color(0xFFE53935);

  // Text
  static const Color textPrimary = Color(0xFFFFFFFF);
  static const Color textSecondary = Color(0xB3FFFFFF);
  static const Color textMuted = Color(0x61FFFFFF);

  // Chef states
  static const Color chefAvailable = Color(0xFF4CAF50);
  static const Color chefCooking = Color(0xFFFF9800);
  static const Color chefPlating = Color(0xFF2196F3);

  // Stars
  static const Color starFilled = Color(0xFFFFD700);
  static const Color starEmpty = Color(0xFF555555);
}
