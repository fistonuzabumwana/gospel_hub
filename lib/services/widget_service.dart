import 'dart:async';

import 'package:flutter/services.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../services/database_service.dart';
import '../models/bible_book.dart';
import 'daily_verse_service.dart';

class WidgetService {
  static const _channel = MethodChannel('com.gospelhub.app/widget');

  static const String _widgetLanguageKey = 'widget_language';
  static const String _widgetVerseDayKey = 'widget_verse_day_key';

  /// Widget bible text language: `en` or `rw` (independent of app UI language).
  static Future<String> getWidgetLanguage() async {
    final prefs = await SharedPreferences.getInstance();
    final lang = prefs.getString(_widgetLanguageKey);
    if (lang == 'en' || lang == 'rw') return lang!;
    return 'rw';
  }

  static Future<void> syncWidgetData() async {
    try {
      final db = DatabaseService();
      final prefs = await SharedPreferences.getInstance();

      await _ensureTodayVerseIndex(prefs);

      await prefs.setInt('widget_verses_count', DailyVerseService.verseCount);

      for (int i = 0; i < DailyVerseService.verseRefs.length; i++) {
        final ref = DailyVerseService.verseRefs[i];
        final book = BibleBook.allBooks.firstWhere(
          (b) => b.bookNumber == ref.bookNumber,
          orElse: () => BibleBook.allBooks.first,
        );

        final textEn = await db.getSingleVerseText(ref.bookNumber, ref.chapter, ref.verse, true);
        final bookNameEn = book.getDisplayName('english');
        await prefs.setString('widget_verse_ref_en_$i', '$bookNameEn ${ref.chapter}:${ref.verse}');
        await prefs.setString('widget_verse_text_en_$i', textEn ?? '');

        final textRw = await db.getSingleVerseText(ref.bookNumber, ref.chapter, ref.verse, false);
        final bookNameRw = book.getDisplayName('kinyarwanda');
        await prefs.setString('widget_verse_ref_rw_$i', '$bookNameRw ${ref.chapter}:${ref.verse}');
        await prefs.setString('widget_verse_text_rw_$i', textRw ?? '');
      }

      final lang = await getWidgetLanguage();
      await prefs.setString(_widgetLanguageKey, lang);

      await _invokeUpdateWidget(null);
    } catch (e) {
      print('Error syncing widget data: $e');
    }
  }

  /// Align widget index with home "verse of the day" when the calendar day changes.
  static Future<void> _ensureTodayVerseIndex(SharedPreferences prefs) async {
    final now = DateTime.now();
    final todayKey = DailyVerseService.dayKeyFor(now);
    final lastKey = prefs.getString(_widgetVerseDayKey);

    if (lastKey != todayKey || !prefs.containsKey('widget_verse_index')) {
      await prefs.setInt('widget_verse_index', DailyVerseService.todayVerseIndex(now));
      await prefs.setString(_widgetVerseDayKey, todayKey);
    }
  }

  static const double minWidgetOpacity = 0.1;
  static const double maxWidgetOpacity = 1.0;

  static double _clampOpacity(double opacity) {
    return opacity.clamp(minWidgetOpacity, maxWidgetOpacity);
  }

  static Future<void> _invokeUpdateWidget(Map<String, dynamic>? args) async {
    try {
      await _channel
          .invokeMethod('updateWidget', args)
          .timeout(const Duration(seconds: 8));
    } on TimeoutException {
      // Native widget update must not block the UI.
    } catch (_) {}
  }

  static double _readDouble(SharedPreferences prefs, String key, double defaultValue) {
    try {
      final value = prefs.getDouble(key);
      if (value != null) return value;
    } catch (_) {}
    try {
      final asString = prefs.getString(key);
      if (asString != null) return double.parse(asString);
    } catch (_) {}
    return defaultValue;
  }

  static Future<double> getWidgetOpacity() async {
    final prefs = await SharedPreferences.getInstance();
    return _clampOpacity(_readDouble(prefs, 'widget_opacity', maxWidgetOpacity));
  }

  static Future<double> getWidgetFontSize() async {
    final prefs = await SharedPreferences.getInstance();
    return _readDouble(prefs, 'widget_font_size', 14.5);
  }

  static Future<String> getWidgetFontStyle() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('widget_font_style') ?? 'serif';
  }

  static Future<void> applyWidgetSettings({
    required double opacity,
    required double fontSize,
    required String fontStyle,
    required String language,
  }) async {
    final prefs = await SharedPreferences.getInstance();
    final clampedOpacity = _clampOpacity(opacity);
    final lang = language == 'en' ? 'en' : 'rw';
    await prefs.setDouble('widget_opacity', clampedOpacity);
    await prefs.setDouble('widget_font_size', fontSize);
    await prefs.setString('widget_font_style', fontStyle);
    await prefs.setString(_widgetLanguageKey, lang);
    await _invokeUpdateWidget({
      'opacity': clampedOpacity,
      'fontSize': fontSize,
      'fontStyle': fontStyle,
      'language': lang,
    });
  }

  static Future<void> setWidgetOpacity(double opacity) async {
    final prefs = await SharedPreferences.getInstance();
    final clamped = _clampOpacity(opacity);
    await prefs.setDouble('widget_opacity', clamped);
    await _invokeUpdateWidget({'opacity': clamped});
  }

  static Future<void> setWidgetFontSize(double size) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble('widget_font_size', size);
    await _invokeUpdateWidget({'fontSize': size});
  }

  static Future<void> setWidgetFontStyle(String style) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('widget_font_style', style);
    await _invokeUpdateWidget({'fontStyle': style});
  }

  static Future<Map<String, String>> getVerseOfDayPreview(String language) async {
    final lang = language == 'en' ? 'en' : 'rw';
    final index = DailyVerseService.todayVerseIndex();
    final prefs = await SharedPreferences.getInstance();

    final cachedRef = prefs.getString('widget_verse_ref_${lang}_$index');
    final cachedText = prefs.getString('widget_verse_text_${lang}_$index');
    if (cachedRef != null &&
        cachedText != null &&
        cachedRef.isNotEmpty &&
        cachedText.isNotEmpty) {
      return {'ref': cachedRef, 'text': cachedText};
    }

    final ref = DailyVerseService.todayVerseRef();
    final db = DatabaseService();
    final book = BibleBook.allBooks.firstWhere(
      (b) => b.bookNumber == ref.bookNumber,
      orElse: () => BibleBook.allBooks.first,
    );
    final isEnglish = lang == 'en';
    final text = await db.getSingleVerseText(ref.bookNumber, ref.chapter, ref.verse, isEnglish);
    final bookName = book.getDisplayName(isEnglish ? 'english' : 'kinyarwanda');
    return {
      'ref': '$bookName ${ref.chapter}:${ref.verse}',
      'text': text ?? '',
    };
  }

  static Future<void> triggerWidgetUpdate() async {
    await _invokeUpdateWidget(null);
  }
}
