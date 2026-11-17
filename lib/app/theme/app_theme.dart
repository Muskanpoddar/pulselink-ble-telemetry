import 'package:flutter/material.dart';

/// The app palette.
///
/// The series, surface and ink colours are the validated data-visualisation
/// defaults (checked for CVD separation and contrast against the dark
/// surface), so the dashboard charts stay legible.
class AppTheme {
  const AppTheme._();

  // Surfaces
  static const Color pagePlane = Color(0xFF0D0D0D);
  static const Color surface = Color(0xFF1A1A19);

  // Ink
  static const Color primaryInk = Color(0xFFF0EFEC);
  static const Color secondaryInk = Color(0xFFC3C2B7);
  static const Color mutedInk = Color(0xFF898781);

  // Chart chrome
  static const Color gridline = Color(0xFF2C2C2A);
  static const Color baseline = Color(0xFF383835);

  // Categorical series
  static const Color series1 = Color(0xFF3987E5);
  static const Color series2 = Color(0xFFD95926);

  // Status
  static const Color statusGood = Color(0xFF0CA30C);
  static const Color statusWarning = Color(0xFFFAB219);
  static const Color statusCritical = Color(0xFFD03B3B);

  static ThemeData get dark {
    final base = ThemeData(useMaterial3: true, brightness: Brightness.dark);
    return base.copyWith(
      scaffoldBackgroundColor: pagePlane,
      colorScheme: base.colorScheme.copyWith(
        primary: series1,
        secondary: series2,
        error: statusCritical,
      ),
      textTheme: base.textTheme.apply(
        bodyColor: primaryInk,
        displayColor: primaryInk,
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: pagePlane,
        foregroundColor: primaryInk,
        elevation: 0,
        centerTitle: false,
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: surface,
        indicatorColor: series1.withValues(alpha: 0.20),
        labelTextStyle: const WidgetStatePropertyAll(
          TextStyle(color: secondaryInk, fontSize: 12),
        ),
        iconTheme: const WidgetStatePropertyAll(
          IconThemeData(color: secondaryInk),
        ),
      ),
      dividerTheme: const DividerThemeData(color: gridline, thickness: 1),
      listTileTheme: const ListTileThemeData(iconColor: secondaryInk),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: series1,
          foregroundColor: Colors.white,
          minimumSize: const Size.fromHeight(48),
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          textStyle: const TextStyle(
            fontWeight: FontWeight.w600,
            letterSpacing: 0.6,
          ),
        ),
      ),
    );
  }
}
