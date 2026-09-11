import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

class AppTheme {
  // Common Colors
  static const Color primaryColor = Color(0xFF253570);
  
  // Light Theme Colors
  static const Color lightBackground = Color(0xFFF8FAFC); // Slate 50
  static const Color lightSurface = Colors.white;
  static const Color lightTextPrimary = Color(0xFF0F172A); // Slate 900
  static const Color lightTextSecondary = Color(0xFF64748B); // Slate 500
  static const Color lightAccent = primaryColor;
  
  // Dark Theme Colors
  static const Color darkBackground = Color(0xFF101210);
  static const Color darkSurface = Color(0xFF1B1D1B);
  static const Color darkTextPrimary = Colors.white;
  static const Color darkTextSecondary = Colors.white70;
  static const Color darkAccent = Color(0xFF60A5FA); // Light Blue

  static ThemeData get lightTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.light,
      primaryColor: primaryColor,
      colorScheme: const ColorScheme.light(
        primary: primaryColor,
        secondary: Color(0xFF4F46E5), // Indigo Accent
        tertiary: Color(0xFFF59E0B),  // Amber Accent
        surface: lightSurface,
        error: Color(0xFFEF4444),
        onPrimary: Colors.white,
        onSecondary: Colors.white,
        onSurface: lightTextPrimary,
        onSurfaceVariant: Color(0xFF475569), // Slate 600
        outline: Color(0xFFE2E8F0),   // Slate 200
      ),
      scaffoldBackgroundColor: lightBackground,
      appBarTheme: const AppBarTheme(
        backgroundColor: primaryColor,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: Colors.white),
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      cardTheme: CardThemeData(
        color: lightSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: Color(0xFFE2E8F0), width: 1), // Thin slate-200 border
        ),
      ),
      textTheme: const TextTheme(
        titleLarge: TextStyle(fontWeight: FontWeight.bold, color: lightTextPrimary, letterSpacing: -0.5),
        titleMedium: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
        bodyLarge: TextStyle(color: Color(0xFF334155), height: 1.5),
        bodyMedium: TextStyle(color: lightTextSecondary, height: 1.4),
      ),
      dividerTheme: const DividerThemeData(
        color: Color(0xFFF1F5F9), // Slate 100
        thickness: 1,
        space: 1,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: const Color(0xFFF1F5F9),
        selectedColor: const Color(0xFFEBF3FF),
        labelStyle: const TextStyle(color: Color(0xFF334155), fontSize: 13, fontWeight: FontWeight.w500),
        secondaryLabelStyle: const TextStyle(color: primaryColor, fontSize: 13, fontWeight: FontWeight.w600),
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(100),
          side: BorderSide.none,
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: const Color(0xFFF1F5F9),
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        enabledBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: primaryColor, width: 1.5),
        ),
        labelStyle: const TextStyle(color: lightTextSecondary),
        hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
      ),
      extensions: [
        AppColors(
          accent: lightAccent,
          cardBorder: const Color(0xFFE2E8F0),
          iconInactive: Colors.white.withValues(alpha: 0.55),
          tabBackground: const Color(0xFFF3F4F6),
        ),
      ],
    );
  }

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      primaryColor: primaryColor,
      colorScheme: ColorScheme.fromSeed(
        seedColor: primaryColor,
        primary: primaryColor,
        secondary: primaryColor,
        surface: darkSurface,
        brightness: Brightness.dark,
      ),
      scaffoldBackgroundColor: darkBackground,
      appBarTheme: const AppBarTheme(
        backgroundColor: darkSurface,
        foregroundColor: Colors.white,
        elevation: 0,
        scrolledUnderElevation: 1,
        systemOverlayStyle: SystemUiOverlayStyle.light,
        titleTextStyle: TextStyle(
          color: Colors.white,
          fontSize: 20,
          fontWeight: FontWeight.bold,
        ),
      ),
      cardTheme: CardThemeData(
        color: darkSurface,
        elevation: 1.5,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
        ),
      ),
      textTheme: const TextTheme(
        titleLarge: TextStyle(fontWeight: FontWeight.bold, color: darkTextPrimary),
        titleMedium: TextStyle(fontWeight: FontWeight.w600, color: darkTextPrimary),
        bodyLarge: TextStyle(color: darkTextPrimary),
        bodyMedium: TextStyle(color: darkTextSecondary),
      ),
      extensions: [
        AppColors(
          accent: darkAccent,
          cardBorder: darkAccent.withValues(alpha: 0.1),
          iconInactive: Colors.grey.shade500,
          tabBackground: const Color(0xFF2A2A2A),
        ),
      ],
    );
  }
}

// Custom theme extension for app-specific colors not covered by ColorScheme
class AppColors extends ThemeExtension<AppColors> {
  final Color accent;
  final Color cardBorder;
  final Color iconInactive;
  final Color tabBackground;

  AppColors({
    required this.accent,
    required this.cardBorder,
    required this.iconInactive,
    required this.tabBackground,
  });

  @override
  ThemeExtension<AppColors> copyWith({
    Color? accent,
    Color? cardBorder,
    Color? iconInactive,
    Color? tabBackground,
  }) {
    return AppColors(
      accent: accent ?? this.accent,
      cardBorder: cardBorder ?? this.cardBorder,
      iconInactive: iconInactive ?? this.iconInactive,
      tabBackground: tabBackground ?? this.tabBackground,
    );
  }

  @override
  ThemeExtension<AppColors> lerp(ThemeExtension<AppColors>? other, double t) {
    if (other is! AppColors) {
      return this;
    }
    return AppColors(
      accent: Color.lerp(accent, other.accent, t)!,
      cardBorder: Color.lerp(cardBorder, other.cardBorder, t)!,
      iconInactive: Color.lerp(iconInactive, other.iconInactive, t)!,
      tabBackground: Color.lerp(tabBackground, other.tabBackground, t)!,
    );
  }
}

// Helper method to get AppColors easily
extension AppThemeContext on BuildContext {
  AppColors get appColors => Theme.of(this).extension<AppColors>()!;
}
