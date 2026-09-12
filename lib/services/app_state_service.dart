import 'package:shared_preferences/shared_preferences.dart';
import 'widget_service.dart';

class AppStateService {
  static const String _appLanguageKey = 'app_language';
  static const String _bibleLanguageKey = 'bible_language';
  static const String _darkModeKey = 'dark_mode';
  static const String _isFirstLaunchKey = 'is_first_launch';

  // Cached SharedPreferences instance to avoid repeated async lookups
  static SharedPreferences? _prefs;
  static Future<SharedPreferences> _getPrefs() async {
    _prefs ??= await SharedPreferences.getInstance();
    return _prefs!;
  }

  static Future<String> getAppLanguage() async {
    final prefs = await _getPrefs();
    return prefs.getString(_appLanguageKey) ?? 'en';
  }

  static Future<void> setAppLanguage(String language) async {
    final prefs = await _getPrefs();
    await prefs.setString(_appLanguageKey, language);
    await WidgetService.syncWidgetData();
  }

  static Future<String> getBibleLanguage() async {
    final prefs = await _getPrefs();
    return prefs.getString(_bibleLanguageKey) ?? 'KJV_EN';
  }

  static Future<void> setBibleLanguage(String language) async {
    final prefs = await _getPrefs();
    await prefs.setString(_bibleLanguageKey, language);
  }

  static Future<bool?> getDarkMode() async {
    final prefs = await _getPrefs();
    return prefs.getBool(_darkModeKey);
  }

  static Future<void> setDarkMode(bool? isDark) async {
    final prefs = await _getPrefs();
    if (isDark == null) {
      await prefs.remove(_darkModeKey);
    } else {
      await prefs.setBool(_darkModeKey, isDark);
    }
  }

  static Future<bool> isFirstLaunch() async {
    final prefs = await _getPrefs();
    return prefs.getBool(_isFirstLaunchKey) ?? true;
  }

  static Future<void> setFirstLaunchComplete() async {
    final prefs = await _getPrefs();
    await prefs.setBool(_isFirstLaunchKey, false);
  }

  static const String _dailyNotificationEnabledKey = 'daily_notification_enabled';
  static const String _dailyNotificationHourKey = 'daily_notification_hour';
  static const String _dailyNotificationMinuteKey = 'daily_notification_minute';

  static Future<bool> isDailyNotificationEnabled() async {
    final prefs = await _getPrefs();
    return prefs.getBool(_dailyNotificationEnabledKey) ?? true;
  }

  static Future<void> setDailyNotificationEnabled(bool enabled) async {
    final prefs = await _getPrefs();
    await prefs.setBool(_dailyNotificationEnabledKey, enabled);
  }

  static Future<int> getDailyNotificationHour() async {
    final prefs = await _getPrefs();
    return prefs.getInt(_dailyNotificationHourKey) ?? 8;
  }

  static Future<void> setDailyNotificationHour(int hour) async {
    final prefs = await _getPrefs();
    await prefs.setInt(_dailyNotificationHourKey, hour);
  }

  static Future<int> getDailyNotificationMinute() async {
    final prefs = await _getPrefs();
    return prefs.getInt(_dailyNotificationMinuteKey) ?? 0;
  }

  static Future<void> setDailyNotificationMinute(int minute) async {
    final prefs = await _getPrefs();
    await prefs.setInt(_dailyNotificationMinuteKey, minute);
  }
}