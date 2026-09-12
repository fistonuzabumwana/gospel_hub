import 'package:flutter/material.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'screens/home_screen.dart';
import 'services/app_localizations.dart';
import 'services/notification_service.dart';
import 'theme/app_theme.dart';

final ValueNotifier<ThemeMode> themeNotifier = ValueNotifier(ThemeMode.light);
final ValueNotifier<String> bibleTranslationNotifier = ValueNotifier('parallel');
final ValueNotifier<String> activeKinyarwandaBibleNotifier = ValueNotifier('BY');
final ValueNotifier<String> activeEnglishBibleNotifier = ValueNotifier('KJV');

void main() async {
  WidgetsFlutterBinding.ensureInitialized();
  
  // Load SharedPreferences ONCE and read all startup values synchronously
  final prefs = await SharedPreferences.getInstance();

  // App language
  localeNotifier.value = prefs.getString('app_language') ?? 'en';

  // Theme mode
  final isDark = prefs.getBool('dark_mode');
  if (isDark == null) {
    themeNotifier.value = ThemeMode.system;
  } else {
    themeNotifier.value = isDark ? ThemeMode.dark : ThemeMode.light;
  }

  // Bible translation mode
  bibleTranslationNotifier.value = prefs.getString('bible_translation_mode') ?? 'parallel';

  // Active Bible versions
  final savedKinyarwandaBible = prefs.getString('active_kinyarwanda_bible') ?? 'BY';
  var savedEnglishBible = prefs.getString('active_english_bible');
  if (savedEnglishBible == null) {
    const defaultPairings = {
      'BY': 'KJV',
      'II': 'GNB',
      'BN': 'CE',
      'IID': 'GNC',
    };
    savedEnglishBible = defaultPairings[savedKinyarwandaBible] ?? 'KJV';
  }

  activeKinyarwandaBibleNotifier.value = savedKinyarwandaBible;
  activeEnglishBibleNotifier.value = savedEnglishBible;

  // Initialize and request notification permissions
  final notificationService = NotificationService();
  await notificationService.init();
  await notificationService.requestPermissions();

  runApp(const GospelHubApp());
}

class GospelHubApp extends StatelessWidget {
  const GospelHubApp({super.key});

  @override
  Widget build(BuildContext context) {
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
          theme: AppTheme.lightTheme,
          darkTheme: AppTheme.darkTheme,
          themeMode: currentThemeMode,
          home: const HomeScreen(),
        );
      },
    );
  },
);
  }
}