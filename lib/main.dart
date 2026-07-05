import 'package:flutter/material.dart';
import 'screens/home_screen.dart';
import 'services/app_state_service.dart';

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final isDark = await AppStateService.getDarkMode();
  if (isDark == null) {
    themeNotifier.value = ThemeMode.system;
  } else {
    themeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;
  }
  runApp(const GospelHubApp());
}

class GospelHubApp extends StatelessWidget {
  const GospelHubApp({super.key});

  @override
  Widget build(BuildContext context) {
    const primaryColor = Color(0xFF2A62FF);

    return ValueListenableBuilder<ThemeMode>(
      valueListenable: themeNotifier,
      builder: (_, ThemeMode currentThemeMode, __) {
        return MaterialApp(
          title: 'Gospel Hub',
          debugShowCheckedModeBanner: false,
          theme: ThemeData(
            useMaterial3: true,
            brightness: Brightness.light,
            primaryColor: primaryColor,
            colorScheme: ColorScheme.fromSeed(
              seedColor: primaryColor,
              primary: primaryColor,
              secondary: primaryColor,
              surface: Colors.white,
              brightness: Brightness.light,
            ),
            scaffoldBackgroundColor: const Color(0xFFF6F8F6),
            appBarTheme: const AppBarTheme(
              backgroundColor: Colors.white,
              foregroundColor: Colors.black87,
              elevation: 0,
              scrolledUnderElevation: 1,
            ),
            cardTheme: CardThemeData(
              color: Colors.white,
              elevation: 1.5,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(16),
              ),
            ),
            textTheme: const TextTheme(
              titleLarge: TextStyle(fontWeight: FontWeight.bold, color: Colors.black87),
              titleMedium: TextStyle(fontWeight: FontWeight.w600, color: Colors.black87),
              bodyLarge: TextStyle(color: Colors.black87),
              bodyMedium: TextStyle(color: Colors.black54),
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
  }
}