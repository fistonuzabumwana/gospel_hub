import 'package:shared_preferences/shared_preferences.dart';

class AppStateService {
  static const String _appLanguageKey = 'app_language';
  static const String _bibleLanguageKey = 'bible_language';
  static const String _darkModeKey = 'dark_mode';
  static const String _isFirstLaunchKey = 'is_first_launch';

  static Future<String> getAppLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_appLanguageKey) ?? 'en';
  }

  static Future<void> setAppLanguage(String language) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_appLanguageKey, language);
  }

  static Future<String> getBibleLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_bibleLanguageKey) ?? 'KJV_EN';
  }

  static Future<void> setBibleLanguage(String language) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_bibleLanguageKey, language);
  }

  static Future<bool?> getDarkMode() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_darkModeKey);
  }

  static Future<void> setDarkMode(bool? isDark) async {
    final prefs = await SharedPreferences.getInstance();
    if (isDark == null) {
      await prefs.remove(_darkModeKey);
    } else {
      await prefs.setBool(_darkModeKey, isDark);
    }
  }

  static Future<bool> isFirstLaunch() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getBool(_isFirstLaunchKey) ?? true;
  }

  static Future<void> setFirstLaunchComplete() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setBool(_isFirstLaunchKey, false);
  }
}