import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/home_screen.dart';
import 'services/app_state_service.dart';
import 'services/app_localizations.dart';

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);
final ValueNotifier<String> bibleTranslationNotifier = ValueNotifier('parallel');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load initial app language preference
  final savedLanguage = await AppStateService.getAppLanguage();
  localeNotifier.value = savedLanguage;

  final isDark = await AppStateService.getDarkMode();
  if (isDark == null) {
    themeNotifier.value = ThemeMode.system;
  } else {
    themeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;
  }

  // Load initial Bible translation mode preference
  final prefs = await SharedPreferences.getInstance();
  final savedTranslation = prefs.getString('bible_translation_mode') ?? 'parallel';
  bibleTranslationNotifier.value = savedTranslation;

  runApp(const GospelHubApp());
}

class GospelHubApp extends StatelessWidget {
  const GospelHubApp({super.key});

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF253570);

    return ValueListenableBuilder<String>(
      valueListenable: localeNotifier,
      builder: (_, String currentLocale, __) {
        return ValueListenableBuilder<ThemeMode>(
          valueListenable: themeNotifier,
          builder: (_, ThemeMode currentThemeMode, __) {
            return MaterialApp(
              title: 'Gospel Hub',
              debugShowCheckedModeBanner: false,
              locale: Locale(currentLocale),
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.light,
            primaryColor: primaryColor,
            colorScheme: const ColorScheme.light(
              primary: primaryColor,
              secondary: Color(0xFF4F46E5), // Indigo Accent
              tertiary: Color(0xFFF59E0B),  // Amber Accent
              surface: Colors.white,
              error: Color(0xFFEF4444),
              onPrimary: Colors.white,
              onSecondary: Colors.white,
              onSurface: Color(0xFF0F172A), // Slate 900
              onSurfaceVariant: Color(0xFF475569), // Slate 600
              outline: Color(0xFFE2E8F0),   // Slate 200
            ),
            scaffoldBackgroundColor: const Color(0xFFF8FAFC), // Slate 50 Background
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
              color: Colors.white,
              elevation: 0,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
                side: const BorderSide(color: Color(0xFFE2E8F0), width: 1), // Thin slate-200 border
              ),
            ),
            textTheme: const TextTheme(
              titleLarge: TextStyle(fontWeight: FontWeight.bold, color: Color(0xFF0F172A), letterSpacing: -0.5),
              titleMedium: TextStyle(fontWeight: FontWeight.w600, color: Color(0xFF1E293B)),
              bodyLarge: TextStyle(color: Color(0xFF334155), height: 1.5),
              bodyMedium: TextStyle(color: Color(0xFF64748B), height: 1.4),
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
              labelStyle: const TextStyle(color: Color(0xFF64748B)),
              hintStyle: const TextStyle(color: Color(0xFF94A3B8)),
            ),
          ),
          darkTheme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.dark,
            primaryColor: primaryColor,
            colorScheme: ColorScheme.fromSeed(
              seedColor: primaryColor,
              primary: primaryColor,
              secondary: primaryColor,
              surface: const Color(0xFF1B1D1B),
              brightness: Brightness.dark,
            ),
            scaffoldBackgroundColor: const Color(0xFF101210),
            appBarTheme: const AppBarTheme(
              backgroundColor: Color(0xFF1B1D1B),
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
              color: const Color(0xFF1B1D1B),
              elevation: 1.5,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            textTheme: const TextTheme(
              titleLarge: TextStyle(fontWeight: FontWeight.bold, color: Colors.white),
              titleMedium: TextStyle(fontWeight: FontWeight.w600, color: Colors.white),
              bodyLarge: TextStyle(color: Colors.white),
              bodyMedium: TextStyle(color: Colors.white70),
            ),
          ),
          themeMode: currentThemeMode,
          home: const HomeScreen(),
        );
      },
    );
  },
);
  }
}